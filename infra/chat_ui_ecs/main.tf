terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "chat-ui"
  common_tags = merge(var.tags, {
    Module = "chat-ui-ecs"
  })

  container_image = (
    var.container_image != ""
    ? var.container_image
    : var.create_ecr_repository
    ? "${aws_ecr_repository.ui[0].repository_url}:latest"
    : ""
  )

  fargate_vpce_services = toset(["ecr.api", "ecr.dkr", "logs"])
}

# ------------------------------------------------------------------------------
# Data sources
# ------------------------------------------------------------------------------

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

# ------------------------------------------------------------------------------
# ECR Repository
# ------------------------------------------------------------------------------

resource "aws_ecr_repository" "ui" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ecr" })
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ui" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-logs" })
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------

# --- ALB SG ---

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "SG for internal ALB fronting the chat UI"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_vpc" {
  for_each = toset(var.vpc_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from ${each.value}"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-ingress-${replace(each.value, "/", "-")}" })
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow traffic to Fargate tasks on UI port"
  from_port                    = var.ui_port
  to_port                      = var.ui_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-egress-task" })
}

# --- Task SG ---

resource "aws_security_group" "task" {
  name        = "${local.name_prefix}-task-sg"
  description = "SG for Fargate tasks running the chat UI"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "Allow UI port from ALB"
  from_port                    = var.ui_port
  to_port                      = var.ui_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-ingress-alb" })
}

resource "aws_vpc_security_group_egress_rule" "task_all_outbound" {
  security_group_id = aws_security_group.task.id
  description       = "Allow all outbound (VPC endpoints, etc.)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-egress-all" })
}

# --- VPC Endpoint SG ---

resource "aws_security_group" "vpce" {
  name        = "${local.name_prefix}-vpce-sg"
  description = "SG for VPC interface endpoints used by the chat UI"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "vpce_from_task" {
  security_group_id            = aws_security_group.vpce.id
  description                  = "Allow HTTPS from Fargate task SG"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-ingress-task" })
}

resource "aws_vpc_security_group_egress_rule" "vpce_all_outbound" {
  security_group_id = aws_security_group.vpce.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-egress" })
}

# ------------------------------------------------------------------------------
# IAM — Task Execution Role (ECR pull + CloudWatch Logs)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-exec-role" })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------------------------------
# IAM — Task Role (app-level permissions)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-role" })
}

resource "aws_iam_role_policy" "execute_api_invoke" {
  count = var.agent_api_auth_mode == "iam" ? 1 : 0

  name = "${local.name_prefix}-execute-api-invoke"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_additional" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.task.name
  policy_arn = each.value
}

# ------------------------------------------------------------------------------
# Internal Application Load Balancer
# ------------------------------------------------------------------------------

resource "aws_lb" "ui" {
  name               = "${local.name_prefix}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })
}

resource "aws_lb_target_group" "ui" {
  name        = "${local.name_prefix}-tg"
  port        = var.ui_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/_stcore/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tg" })
}

resource "aws_lb_listener" "ui" {
  load_balancer_arn = aws_lb.ui.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-listener" })
}

# ------------------------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------------------------

resource "aws_ecs_cluster" "ui" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-cluster" })
}

# ------------------------------------------------------------------------------
# ECS Task Definition
# ------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "ui" {
  family                   = "${local.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "streamlit"
      image     = local.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.ui_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AGENT_API_BASE_URL", value = var.agent_api_base_url },
        { name = "AGENT_API_AUTH_MODE", value = var.agent_api_auth_mode },
        { name = "AWS_DEFAULT_REGION", value = var.region },
        { name = "STREAMLIT_SERVER_PORT", value = tostring(var.ui_port) },
        { name = "STREAMLIT_SERVER_ADDRESS", value = "0.0.0.0" },
        { name = "STREAMLIT_SERVER_HEADLESS", value = "true" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ui.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-def" })
}

# ------------------------------------------------------------------------------
# ECS Service
# ------------------------------------------------------------------------------

resource "aws_ecs_service" "ui" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.ui.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "streamlit"
    container_port   = var.ui_port
  }

  depends_on = [aws_lb_listener.ui]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-service" })
}

# ------------------------------------------------------------------------------
# VPC Interface Endpoints — required for Fargate in private subnets
# ------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "fargate" {
  for_each = local.fargate_vpce_services

  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${replace(each.value, ".", "-")}-vpce" })
}

# ------------------------------------------------------------------------------
# VPC Interface Endpoint — execute-api (private API Gateway)
# ------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "execute_api" {
  count = var.create_execute_api_vpce ? 1 : 0

  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${var.region}.execute-api"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-execute-api-vpce" })
}

# ------------------------------------------------------------------------------
# Additional VPC Interface Endpoints (caller-supplied)
# ------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "additional" {
  for_each = toset(var.additional_vpce_services)

  vpc_id              = var.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.value}-vpce" })
}

# ------------------------------------------------------------------------------
# S3 Gateway Endpoint (for ECR image layer pulls)
# ------------------------------------------------------------------------------

data "aws_route_tables" "private" {
  count  = var.create_s3_gateway_endpoint ? 1 : 0
  vpc_id = var.vpc_id

  filter {
    name   = "association.subnet-id"
    values = var.private_subnet_ids
  }
}

resource "aws_vpc_endpoint" "s3_gateway" {
  count = var.create_s3_gateway_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.region}.s3"
  route_table_ids   = data.aws_route_tables.private[0].ids

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-s3-gw-vpce" })
}

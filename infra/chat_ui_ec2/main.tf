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
    Module = "chat-ui-ec2"
  })

  # Resolves to the managed bucket when create_app_s3_bucket = true,
  # otherwise falls back to the caller-supplied bucket name.
  effective_app_s3_bucket = var.create_app_s3_bucket ? aws_s3_bucket.app_artifact[0].id : var.app_s3_bucket
}

# ------------------------------------------------------------------------------
# Data sources
# ------------------------------------------------------------------------------

data "aws_vpc" "this" {
  id = var.vpc_id
}

# ------------------------------------------------------------------------------
# S3 Artifact Bucket (optional — enabled by create_app_s3_bucket)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "app_artifact" {
  count = var.create_app_s3_bucket ? 1 : 0

  bucket_prefix = "${local.name_prefix}-artifact-"
  force_destroy = false

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-artifact" })
}

resource "aws_s3_bucket_versioning" "app_artifact" {
  count = var.create_app_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.app_artifact[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_artifact" {
  count = var.create_app_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.app_artifact[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_artifact" {
  count = var.create_app_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.app_artifact[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------

resource "aws_security_group" "ui" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "SG for Streamlit chat UI EC2 instances"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "ui_from_vpc" {
  for_each = toset(var.vpc_cidrs)

  security_group_id = aws_security_group.ui.id
  description       = "Allow Streamlit port from ${each.value}"
  from_port         = var.ui_port
  to_port           = var.ui_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ingress-ui-${replace(each.value, "/", "-")}" })
}

resource "aws_vpc_security_group_egress_rule" "ui_all_outbound" {
  security_group_id = aws_security_group.ui.id
  description       = "Allow all outbound (VPC endpoints, etc.)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-egress-all" })
}

resource "aws_security_group" "vpce" {
  name        = "${local.name_prefix}-vpce-sg"
  description = "SG for VPC interface endpoints used by the chat UI"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "vpce_from_ui" {
  security_group_id            = aws_security_group.vpce.id
  description                  = "Allow HTTPS from UI EC2 SG"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ui.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-ingress" })
}

resource "aws_vpc_security_group_egress_rule" "vpce_all_outbound" {
  security_group_id = aws_security_group.vpce.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-egress" })
}

# ------------------------------------------------------------------------------
# IAM Role & Instance Profile
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ui" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2-role" })
}

resource "aws_iam_instance_profile" "ui" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ui.name

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2-profile" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ui.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "execute_api_invoke" {
  count = var.agent_api_auth_mode == "iam" ? 1 : 0

  name = "${local.name_prefix}-execute-api-invoke"
  role = aws_iam_role.ui.id

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

resource "aws_iam_role_policy" "s3_app_artifact" {
  count = local.effective_app_s3_bucket != "" ? 1 : 0

  name = "${local.name_prefix}-s3-app-artifact"
  role = aws_iam_role.ui.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${local.effective_app_s3_bucket}/${var.app_s3_key}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = toset(var.additional_iam_policy_arns)

  role       = aws_iam_role.ui.name
  policy_arn = each.value
}

# ------------------------------------------------------------------------------
# Launch Template
# ------------------------------------------------------------------------------

resource "aws_launch_template" "ui" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ui.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ui.name
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    ui_port             = var.ui_port
    agent_api_base_url  = var.agent_api_base_url
    agent_api_auth_mode = var.agent_api_auth_mode
    aws_region          = var.region
    app_s3_uri          = local.effective_app_s3_bucket != "" ? "s3://${local.effective_app_s3_bucket}/${var.app_s3_key}" : ""
  }))

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-ec2" })
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-lt" })
}

# ------------------------------------------------------------------------------
# Auto Scaling Group
# ------------------------------------------------------------------------------

resource "aws_autoscaling_group" "ui" {
  name                = "${local.name_prefix}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.ui.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ec2"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
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
# Additional VPC Interface Endpoints (SSM, CloudWatch Logs, etc.)
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

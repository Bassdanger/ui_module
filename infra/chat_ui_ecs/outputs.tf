output "ecr_repository_url" {
  description = "ECR repository URL — push your container image here"
  value       = var.create_ecr_repository ? aws_ecr_repository.ui[0].repository_url : ""
}

output "alb_dns_name" {
  description = "DNS name of the internal ALB (stable private endpoint for the UI)"
  value       = aws_lb.ui.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.ui.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.ui.name
}

output "task_role_arn" {
  description = "ARN of the IAM role assumed by the running container"
  value       = aws_iam_role.task.arn
}

output "task_execution_role_arn" {
  description = "ARN of the IAM role used by ECS to pull images and write logs"
  value       = aws_iam_role.task_execution.arn
}

output "task_security_group_id" {
  description = "Security group ID attached to Fargate tasks"
  value       = aws_security_group.task.id
}

output "alb_security_group_id" {
  description = "Security group ID attached to the internal ALB"
  value       = aws_security_group.alb.id
}

output "vpce_security_group_id" {
  description = "Security group ID attached to VPC interface endpoints"
  value       = aws_security_group.vpce.id
}

output "execute_api_vpce_id" {
  description = "ID of the execute-api VPC endpoint (empty string if not created)"
  value       = var.create_execute_api_vpce ? aws_vpc_endpoint.execute_api[0].id : ""
}

output "additional_vpce_ids" {
  description = "Map of additional VPC endpoint service suffix to endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.additional : k => v.id }
}

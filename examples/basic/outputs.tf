output "ecr_repository_url" {
  description = "ECR repository URL — push your container image here"
  value       = module.chat_ui_ecs.ecr_repository_url
}

output "alb_dns_name" {
  description = "Internal ALB DNS name (stable private endpoint for the UI)"
  value       = module.chat_ui_ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.chat_ui_ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.chat_ui_ecs.ecs_service_name
}

output "task_security_group_id" {
  description = "Security group ID for Fargate tasks"
  value       = module.chat_ui_ecs.task_security_group_id
}

output "alb_security_group_id" {
  description = "Security group ID for the internal ALB"
  value       = module.chat_ui_ecs.alb_security_group_id
}

output "execute_api_vpce_id" {
  description = "Execute-api VPC endpoint ID (empty if not created)"
  value       = module.chat_ui_ecs.execute_api_vpce_id
}

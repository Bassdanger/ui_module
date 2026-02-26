output "ui_security_group_id" {
  description = "Security group ID attached to the Streamlit UI EC2 instances"
  value       = aws_security_group.ui.id
}

output "vpce_security_group_id" {
  description = "Security group ID attached to VPC interface endpoints"
  value       = aws_security_group.vpce.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group running the UI"
  value       = aws_autoscaling_group.ui.name
}

output "launch_template_id" {
  description = "ID of the launch template for the UI instances"
  value       = aws_launch_template.ui.id
}

output "execute_api_vpce_id" {
  description = "ID of the execute-api VPC endpoint (empty string if not created)"
  value       = var.create_execute_api_vpce ? aws_vpc_endpoint.execute_api[0].id : ""
}

output "additional_vpce_ids" {
  description = "Map of additional VPC endpoint service suffix to endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.additional : k => v.id }
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the UI EC2 instances"
  value       = aws_iam_role.ui.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the UI EC2 instances"
  value       = aws_iam_role.ui.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile attached to the UI EC2 instances"
  value       = aws_iam_instance_profile.ui.name
}

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

output "app_s3_bucket_name" {
  description = "Name of the S3 bucket used for the ui_module artifact (empty string if not managed by this module)"
  value       = local.effective_app_s3_bucket
}

output "ui_security_group_id" {
  description = "Security group ID for the Streamlit UI EC2 instances"
  value       = module.chat_ui_ec2.ui_security_group_id
}

output "vpce_security_group_id" {
  description = "Security group ID for VPC interface endpoints"
  value       = module.chat_ui_ec2.vpce_security_group_id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.chat_ui_ec2.asg_name
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = module.chat_ui_ec2.launch_template_id
}

output "execute_api_vpce_id" {
  description = "Execute-api VPC endpoint ID (empty if not created)"
  value       = module.chat_ui_ec2.execute_api_vpce_id
}

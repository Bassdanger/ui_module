variable "vpc_id" {
  type        = string
  description = "Existing VPC ID to deploy the chat UI into"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Two private subnet IDs (across AZs)"
}

variable "ami_id" {
  type        = string
  description = "Custom RHEL AMI ID for the Streamlit UI EC2 instances"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_cidrs" {
  type        = list(string)
  description = "VPC CIDR blocks for security group rules"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type"
}

variable "agent_api_base_url" {
  type        = string
  description = "Base URL for the private API Gateway agent endpoint"
}

variable "agent_api_auth_mode" {
  type        = string
  default     = "none"
  description = "Auth mode for the agent API: iam, api_key, or none"
}

variable "create_app_s3_bucket" {
  type        = bool
  default     = false
  description = "When true, the module creates and manages the S3 artifact bucket"
}

variable "app_s3_bucket" {
  type        = string
  default     = ""
  description = "Existing S3 bucket name for the ui_module artifact (ignored when create_app_s3_bucket = true)"
}

variable "app_s3_key" {
  type        = string
  default     = "ui_module/ui_module.tar.gz"
  description = "S3 object key for the ui_module tar.gz artifact"
}

variable "create_execute_api_vpce" {
  type        = bool
  default     = true
  description = "Whether to create an execute-api VPC endpoint"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags for all resources"
}

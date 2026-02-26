variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC to deploy into"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Two private subnet IDs (across AZs) for EC2 and VPC endpoints"

  validation {
    condition     = length(var.private_subnet_ids) == 2
    error_message = "Exactly two private subnet IDs are required."
  }
}

variable "ami_id" {
  type        = string
  description = "Custom RHEL AMI ID for the Streamlit UI EC2 instances"
}

variable "region" {
  type        = string
  description = "AWS region for resource creation and VPC endpoint service names"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "EC2 instance type for the UI server"
}

variable "ui_port" {
  type        = number
  default     = 8501
  description = "Port Streamlit listens on"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block used for security group ingress rules"
}

variable "iam_instance_profile_name" {
  type        = string
  default     = ""
  description = "Optional IAM instance profile name to attach to UI EC2 instances (for API auth, SSM, CloudWatch, etc.)"
}

variable "agent_api_base_url" {
  type        = string
  default     = ""
  description = "Base URL for the private API Gateway agent endpoint (set via user data env var)"
}

variable "agent_api_auth_mode" {
  type        = string
  default     = "none"
  description = "Auth mode for the agent API: iam, api_key, or none"

  validation {
    condition     = contains(["iam", "api_key", "none"], var.agent_api_auth_mode)
    error_message = "agent_api_auth_mode must be one of: iam, api_key, none."
  }
}

variable "create_execute_api_vpce" {
  type        = bool
  default     = true
  description = "Whether to create an interface VPC endpoint for execute-api (private API Gateway)"
}

variable "additional_vpce_services" {
  type        = list(string)
  default     = []
  description = "Additional AWS service suffixes to create interface VPC endpoints for (e.g. [\"ssm\", \"ssmmessages\", \"ec2messages\", \"logs\"])"
}

variable "asg_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of EC2 instances in the ASG"
}

variable "asg_max_size" {
  type        = number
  default     = 2
  description = "Maximum number of EC2 instances in the ASG"
}

variable "asg_desired_capacity" {
  type        = number
  default     = 1
  description = "Desired number of EC2 instances in the ASG"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources"
}

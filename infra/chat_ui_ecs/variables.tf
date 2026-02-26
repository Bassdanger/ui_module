variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC to deploy into"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Two private subnet IDs (across AZs) for Fargate tasks, ALB, and VPC endpoints"

  validation {
    condition     = length(var.private_subnet_ids) == 2
    error_message = "Exactly two private subnet IDs are required."
  }
}

variable "region" {
  type        = string
  description = "AWS region for resource creation and VPC endpoint service names"
}

variable "vpc_cidrs" {
  type        = list(string)
  description = "VPC CIDR blocks — used for ALB security group ingress rules"
}

variable "ui_port" {
  type        = number
  default     = 8501
  description = "Port Streamlit listens on inside the container"
}

# ---------------------------------------------------------------------------
# Container / ECS
# ---------------------------------------------------------------------------

variable "container_image" {
  type        = string
  default     = ""
  description = "Full container image URI (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/chat-ui:latest). When empty, the module expects you to push to the ECR repo it creates."
}

variable "task_cpu" {
  type        = number
  default     = 256
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
}

variable "task_memory" {
  type        = number
  default     = 512
  description = "Fargate task memory in MiB"
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Number of Fargate tasks to run"
}

variable "create_ecr_repository" {
  type        = bool
  default     = true
  description = "Whether to create an ECR repository for the UI container image"
}

# ---------------------------------------------------------------------------
# Agent API
# ---------------------------------------------------------------------------

variable "agent_api_base_url" {
  type        = string
  default     = ""
  description = "Base URL for the private API Gateway agent endpoint (passed as env var to the container)"
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

# ---------------------------------------------------------------------------
# VPC Endpoints
# ---------------------------------------------------------------------------

variable "create_execute_api_vpce" {
  type        = bool
  default     = true
  description = "Whether to create an interface VPC endpoint for execute-api (private API Gateway)"
}

variable "create_s3_gateway_endpoint" {
  type        = bool
  default     = true
  description = "Whether to create an S3 Gateway endpoint (required for ECR image layer pulls in private subnets)"
}

variable "additional_vpce_services" {
  type        = list(string)
  default     = []
  description = "Extra AWS service suffixes to create interface VPC endpoints for, beyond the ones the module creates automatically (ecr.api, ecr.dkr, logs)"
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

variable "additional_iam_policy_arns" {
  type        = list(string)
  default     = []
  description = "Extra IAM managed policy ARNs to attach to the ECS task role"
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources"
}

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "chat_ui_ecs" {
  source = "../../infra/chat_ui_ecs"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  region             = var.region
  vpc_cidrs          = var.vpc_cidrs

  agent_api_base_url  = var.agent_api_base_url
  agent_api_auth_mode = var.agent_api_auth_mode

  container_image       = var.container_image
  create_ecr_repository = true

  create_execute_api_vpce  = var.create_execute_api_vpce
  create_s3_gateway_endpoint = true

  tags = var.tags
}

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

module "chat_ui_ec2" {
  source = "../../infra/chat_ui_ec2"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  ami_id             = var.ami_id
  region             = var.region
  vpc_cidrs          = var.vpc_cidrs
  instance_type      = var.instance_type

  agent_api_base_url  = var.agent_api_base_url
  agent_api_auth_mode = var.agent_api_auth_mode

  create_app_s3_bucket = var.create_app_s3_bucket
  app_s3_bucket        = var.app_s3_bucket
  app_s3_key           = var.app_s3_key

  create_execute_api_vpce = var.create_execute_api_vpce

  tags = var.tags
}

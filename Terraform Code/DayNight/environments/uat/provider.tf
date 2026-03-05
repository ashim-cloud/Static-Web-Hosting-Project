# Terraform and provider versions for this environment.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AWS provider configuration for UAT Region.
provider "aws" {
  region = var.aws_region
}

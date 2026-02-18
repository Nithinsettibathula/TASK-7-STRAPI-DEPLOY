terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # This ensures you use the latest stable version of the AWS plugin
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Best Practice: Default Tags
  # This automatically tags every resource (RDS, ECS, etc.) so you know who owns it
  default_tags {
    tags = {
      Project   = "Strapi-Fargate-Deployment"
      ManagedBy = "Terraform"
      Owner     = "Nithin"
    }
  }
}
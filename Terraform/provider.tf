terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Credentials from environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
  # OR use AWS CLI profile: AWS_PROFILE=<profile_name>
  # Do NOT hardcode credentials in this file
}

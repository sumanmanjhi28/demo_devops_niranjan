# Terraform Backend Configuration
# S3 backend for remote state storage and team collaboration
# State file is stored in S3 with DynamoDB for state locking

terraform {
  backend "s3" {
    bucket         = "demo-devops-terraform-state-284874841655"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Terraform Backend Configuration
# S3 backend for remote state storage and team collaboration
# State file is stored in S3 with DynamoDB for state locking

# IMPORTANT: Uncomment this after running 'backend-setup' workflow first!
# Or run the backend-setup workflow to create S3 bucket and DynamoDB table

terraform {
  backend "s3" {
    bucket         = "demo-devops-terraform-state-284874841655"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "demo-devops-terraform-locks"
  }
}

# To enable backend:
# 1. Run GitHub Actions workflow: "Terraform Backend Setup" → action: setup
# 2. Uncomment the backend block above (if commented)
# 3. Run: terraform init -migrate-state (if migrating from local state)


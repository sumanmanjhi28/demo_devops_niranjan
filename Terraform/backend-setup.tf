# ========================================
# TERRAFORM BACKEND RESOURCES
# These resources store Terraform state
# Keep these persistent (low cost ~$1/month)
# ========================================

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "${var.app_name}-terraform-state-${data.aws_caller_identity.current.account_id}"
  force_destroy = false # Protect state from accidental deletion

  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.app_name}-terraform-state"
      Purpose     = "Terraform state storage"
      Persistence = "always"
    }
  )
}

# Enable versioning on state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption for state bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for state bucket
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${var.app_name}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST" # No fixed cost
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = false # Set to true in production
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.app_name}-terraform-locks"
      Purpose     = "Terraform state locking"
      Persistence = "always"
    }
  )
}

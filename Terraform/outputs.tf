output "elastic_beanstalk_app_name" {
  description = "Elastic Beanstalk application name"
  value       = aws_elastic_beanstalk_application.main.name
}

output "elastic_beanstalk_environment_name" {
  description = "Elastic Beanstalk environment name"
  value       = aws_elastic_beanstalk_environment.main.name
}

output "elastic_beanstalk_endpoint" {
  description = "Elastic Beanstalk environment endpoint (CNAME)"
  value       = aws_elastic_beanstalk_environment.main.endpoint_url
}

output "elastic_beanstalk_environment_url" {
  description = "Full URL to access the application"
  value       = "http://${aws_elastic_beanstalk_environment.main.endpoint_url}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group ID for Elastic Beanstalk"
  value       = aws_security_group.eb.id
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.eb.name
}

output "s3_bucket_name" {
  description = "S3 bucket name for deployments"
  value       = aws_s3_bucket.eb_deployment.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for deployments"
  value       = aws_s3_bucket.eb_deployment.arn
}

output "s3_bucket_region" {
  description = "S3 bucket region"
  value       = aws_s3_bucket.eb_deployment.region
}

# GitHub Actions Credentials
output "github_actions_access_key_id" {
  description = "AWS Access Key ID for GitHub Actions (store as secret AWS_ACCESS_KEY_ID)"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "AWS Secret Access Key for GitHub Actions (store as secret AWS_SECRET_ACCESS_KEY)"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "github_actions_setup_guide" {
  description = "Instructions for setting up GitHub Actions secrets"
  value = <<-EOT
    1. Go to GitHub repository Settings → Secrets and variables → Actions
    2. Create new repository secrets:
       - Name: AWS_ACCESS_KEY_ID
         Value: ${aws_iam_access_key.github_actions.id}
       - Name: AWS_SECRET_ACCESS_KEY
         Value: ${aws_iam_access_key.github_actions.secret}
    3. Update your GitHub Actions workflow with:
       - aws-region: ${var.aws_region}
       - application-name: ${aws_elastic_beanstalk_application.main.name}
       - environment-name: ${aws_elastic_beanstalk_environment.main.name}
       - S3_BUCKET: ${aws_s3_bucket.eb_deployment.bucket}
  EOT
}

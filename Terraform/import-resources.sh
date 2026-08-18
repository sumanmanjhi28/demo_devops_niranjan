#!/bin/bash
# Script to import existing AWS resources into Terraform state

# Set your AWS region
AWS_REGION="us-east-1"
APP_NAME="demo-devops"
ENV_NAME="dev"

echo "Importing existing AWS resources into Terraform state..."

# Import IAM Roles
terraform import aws_iam_role.eb_instance_role ${APP_NAME}-eb-instance-role
terraform import aws_iam_role.eb_service_role ${APP_NAME}-eb-service-role

# Import Elastic Beanstalk Application
terraform import aws_elastic_beanstalk_application.main ${APP_NAME}

# Import CloudWatch Log Group
terraform import aws_cloudwatch_log_group.eb "/aws/elasticbeanstalk/${APP_NAME}-${ENV_NAME}"

# Import IAM User
terraform import aws_iam_user.github_actions ${APP_NAME}-github-actions

# Note: You'll need to get these IDs from AWS Console or CLI
echo ""
echo "For S3 bucket, run:"
echo "terraform import aws_s3_bucket.eb_deployment <bucket-name>"
echo ""
echo "For other resources (VPC, subnets, etc.), if they were created by previous run:"
echo "terraform import aws_vpc.main <vpc-id>"
echo "terraform import aws_subnet.public <subnet-id>"
echo "terraform import aws_subnet.private <subnet-id>"
echo "terraform import aws_internet_gateway.main <igw-id>"
echo "terraform import aws_route_table.public <route-table-id>"
echo "terraform import aws_security_group.eb <security-group-id>"
echo "terraform import aws_iam_instance_profile.eb_profile ${APP_NAME}-eb-instance-profile"

echo ""
echo "Import complete! Run 'terraform plan' to verify."

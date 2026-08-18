# Terraform State Management Guide

## Current Issue

Resources already exist in AWS but Terraform doesn't have a state file tracking them. This happens when:
- State file was lost/deleted
- Running Terraform from a different location
- State file is not shared across team/CI

## Solutions

### Option 1: Destroy and Recreate (Easiest but Destructive)

**⚠️ WARNING: This will delete all existing resources!**

```bash
# Manually delete resources in AWS Console or via CLI:
aws elasticbeanstalk delete-application --application-name demo-devops --terminate-env-by-force
aws iam delete-user --user-name demo-devops-github-actions
aws iam delete-role --role-name demo-devops-eb-instance-role
aws iam delete-role --role-name demo-devops-eb-service-role
aws logs delete-log-group --log-group-name /aws/elasticbeanstalk/demo-devops-dev
# ... delete other resources

# Then run Terraform fresh:
terraform init
terraform plan
terraform apply
```

### Option 2: Import Existing Resources (Recommended)

Import existing resources into Terraform state:

```bash
cd Terraform

# Import IAM resources
terraform import aws_iam_role.eb_instance_role demo-devops-eb-instance-role
terraform import aws_iam_role.eb_service_role demo-devops-eb-service-role
terraform import aws_iam_instance_profile.eb_profile demo-devops-eb-instance-profile
terraform import aws_iam_user.github_actions demo-devops-github-actions

# Import Elastic Beanstalk
terraform import aws_elastic_beanstalk_application.main demo-devops

# Import CloudWatch
terraform import aws_cloudwatch_log_group.eb /aws/elasticbeanstalk/demo-devops-dev

# Get the S3 bucket name and import it
terraform import aws_s3_bucket.eb_deployment <your-bucket-name>

# If VPC and networking were created, get their IDs from AWS Console and import:
# terraform import aws_vpc.main vpc-xxxxxxxxx
# terraform import aws_subnet.public subnet-xxxxxxxxx
# terraform import aws_subnet.private subnet-xxxxxxxxx
# terraform import aws_internet_gateway.main igw-xxxxxxxxx
# terraform import aws_route_table.public rtb-xxxxxxxxx
# terraform import aws_security_group.eb sg-xxxxxxxxx

# After importing, verify:
terraform plan
```

### Option 3: Setup Remote Backend (Best for Teams/CI/CD)

Store state in S3 for shared access:

1. **Create S3 bucket and DynamoDB table:**

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket demo-devops-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket demo-devops-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket demo-devops-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region us-east-1
```

2. **Uncomment backend configuration in `backend.tf`**

3. **Migrate state:**

```bash
terraform init -migrate-state
```

## Current State Configuration

**Backend:** Local (default)
**Location:** `./terraform.tfstate` (currently missing)
**Issue:** State file lost or not committed to version control

## Recommendations

1. **For local development:** Use Option 2 (import) and keep state file backed up
2. **For team/CI/CD:** Use Option 3 (remote backend in S3)
3. **Never commit** state files to git (already in `.gitignore`)
4. **Always backup** state files before making changes

## State File Best Practices

- ✅ Use remote backend (S3) for teams
- ✅ Enable state locking (DynamoDB)
- ✅ Enable bucket versioning
- ✅ Encrypt state files
- ✅ Regular backups
- ❌ Never commit state to git
- ❌ Never manually edit state files
- ❌ Never share state files via email/chat

## Troubleshooting

**State file missing:**
- Import existing resources
- Or destroy and recreate

**State drift (resources changed outside Terraform):**
```bash
terraform refresh
terraform plan
```

**State locked:**
```bash
# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

**Import all IAM role policy attachments:**
```bash
# After importing the role, import policy attachments
terraform import aws_iam_role_policy_attachment.eb_worker demo-devops-eb-instance-role/arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier
terraform import aws_iam_role_policy_attachment.eb_multicontainer_docker demo-devops-eb-instance-role/arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker
terraform import aws_iam_role_policy_attachment.cloudwatch_logs demo-devops-eb-instance-role/arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
terraform import aws_iam_role_policy_attachment.ssm_access demo-devops-eb-instance-role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
terraform import aws_iam_role_policy_attachment.eb_service demo-devops-eb-service-role/arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth
terraform import aws_iam_role_policy_attachment.eb_service_basic demo-devops-eb-service-role/arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService
```

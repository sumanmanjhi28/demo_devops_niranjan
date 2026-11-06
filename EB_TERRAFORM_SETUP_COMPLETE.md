# Elastic Beanstalk with S3 - Terraform Setup Complete ✅

## Summary

Your Terraform configuration now supports **dual deployment** to both **Amazon EKS** and **Elastic Beanstalk** with S3 storage for application versions.

---

## What Was Added

### 1. **Terraform Resources** (`Terraform/main.tf`)

#### S3 Resources
- ✅ S3 bucket for EB application versions (with force_destroy)
- ✅ Bucket versioning enabled
- ✅ AES256 server-side encryption
- ✅ Public access blocked

#### IAM Resources
- ✅ IAM role for EB EC2 instances
- ✅ IAM instance profile for EB
- ✅ IAM role for EB service
- ✅ Managed policy attachments (WebTier, MulticontainerDocker, WorkerTier, CloudWatch)
- ✅ GitHub Actions IAM policy for EB deployments

#### Elastic Beanstalk Resources
- ✅ EB Application
- ✅ EB Environment with full configuration:
  - VPC integration (uses same VPC as EKS)
  - Auto scaling (1-2 instances, configurable)
  - Application Load Balancer
  - CloudWatch Logs streaming
  - Rolling deployment strategy
  - Enhanced health reporting
  
#### Security Resources
- ✅ Security group for EB instances (HTTP/HTTPS access)

#### Monitoring
- ✅ CloudWatch Log Group with 7-day retention

### 2. **Variables** (`Terraform/variables.tf`)

Added configuration options:
```hcl
enable_elastic_beanstalk  # Toggle EB on/off (default: false)
eb_instance_type          # Instance type (default: t3.micro)
eb_solution_stack         # Node.js platform version
eb_min_instances          # Min auto scaling (default: 1)
eb_max_instances          # Max auto scaling (default: 2)
```

### 3. **Outputs** (`Terraform/outputs.tf`)

New outputs for EB:
- `eb_application_name` - EB application name
- `eb_environment_name` - EB environment name
- `eb_environment_url` - Application URL
- `eb_cname` - EB CNAME for access
- `eb_s3_bucket` - S3 bucket for deployments
- `eb_deployment_guide` - Full deployment instructions

### 4. **Documentation**

Created comprehensive guides:

#### `Terraform/DUAL_DEPLOYMENT_GUIDE.md`
- Full guide for using both EKS and EB
- Deployment methods for each platform
- GitHub Actions integration examples
- Cost comparison
- When to use each platform
- Monitoring and troubleshooting

#### `Terraform/ENABLE_EB.md`
- Quick start guide for enabling EB
- Step-by-step deployment instructions
- Configuration options
- Cost estimation
- Troubleshooting tips

#### `Terraform/terraform.tfvars.example`
- Updated with all EB variables
- Clear examples and defaults

---

## How to Use

### Quick Start: Enable Elastic Beanstalk

1. **Edit configuration:**
```bash
cd Terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set:
# enable_elastic_beanstalk = true
```

2. **Apply Terraform:**
```bash
terraform init
terraform plan
terraform apply
```

3. **Get deployment info:**
```bash
terraform output eb_deployment_guide
```

### Deploy Your Application

#### Option A: Manual Deployment

```bash
# 1. Package app
zip -r app.zip . -x "node_modules/*" ".git/*" "Terraform/*" "k8s/*"

# 2. Upload to S3
EB_BUCKET=$(terraform output -raw eb_s3_bucket)
aws s3 cp app.zip s3://$EB_BUCKET/app-v1.zip

# 3. Create app version
aws elasticbeanstalk create-application-version \
  --application-name demo-devops \
  --version-label v1.0 \
  --source-bundle S3Bucket="$EB_BUCKET",S3Key="app-v1.zip"

# 4. Deploy
aws elasticbeanstalk update-environment \
  --environment-name demo-devops-dev \
  --version-label v1.0

# 5. Access
open http://$(terraform output -raw eb_cname)
```

#### Option B: GitHub Actions Deployment

Create `.github/workflows/deploy-eb.yml` (see DUAL_DEPLOYMENT_GUIDE.md for full example)

---

## Architecture

### Current Setup (EKS Only)
```
┌─────────────────────────────────────────┐
│            AWS Account                   │
│  ┌────────────────────────────────────┐ │
│  │  VPC (10.0.0.0/16)                 │ │
│  │  ┌──────────┐      ┌──────────┐   │ │
│  │  │ Public   │      │ Private  │   │ │
│  │  │ Subnets  │      │ Subnets  │   │ │
│  │  │          │      │          │   │ │
│  │  │  [ALB]   │─────▶│ [EKS]   │   │ │
│  │  │          │      │ Nodes    │   │ │
│  │  └──────────┘      └──────────┘   │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ ECR Repository                     │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### With Elastic Beanstalk Enabled
```
┌──────────────────────────────────────────┐
│            AWS Account                    │
│  ┌─────────────────────────────────────┐ │
│  │  VPC (10.0.0.0/16)                  │ │
│  │  ┌──────────┐      ┌──────────┐    │ │
│  │  │ Public   │      │ Private  │    │ │
│  │  │ Subnets  │      │ Subnets  │    │ │
│  │  │          │      │          │    │ │
│  │  │  [ALB]   │─────▶│ [EKS]   │    │ │
│  │  │          │      │ Nodes    │    │ │
│  │  │          │      │          │    │ │
│  │  │  [ALB]   │─────▶│ [EB]    │    │ │
│  │  │          │      │ Instances│    │ │
│  │  └──────────┘      └──────────┘    │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │ ECR Repository                      │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │ S3 Bucket (EB versions)             │ │
│  └─────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

---

## Cost Breakdown

### EKS Only (~$181/month)
- EKS Control Plane: $73/month
- 2x t3.medium nodes: $60/month
- NAT Gateway: $32/month
- Application Load Balancer: $16/month

### EKS + Elastic Beanstalk (~$205-213/month)
- EKS (above): $181/month
- 1-2x t3.micro instances: $7-15/month
- EB Application Load Balancer: $16/month
- S3 storage: <$1/month

### Elastic Beanstalk Only (~$24-32/month)
If you disable EKS:
- 1-2x t3.micro instances: $7-15/month
- Application Load Balancer: $16/month
- S3 storage: <$1/month
- VPC/Subnets: Free tier

---

## Key Features

### Conditional Provisioning
- EB resources only created when `enable_elastic_beanstalk = true`
- No impact on existing EKS setup when disabled
- Clean enable/disable without affecting other resources

### Shared Infrastructure
- Uses same VPC as EKS
- Reuses public subnets
- Shared IAM user for GitHub Actions
- Consistent tagging across resources

### Production Ready
- Auto scaling configured (1-2 instances)
- Load balancer with health checks
- CloudWatch logging enabled
- Rolling deployments
- Enhanced health monitoring
- S3 versioning for rollbacks
- Encrypted S3 bucket
- Public access blocked on S3

### Security
- Proper IAM roles and policies
- Security groups with HTTP/HTTPS only
- Instance profile for EC2 permissions
- S3 bucket encryption (AES256)
- VPC-isolated instances

---

## Next Steps

### 1. Review Configuration
```bash
cd Terraform
cat DUAL_DEPLOYMENT_GUIDE.md
cat ENABLE_EB.md
```

### 2. Enable and Deploy
```bash
# Enable EB in terraform.tfvars
terraform apply

# Deploy your application
# Follow steps in ENABLE_EB.md
```

### 3. Set Up CI/CD
- Add GitHub Actions workflow for EB
- Configure deployment strategy (blue-green, rolling, etc.)
- Set up monitoring alerts

### 4. Monitor
```bash
# View EB environment health
aws elasticbeanstalk describe-environment-health \
  --environment-name demo-devops-dev \
  --attribute-names All

# View logs
aws logs tail /aws/elasticbeanstalk/demo-devops-dev --follow
```

---

## Configuration Reference

### Minimal Configuration (terraform.tfvars)
```hcl
aws_region = "us-east-1"
app_name   = "demo-devops"
env_name   = "dev"

# Enable EB
enable_elastic_beanstalk = true
```

### Full Configuration (terraform.tfvars)
```hcl
aws_region = "us-east-1"
app_name   = "demo-devops"
env_name   = "dev"

# EKS Configuration
instance_type = "t3.medium"
min_size      = 1
max_size      = 3
desired_size  = 2
eks_version   = "1.31"

# Elastic Beanstalk Configuration
enable_elastic_beanstalk = true
eb_instance_type         = "t3.micro"
eb_solution_stack        = "64bit Amazon Linux 2023 v6.1.11 running Node.js 22"
eb_min_instances         = 1
eb_max_instances         = 2

# Network
vpc_cidr = "10.0.0.0/16"

# Tags
tags = {
  Terraform   = "true"
  Environment = "dev"
  Project     = "demo-devops"
}
```

---

## Troubleshooting

### Common Issues

#### 1. Solution Stack Not Found
**Error:** `No Solution Stack named '...' found`

**Solution:**
```bash
# List available stacks
aws elasticbeanstalk list-available-solution-stacks \
  --query 'SolutionStacks[?contains(@, `Node.js`)]' \
  --output table

# Update in terraform.tfvars:
eb_solution_stack = "<valid-stack-name>"
```

#### 2. S3 Bucket Access Denied
**Error:** `Access Denied` when uploading to S3

**Solution:**
```bash
# Check bucket exists
aws s3 ls | grep demo-devops

# Check your AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
terraform output github_actions_access_key_id
```

#### 3. Environment Creation Timeout
**Error:** Environment stuck in "Launching" state

**Solution:**
```bash
# Check events
aws elasticbeanstalk describe-events \
  --environment-name demo-devops-dev \
  --max-records 50

# Check security groups allow traffic
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=demo-devops-eb-instances-sg"
```

---

## Documentation Files

| File | Purpose |
|------|---------|
| `Terraform/main.tf` | Infrastructure code with EB resources |
| `Terraform/variables.tf` | Configuration variables for EB |
| `Terraform/outputs.tf` | EB deployment information |
| `Terraform/DUAL_DEPLOYMENT_GUIDE.md` | Complete guide for both platforms |
| `Terraform/ENABLE_EB.md` | Quick start for EB |
| `Terraform/terraform.tfvars.example` | Configuration template |
| `EB_TERRAFORM_SETUP_COMPLETE.md` | This file |

---

## Support and Resources

### Documentation
- 📖 [DUAL_DEPLOYMENT_GUIDE.md](./Terraform/DUAL_DEPLOYMENT_GUIDE.md) - Complete guide
- 🚀 [ENABLE_EB.md](./Terraform/ENABLE_EB.md) - Quick start
- 📝 [AWS EB Documentation](https://docs.aws.amazon.com/elasticbeanstalk/)

### Commands Reference
```bash
# Enable EB
terraform apply -var="enable_elastic_beanstalk=true"

# View outputs
terraform output

# Deploy app
# (See ENABLE_EB.md for full commands)

# Disable EB
terraform apply -var="enable_elastic_beanstalk=false"

# Cleanup everything
terraform destroy
```

---

## Summary Checklist

- ✅ S3 bucket for application versions
- ✅ Elastic Beanstalk application and environment
- ✅ IAM roles and policies (instance, service, GitHub Actions)
- ✅ Security groups for HTTP/HTTPS
- ✅ Auto scaling configuration (1-2 instances)
- ✅ Application Load Balancer
- ✅ CloudWatch Logs with streaming
- ✅ VPC integration with EKS
- ✅ Conditional provisioning (enable/disable)
- ✅ Terraform outputs for deployment
- ✅ Comprehensive documentation
- ✅ GitHub Actions integration guide
- ✅ Cost breakdown and comparison

---

**Your Terraform configuration is now ready to deploy applications to both EKS and Elastic Beanstalk!** 🎉

To get started, read `Terraform/ENABLE_EB.md` for step-by-step instructions.

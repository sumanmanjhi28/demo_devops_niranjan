# Quick Guide: Enable Elastic Beanstalk with S3

## Enable Elastic Beanstalk

### Option 1: Using terraform.tfvars

1. Copy the example file (if you haven't already):
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` and set:
```hcl
enable_elastic_beanstalk = true
```

3. Apply the configuration:
```bash
terraform init  # If first time
terraform plan  # Review changes
terraform apply # Provision resources
```

### Option 2: Using Command Line

```bash
terraform apply -var="enable_elastic_beanstalk=true"
```

### Option 3: Using Environment Variable

```bash
export TF_VAR_enable_elastic_beanstalk=true
terraform apply
```

---

## What Gets Provisioned

When you enable Elastic Beanstalk, Terraform creates:

✅ **S3 Bucket** for application versions
- Bucket name: `demo-devops-dev-deployment-{account-id}`
- Versioning enabled
- AES256 encryption
- Public access blocked

✅ **Elastic Beanstalk Application**
- Application name: `demo-devops`
- Platform: Node.js 22 on Amazon Linux 2023

✅ **Elastic Beanstalk Environment**
- Environment name: `demo-devops-dev`
- Instance type: `t3.micro` (configurable)
- Auto scaling: 1-2 instances (configurable)
- Load balancer: Application Load Balancer
- VPC: Uses same VPC as EKS

✅ **IAM Roles and Policies**
- EB instance role with necessary permissions
- EB service role for AWS operations
- GitHub Actions policy for EB deployments

✅ **Security Groups**
- HTTP (80) and HTTPS (443) access
- Attached to EB instances

✅ **CloudWatch Log Group**
- Log streaming enabled
- 7-day retention

---

## Verify Provisioning

```bash
# Check outputs
terraform output eb_application_name
terraform output eb_environment_url
terraform output eb_s3_bucket

# View full deployment guide
terraform output eb_deployment_guide
```

---

## Deploy Your First Application

### Step 1: Package Application

```bash
zip -r app.zip . -x "node_modules/*" ".git/*" "Terraform/*" "k8s/*" "*.md"
```

### Step 2: Upload to S3

```bash
EB_BUCKET=$(terraform output -raw eb_s3_bucket)
aws s3 cp app.zip s3://$EB_BUCKET/app-v1.zip
```

### Step 3: Create Application Version

```bash
aws elasticbeanstalk create-application-version \
  --application-name demo-devops \
  --version-label v1.0 \
  --source-bundle S3Bucket="$EB_BUCKET",S3Key="app-v1.zip" \
  --region us-east-1
```

### Step 4: Deploy

```bash
aws elasticbeanstalk update-environment \
  --environment-name demo-devops-dev \
  --version-label v1.0 \
  --region us-east-1
```

### Step 5: Access Application

```bash
# Get URL
terraform output eb_environment_url

# Or open in browser
open http://$(terraform output -raw eb_cname)
```

---

## Disable Elastic Beanstalk

To remove EB resources while keeping EKS:

1. Edit `terraform.tfvars`:
```hcl
enable_elastic_beanstalk = false
```

2. Apply changes:
```bash
terraform apply
```

This will destroy:
- Elastic Beanstalk environment
- Elastic Beanstalk application
- S3 bucket (with all versions)
- IAM roles and policies for EB
- Security groups for EB

**Note:** EKS resources remain untouched.

---

## Configuration Options

Customize EB settings in `terraform.tfvars`:

```hcl
# Enable/disable Elastic Beanstalk
enable_elastic_beanstalk = true

# Instance type (t3.micro, t3.small, t3.medium, etc.)
eb_instance_type = "t3.micro"

# Auto scaling limits
eb_min_instances = 1
eb_max_instances = 2

# Solution stack (Node.js version)
eb_solution_stack = "64bit Amazon Linux 2023 v6.1.11 running Node.js 22"
```

### Available Solution Stacks

To see available Node.js solution stacks:

```bash
aws elasticbeanstalk list-available-solution-stacks \
  --query 'SolutionStacks[?contains(@, `Node.js`)]' \
  --output table
```

---

## Cost Estimation

### Elastic Beanstalk Resources

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| EC2 Instance (t3.micro) | 1-2 instances | $7.30 - $14.60 |
| Application Load Balancer | Always on | ~$16.20 |
| S3 Storage | First GB free | ~$0.50 |
| Data Transfer | First GB free | Variable |
| **Estimated Total** | | **~$24-32/month** |

**Note:** Costs are approximate and depend on usage.

---

## Environment Variables

Set application environment variables in `main.tf`:

```hcl
setting {
  namespace = "aws:elasticbeanstalk:application:environment"
  name      = "YOUR_VAR_NAME"
  value     = "your-value"
}
```

Or via AWS CLI:

```bash
aws elasticbeanstalk update-environment \
  --environment-name demo-devops-dev \
  --option-settings \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=NODE_ENV,Value=production \
    Namespace=aws:elasticbeanstalk:application:environment,OptionName=PORT,Value=8080
```

---

## Monitoring

### View Environment Health

```bash
aws elasticbeanstalk describe-environment-health \
  --environment-name demo-devops-dev \
  --attribute-names All \
  --region us-east-1
```

### View Application Logs

```bash
# Tail logs
aws logs tail /aws/elasticbeanstalk/demo-devops-dev --follow

# Download bundle
aws elasticbeanstalk request-environment-info \
  --environment-name demo-devops-dev \
  --info-type bundle

# Retrieve bundle URL
aws elasticbeanstalk retrieve-environment-info \
  --environment-name demo-devops-dev \
  --info-type bundle
```

---

## Troubleshooting

### Issue: Environment creation failed

**Check:**
```bash
aws elasticbeanstalk describe-events \
  --environment-name demo-devops-dev \
  --max-records 50
```

### Issue: S3 upload fails

**Check bucket exists:**
```bash
aws s3 ls | grep demo-devops
```

**Check permissions:**
```bash
aws s3api get-bucket-policy \
  --bucket demo-devops-dev-deployment-284874841655
```

### Issue: Application not responding

**Check environment status:**
```bash
aws elasticbeanstalk describe-environments \
  --environment-names demo-devops-dev \
  --query 'Environments[0].Status'
```

**Check instance health:**
```bash
aws elasticbeanstalk describe-instances-health \
  --environment-name demo-devops-dev
```

---

## Next Steps

1. ✅ Enable Elastic Beanstalk
2. ✅ Deploy your first application
3. 📖 Read [DUAL_DEPLOYMENT_GUIDE.md](./DUAL_DEPLOYMENT_GUIDE.md) for advanced usage
4. 🚀 Set up GitHub Actions for automated deployments
5. 📊 Configure CloudWatch alarms for monitoring

---

## Additional Resources

- [Terraform Configuration](./main.tf)
- [Full Deployment Guide](./DUAL_DEPLOYMENT_GUIDE.md)
- [AWS EB CLI](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3.html)
- [EB Platform Versions](https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.nodejs)

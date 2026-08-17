# Terraform - Elastic Beanstalk Deployment

This Terraform configuration creates a complete AWS Elastic Beanstalk environment with all required dependencies.

## What's Included

- **VPC**: Custom VPC with public and private subnets
- **Internet Gateway**: For public internet access
- **Security Groups**: Configured for HTTP/HTTPS/3000 port access
- **IAM Roles**: For Elastic Beanstalk service and EC2 instances
- **Elastic Beanstalk**: Configured for Node.js 22 with auto-scaling
- **CloudWatch Logs**: For application logging and monitoring

## Prerequisites

1. **Terraform** >= 1.0 installed ([Download](https://www.terraform.io/downloads.html))
2. **AWS CLI** configured or AWS credentials set up:
   ```bash
   # Option 1: Using AWS CLI profile
   aws configure --profile myprofile
   export AWS_PROFILE=myprofile
   
   # Option 2: Using environment variables (RECOMMENDED)
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_DEFAULT_REGION=us-east-1
   ```

3. Push your code to a Git repository or create a `.zip` file for deployment

## Setup Instructions

### 1. Prepare Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Then edit `terraform.tfvars` with your desired values:
```hcl
aws_region  = "us-east-1"
app_name    = "demo-devops"
env_name    = "dev"
instance_type = "t3.micro"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan -out=tfplan
```

Review the plan to ensure all resources will be created as expected.

### 4. Apply the Configuration

```bash
terraform apply tfplan
```

This will create:
- VPC with subnets and routing
- Security groups
- IAM roles and instance profiles
- Elastic Beanstalk application and environment
- CloudWatch log groups

### 5. Deploy Your Application

After the environment is created, you need to deploy your Node.js application:

**Option A: Using Elastic Beanstalk CLI (EB CLI)**

```bash
# Install EB CLI
pip install awsebcli

# Initialize EB
eb init -p node.js-22 demo-devops --region us-east-1

# Create/deploy environment
eb create dev-env
```

**Option B: Using Terraform for Application Version**

Push your code to CodeCommit or GitHub and configure `aws_elastic_beanstalk_app_version` resource.

**Option C: Manual ZIP Upload**

1. Zip your application:
   ```bash
   zip -r app.zip . -x "node_modules/*" "terraform/*" ".git/*"
   ```

2. Upload via AWS Console:
   - Go to Elastic Beanstalk > Applications > demo-devops > Upload and deploy

## Verify Deployment

```bash
terraform output
```

This shows the Elastic Beanstalk endpoint. Access your application:
```
http://<endpoint-url>
```

## Environment Variables

For Node.js environment variables, add them in `main.tf`:

```hcl
setting {
  namespace = "aws:elasticbeanstalk:application:environment"
  name      = "PORT"
  value     = "3000"
}

setting {
  namespace = "aws:elasticbeanstalk:application:environment"
  name      = "NODE_ENV"
  value     = "production"
}
```

Then run:
```bash
terraform apply
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

## Security Notes

⚠️ **IMPORTANT**: Never commit credentials to version control!

- Use `terraform.tfvars` (add to `.gitignore`)
- Use AWS IAM roles when running from EC2
- Use AWS CLI profiles for local development
- Use environment variables for CI/CD (GitHub Actions, Jenkins, etc.)

## Troubleshooting

### Deployment Timeout
If Elastic Beanstalk takes too long:
```bash
# Check events
aws elasticbeanstalk describe-events --environment-name demo-devops-dev --region us-east-1
```

### Permissions Denied
Ensure your IAM user has these policies:
- `AWSElasticBeanstalkFullAccess`
- `AWSElasticBeanstalkAdministrator`
- `IAMFullAccess`
- `VPCFullAccess`
- `EC2FullAccess`

### Port 3000 Not Accessible
Update the security group in `main.tf`:
```hcl
ingress {
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = ["YOUR_IP/32"]  # Restrict to your IP
}
```

## Cost Estimation

This typical setup costs:
- **t3.micro**: ~$5-10/month (free tier eligible)
- **Data transfer**: ~$1-5/month
- **CloudWatch logs**: Minimal cost

**Total estimate**: $10-20/month for dev environment

## Next Steps

1. Create a CI/CD pipeline (Jenkins, GitHub Actions)
2. Add Database (RDS) support
3. Configure SSL/TLS with ACM
4. Set up monitoring alerts
5. Implement auto-scaling policies

For more info: [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

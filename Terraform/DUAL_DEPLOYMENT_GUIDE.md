# Dual Deployment Guide: EKS + Elastic Beanstalk

This Terraform configuration supports deploying your application to both **Amazon EKS** (Kubernetes) and **Elastic Beanstalk** (Platform as a Service) simultaneously or separately.

## Architecture Overview

### Default Configuration (EKS Only)
- **EKS Cluster** with managed node groups
- **ECR Repository** for Docker images
- **VPC** with public/private subnets
- **NAT Gateway** for private subnet internet access
- **Application Load Balancer** (via Kubernetes Service)

### Optional Configuration (EKS + Elastic Beanstalk)
- All EKS resources (above)
- **Elastic Beanstalk Application** with Node.js environment
- **S3 Bucket** for EB application versions (with versioning & encryption)
- **Application Load Balancer** for EB (managed by AWS)
- **Auto Scaling Group** for EB instances
- **CloudWatch Logs** for EB monitoring

---

## Quick Start

### 1. Enable Elastic Beanstalk (Optional)

Edit your `terraform.tfvars` file and set:

```hcl
enable_elastic_beanstalk = true
```

### 2. Apply Terraform Configuration

```bash
cd Terraform
terraform init
terraform plan
terraform apply
```

### 3. Get Deployment Information

```bash
# View all outputs
terraform output

# EKS-specific outputs
terraform output eks_cluster_name
terraform output ecr_repository_url

# EB-specific outputs (if enabled)
terraform output eb_environment_url
terraform output eb_s3_bucket
```

---

## Configuration Variables

### EKS Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `instance_type` | EC2 instance type for EKS nodes | `t3.medium` |
| `min_size` | Minimum number of EKS nodes | `1` |
| `max_size` | Maximum number of EKS nodes | `3` |
| `desired_size` | Desired number of EKS nodes | `2` |
| `eks_version` | EKS cluster version | `1.31` |

### Elastic Beanstalk Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_elastic_beanstalk` | Enable EB deployment | `false` |
| `eb_instance_type` | EC2 instance type for EB | `t3.micro` |
| `eb_solution_stack` | EB solution stack | `64bit Amazon Linux 2023 v6.1.11 running Node.js 22` |
| `eb_min_instances` | Minimum EB instances | `1` |
| `eb_max_instances` | Maximum EB instances | `2` |

---

## Deployment Methods

### Method 1: Deploy to EKS (Kubernetes)

#### Step 1: Build and Push Docker Image

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Build and tag image
docker build -t demo-devops:latest .
docker tag demo-devops:latest $(terraform output -raw ecr_repository_url):latest

# Push to ECR
docker push $(terraform output -raw ecr_repository_url):latest
```

#### Step 2: Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw eks_cluster_name)
```

#### Step 3: Deploy to Kubernetes

```bash
# Update image in deployment manifest
export ECR_IMAGE=$(terraform output -raw ecr_repository_url):latest
sed -i "s|DOCKER_IMAGE_PLACEHOLDER|$ECR_IMAGE|g" k8s/deployment.yaml

# Apply manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Get LoadBalancer URL
kubectl get svc demo-devops-service
```

---

### Method 2: Deploy to Elastic Beanstalk

#### Step 1: Package Application

```bash
# Create deployment package (exclude node_modules, .git, etc.)
zip -r app.zip . -x "node_modules/*" ".git/*" "Terraform/*" "k8s/*" "*.md"
```

#### Step 2: Upload to S3

```bash
# Get S3 bucket name
export EB_BUCKET=$(terraform output -raw eb_s3_bucket)

# Upload application package
aws s3 cp app.zip s3://$EB_BUCKET/app-$(date +%Y%m%d-%H%M%S).zip
```

#### Step 3: Create Application Version

```bash
# Get application and environment names
export EB_APP=$(terraform output -raw eb_application_name)
export EB_ENV=$(terraform output -raw eb_environment_name)
export VERSION_LABEL="v$(date +%Y%m%d-%H%M%S)"

# Create application version
aws elasticbeanstalk create-application-version \
  --application-name $EB_APP \
  --version-label $VERSION_LABEL \
  --source-bundle S3Bucket="$EB_BUCKET",S3Key="app-$(date +%Y%m%d-%H%M%S).zip" \
  --region us-east-1
```

#### Step 4: Deploy to Environment

```bash
# Deploy the version
aws elasticbeanstalk update-environment \
  --environment-name $EB_ENV \
  --version-label $VERSION_LABEL \
  --region us-east-1

# Monitor deployment
aws elasticbeanstalk describe-environments \
  --environment-names $EB_ENV \
  --region us-east-1 \
  --query 'Environments[0].Status' \
  --output text
```

#### Step 5: Access Application

```bash
# Get application URL
terraform output eb_environment_url

# Or use:
echo "http://$(terraform output -raw eb_cname)"
```

---

## GitHub Actions Integration

### For EKS Deployment

Use the existing `.github/workflows/deploy.yml` workflow. It automatically:
1. Builds Docker image
2. Pushes to ECR
3. Deploys to EKS cluster

### For Elastic Beanstalk Deployment

Create `.github/workflows/deploy-eb.yml`:

```yaml
name: Deploy to Elastic Beanstalk

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Deploy to EB'
        required: true
        type: choice
        options:
          - deploy

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: github.event.inputs.action == 'deploy'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Package application
        run: |
          zip -r app-${{ github.sha }}.zip . \
            -x "node_modules/*" ".git/*" "Terraform/*" "k8s/*" "*.md" ".github/*"

      - name: Upload to S3
        run: |
          aws s3 cp app-${{ github.sha }}.zip \
            s3://demo-devops-dev-deployment-284874841655/app-${{ github.sha }}.zip

      - name: Create EB application version
        run: |
          aws elasticbeanstalk create-application-version \
            --application-name demo-devops \
            --version-label v-${{ github.sha }} \
            --source-bundle S3Bucket="demo-devops-dev-deployment-284874841655",S3Key="app-${{ github.sha }}.zip"

      - name: Deploy to EB environment
        run: |
          aws elasticbeanstalk update-environment \
            --environment-name demo-devops-dev \
            --version-label v-${{ github.sha }}

      - name: Wait for deployment
        run: |
          aws elasticbeanstalk wait environment-updated \
            --environment-names demo-devops-dev

      - name: Get environment URL
        run: |
          CNAME=$(aws elasticbeanstalk describe-environments \
            --environment-names demo-devops-dev \
            --query 'Environments[0].CNAME' \
            --output text)
          echo "Application deployed to: http://$CNAME"
```

---

## Monitoring and Logs

### EKS Monitoring

```bash
# View pod logs
kubectl logs -f deployment/demo-devops

# View pod status
kubectl get pods -o wide

# View service status
kubectl describe svc demo-devops-service

# CloudWatch Logs
aws logs tail /aws/eks/demo-devops-eks/cluster --follow
```

### Elastic Beanstalk Monitoring

```bash
# View environment health
aws elasticbeanstalk describe-environment-health \
  --environment-name demo-devops-dev \
  --attribute-names All

# View recent events
aws elasticbeanstalk describe-events \
  --environment-name demo-devops-dev \
  --max-records 20

# CloudWatch Logs
aws logs tail /aws/elasticbeanstalk/demo-devops-dev --follow
```

---

## Cost Comparison

### EKS Deployment (~$73/month)
- EKS cluster: $73/month
- 2x t3.medium nodes: ~$60/month
- NAT Gateway: ~$32/month
- Load Balancer: ~$16/month
- **Total: ~$181/month**

### Elastic Beanstalk Deployment (~$15/month)
- 1-2x t3.micro instances: ~$7-15/month
- Load Balancer: ~$16/month
- S3 storage: <$1/month
- **Total: ~$24-32/month**

### Dual Deployment (~$205/month)
- Combines both above
- Shared VPC and networking costs

---

## When to Use Each Deployment Method

### Use EKS When:
- Need full Kubernetes features and flexibility
- Running microservices architecture
- Require fine-grained control over orchestration
- Need to run multiple containerized applications
- Team has Kubernetes expertise

### Use Elastic Beanstalk When:
- Simple monolithic Node.js application
- Want AWS-managed platform
- Need quick deployment with minimal config
- Cost-sensitive workload
- Limited DevOps resources

### Use Both When:
- Gradual migration from EB to EKS
- A/B testing deployment strategies
- Blue-green deployment across platforms
- Different environments (dev on EB, prod on EKS)

---

## Cleanup

### Remove Elastic Beanstalk Only

```bash
# In terraform.tfvars, set:
enable_elastic_beanstalk = false

# Apply changes
terraform apply
```

### Remove Everything

```bash
terraform destroy
```

---

## Troubleshooting

### EB Deployment Fails

```bash
# Check environment status
aws elasticbeanstalk describe-environments \
  --environment-names demo-devops-dev

# Check recent events
aws elasticbeanstalk describe-events \
  --environment-name demo-devops-dev \
  --max-records 50
```

### EKS Pods Not Starting

```bash
# Describe pod for events
kubectl describe pod <pod-name>

# Check node status
kubectl get nodes

# View logs
kubectl logs <pod-name>
```

### S3 Upload Issues

```bash
# Verify bucket exists
aws s3 ls | grep demo-devops

# Check bucket permissions
aws s3api get-bucket-policy --bucket demo-devops-dev-deployment-284874841655
```

---

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS Elastic Beanstalk Documentation](https://docs.aws.amazon.com/elasticbeanstalk/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Support

For issues or questions:
1. Check Terraform outputs: `terraform output`
2. Review CloudWatch Logs
3. Check AWS Console for environment health
4. Review this guide's troubleshooting section

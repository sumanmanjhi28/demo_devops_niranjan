# ========================================
# EKS CLUSTER INFRASTRUCTURE
# ========================================

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.app_name}-vpc"
      "kubernetes.io/cluster/${var.app_name}-eks" = "shared"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-igw" }
  )
}

# Public Subnets (for Load Balancer)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.app_name}-public-subnet-${count.index + 1}"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.app_name}-eks" = "shared"
    }
  )
}

# Private Subnets (for EKS worker nodes)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.app_name}-private-subnet-${count.index + 1}"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.app_name}-eks" = "shared"
    }
  )
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-public-rt" }
  )
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-private-rt" }
  )
}

# NAT Gateway EIP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-nat-eip" }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-nat-gateway" }
  )

  depends_on = [aws_internet_gateway.main]
}

# Route Table Associations - Public
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Associations - Private
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ========================================
# EKS CLUSTER
# ========================================

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "${var.app_name}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-eks-cluster-sg" }
  )
}

# ========================================
# IAM ROLES FOR EKS
# ========================================

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.app_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policies to EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_nodes" {
  name = "${var.app_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach policies to node role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ========================================
# EKS CLUSTER AND NODE GROUP
# ========================================

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.app_name}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = var.tags
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.app_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  instance_types = [var.instance_type]

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = var.tags
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.app_name}-eks/cluster"
  retention_in_days = 7

  tags = var.tags
}

# IAM User for GitHub Actions CI/CD
resource "aws_iam_user" "github_actions" {
  name = "${var.app_name}-github-actions"
  tags = var.tags
}

# IAM Policy for GitHub Actions - ECR and EKS deployment
resource "aws_iam_user_policy" "github_actions_deploy" {
  name = "${var.app_name}-github-actions-deploy-policy"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

# Access Key for GitHub Actions User
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

# ========================================
# ELASTIC BEANSTALK WITH S3 (OPTIONAL)
# ========================================

# S3 Bucket for Elastic Beanstalk Application Versions
resource "aws_s3_bucket" "eb_deployment" {
  count  = var.enable_elastic_beanstalk ? 1 : 0
  bucket = "${var.app_name}-${var.env_name}-deployment-${data.aws_caller_identity.current.account_id}"

  force_destroy = true

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-${var.env_name}-deployment" }
  )
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "eb_deployment" {
  count  = var.enable_elastic_beanstalk ? 1 : 0
  bucket = aws_s3_bucket.eb_deployment[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "eb_deployment" {
  count  = var.enable_elastic_beanstalk ? 1 : 0
  bucket = aws_s3_bucket.eb_deployment[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "eb_deployment" {
  count  = var.enable_elastic_beanstalk ? 1 : 0
  bucket = aws_s3_bucket.eb_deployment[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ========================================
# IAM ROLES FOR ELASTIC BEANSTALK
# ========================================

# IAM Role for EB EC2 Instances
resource "aws_iam_role" "eb_instance_role" {
  count = var.enable_elastic_beanstalk ? 1 : 0
  name  = "${var.app_name}-eb-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Instance Profile for EB
resource "aws_iam_instance_profile" "eb_instance_profile" {
  count = var.enable_elastic_beanstalk ? 1 : 0
  name  = "${var.app_name}-eb-instance-profile"
  role  = aws_iam_role.eb_instance_role[0].name
}

# Attach AWS managed policies to EB instance role
resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  count      = var.enable_elastic_beanstalk ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_multicontainer_docker" {
  count      = var.enable_elastic_beanstalk ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_role_policy_attachment" "eb_worker_tier" {
  count      = var.enable_elastic_beanstalk ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_elastic_beanstalk ? 1 : 0
  role       = aws_iam_role.eb_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Role for EB Service
resource "aws_iam_role" "eb_service_role" {
  count = var.enable_elastic_beanstalk ? 1 : 0
  name  = "${var.app_name}-eb-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach service role policies
resource "aws_iam_role_policy_attachment" "eb_service" {
  count      = var.enable_elastic_beanstalk ? 1 : 0
  role       = aws_iam_role.eb_service_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_role_policy_attachment" "eb_enhanced_health" {
  count      = var.enable_elastic_beanstalk ? 1 : 0
  role       = aws_iam_role.eb_service_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

# ========================================
# ELASTIC BEANSTALK APPLICATION
# ========================================

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "main" {
  count       = var.enable_elastic_beanstalk ? 1 : 0
  name        = var.app_name
  description = "${var.app_name} Node.js application"

  tags = var.tags
}

# CloudWatch Log Group for EB
resource "aws_cloudwatch_log_group" "eb" {
  count             = var.enable_elastic_beanstalk ? 1 : 0
  name              = "/aws/elasticbeanstalk/${var.app_name}-${var.env_name}"
  retention_in_days = 7

  tags = var.tags
}

# Security Group for EB Environment
resource "aws_security_group" "eb_instances" {
  count       = var.enable_elastic_beanstalk ? 1 : 0
  name        = "${var.app_name}-eb-instances-sg"
  description = "Security group for Elastic Beanstalk instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-eb-instances-sg" }
  )
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "main" {
  count               = var.enable_elastic_beanstalk ? 1 : 0
  name                = "${var.app_name}-${var.env_name}"
  application         = aws_elastic_beanstalk_application.main[0].name
  solution_stack_name = var.eb_solution_stack
  tier                = "WebServer"

  # VPC Configuration
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", aws_subnet.public[*].id)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", aws_subnet.public[*].id)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  # Instance Configuration
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.eb_instance_type
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile[0].name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_instances[0].id
  }

  # Auto Scaling Configuration
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = var.eb_min_instances
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.eb_max_instances
  }

  # Load Balancer Configuration
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service_role[0].arn
  }

  # Environment Variables
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = "production"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "8080"
  }

  # Enhanced Health Reporting
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # CloudWatch Logs
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "7"
  }

  # Deployment Configuration
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Rolling"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = "Percentage"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = "50"
  }

  # Managed Updates
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "false"
  }

  tags = var.tags

  depends_on = [
    aws_elastic_beanstalk_application.main,
    aws_iam_role.eb_instance_role,
    aws_iam_role.eb_service_role
  ]
}

# IAM Policy for GitHub Actions - Add EB deployment permissions
resource "aws_iam_user_policy" "github_actions_eb" {
  count = var.enable_elastic_beanstalk ? 1 : 0
  name  = "${var.app_name}-github-actions-eb-policy"
  user  = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EBDeployment"
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:CreateApplicationVersion",
          "elasticbeanstalk:DescribeApplicationVersions",
          "elasticbeanstalk:DescribeEnvironments",
          "elasticbeanstalk:UpdateEnvironment",
          "elasticbeanstalk:DescribeEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3DeploymentBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.eb_deployment[0].arn,
          "${aws_s3_bucket.eb_deployment[0].arn}/*"
        ]
      }
    ]
  })
}

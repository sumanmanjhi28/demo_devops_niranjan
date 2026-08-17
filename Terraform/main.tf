# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-vpc" }
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

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-public-subnet" }
  )
}

# Private Subnet (optional, for databases)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-private-subnet" }
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
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-public-rt" }
  )
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for Elastic Beanstalk
resource "aws_security_group" "eb" {
  name        = "${var.app_name}-eb-sg"
  description = "Security group for Elastic Beanstalk"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-eb-sg" }
  )
}

# IAM Role for EC2 instances
resource "aws_iam_role" "eb_instance_role" {
  name = "${var.app_name}-eb-instance-role"

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

# Attach policies to EC2 role
resource "aws_iam_role_policy_attachment" "eb_worker" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "eb_multicontainer_docker" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "eb_profile" {
  name = "${var.app_name}-eb-instance-profile"
  role = aws_iam_role.eb_instance_role.name
}

# IAM Role for Elastic Beanstalk service
resource "aws_iam_role" "eb_service_role" {
  name = "${var.app_name}-eb-service-role"

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

resource "aws_iam_role_policy_attachment" "eb_service" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "eb_service_basic" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "main" {
  name        = var.app_name
  description = "Demo DevOps Application"

  tags = var.tags
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "main" {
  name                = "${var.app_name}-${var.env_name}"
  application         = aws_elastic_beanstalk_app.main.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.0.4 running Node.js 22"
  tier                = "WebServer"
  instance_type       = var.instance_type

  # VPC Configuration
  vpc_id            = aws_vpc.main.id
  subnets           = [aws_subnet.public.id]
  security_groups   = [aws_security_group.eb.id]
  
  # IAM Configuration
  service_role_arn = aws_iam_role.eb_service_role.arn

  # Instance Configuration
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_profile.arn
  }

  # Auto Scaling
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = var.min_size
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.max_size
  }

  # Load Balancer
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "false"
  }

  # Environment Health Check
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "EnhancedHealthReporting"
  }

  # Application port
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = var.env_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eb_service,
    aws_iam_role_policy_attachment.eb_service_basic,
  ]

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eb" {
  name              = "/aws/elasticbeanstalk/${var.app_name}-${var.env_name}"
  retention_in_days = 7

  tags = var.tags
}

# S3 Bucket for Elastic Beanstalk Deployments
resource "aws_s3_bucket" "eb_deployment" {
  bucket = "${var.app_name}-${var.env_name}-deployment-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    var.tags,
    { Name = "${var.app_name}-deployment-bucket" }
  )
}

# Enable versioning on S3 bucket
resource "aws_s3_bucket_versioning" "eb_deployment" {
  bucket = aws_s3_bucket.eb_deployment.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "eb_deployment" {
  bucket = aws_s3_bucket.eb_deployment.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption for S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "eb_deployment" {
  bucket = aws_s3_bucket.eb_deployment.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM Policy for S3 access (EC2 instances)
resource "aws_iam_role_policy" "eb_s3_access" {
  name   = "${var.app_name}-eb-s3-access"
  role   = aws_iam_role.eb_instance_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.eb_deployment.arn,
          "${aws_s3_bucket.eb_deployment.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for S3 access (Elastic Beanstalk service)
resource "aws_iam_role_policy" "eb_service_s3_access" {
  name   = "${var.app_name}-eb-service-s3-access"
  role   = aws_iam_role.eb_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.eb_deployment.arn,
          "${aws_s3_bucket.eb_deployment.arn}/*"
        ]
      }
    ]
  })
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM User for GitHub Actions CI/CD
resource "aws_iam_user" "github_actions" {
  name = "${var.app_name}-github-actions"
  tags = var.tags
}

# IAM Policy for GitHub Actions - S3 and Elastic Beanstalk deployment
resource "aws_iam_user_policy" "github_actions_deploy" {
  name = "${var.app_name}-github-actions-deploy-policy"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DeploymentBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.eb_deployment.arn,
          "${aws_s3_bucket.eb_deployment.arn}/*"
        ]
      },
      {
        Sid    = "ElasticBeanstalkDeployment"
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
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.eb_instance_role.arn,
          aws_iam_role.eb_service_role.arn
        ]
      },
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
          "ecr:CreateRepository",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"
      },
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Access Key for GitHub Actions User
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

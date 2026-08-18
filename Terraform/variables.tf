variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "demo-devops"
}

variable "env_name" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 3
}

variable "desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}

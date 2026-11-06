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
  default     = "1.31"
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

# ========================================
# ELASTIC BEANSTALK VARIABLES
# ========================================

variable "enable_elastic_beanstalk" {
  description = "Enable Elastic Beanstalk deployment (set to true to provision EBS alongside EKS)"
  type        = bool
  default     = false
}

variable "eb_instance_type" {
  description = "EC2 instance type for Elastic Beanstalk"
  type        = string
  default     = "t3.micro"
}

variable "eb_solution_stack" {
  description = "Elastic Beanstalk solution stack name"
  type        = string
  default     = "64bit Amazon Linux 2023 v6.2.0 running Node.js 20"
}

variable "eb_min_instances" {
  description = "Minimum number of instances for Elastic Beanstalk auto scaling"
  type        = number
  default     = 1
}

variable "eb_max_instances" {
  description = "Maximum number of instances for Elastic Beanstalk auto scaling"
  type        = number
  default     = 2
}

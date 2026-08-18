output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_version" {
  description = "EKS cluster version"
  value       = aws_eks_cluster.main.version
}

output "eks_node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.eks.name
}

# GitHub Actions Credentials
output "github_actions_access_key_id" {
  description = "AWS Access Key ID for GitHub Actions (store as secret AWS_ACCESS_KEY_ID)"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "AWS Secret Access Key for GitHub Actions (store as secret AWS_SECRET_ACCESS_KEY)"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "github_actions_setup_guide" {
  description = "Instructions for setting up GitHub Actions secrets"
  value = <<-EOT
    1. Go to GitHub repository Settings → Secrets and variables → Actions
    2. Create new repository secrets:
       - Name: AWS_ACCESS_KEY_ID
         Value: ${aws_iam_access_key.github_actions.id}
       - Name: AWS_SECRET_ACCESS_KEY
         Value: ${aws_iam_access_key.github_actions.secret}
    3. Your EKS cluster details:
       - Cluster: ${aws_eks_cluster.main.name}
       - ECR Repository: ${aws_ecr_repository.app.repository_url}
       - Region: ${var.aws_region}
  EOT
  sensitive = true
}

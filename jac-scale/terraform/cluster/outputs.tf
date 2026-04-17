output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used for IRSA role bindings"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (nodes and pods run here)"
  value       = module.vpc.private_subnets
}

output "node_security_group_id" {
  description = "Security group ID shared by all nodes"
  value       = module.eks.node_security_group_id
}

output "karpenter_node_role_name" {
  description = "IAM role name used by Karpenter-provisioned nodes"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = module.karpenter.queue_name
}

output "kubeconfig_command" {
  description = "Run this to update your local kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

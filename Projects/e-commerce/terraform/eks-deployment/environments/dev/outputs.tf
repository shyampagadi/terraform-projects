output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnet_ids
}

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "The certificate authority data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "The security group ID of the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_group_ids" {
  description = "IDs of the EKS node groups"
  value       = module.nodes.node_group_ids
}

output "addon_ids" {
  description = "Map of installed EKS addon IDs"
  value       = module.addons.addon_ids
}

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for ALB Ingress Controller"
  value       = module.addons.alb_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler"
  value       = module.addons.cluster_autoscaler_role_arn
} 
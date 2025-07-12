output "addon_ids" {
  description = "Map of installed EKS addon IDs"
  value       = { for k, v in aws_eks_addon.addons : k => v.id }
}

output "addon_arns" {
  description = "Map of installed EKS addon ARNs"
  value       = { for k, v in aws_eks_addon.addons : k => v.arn }
}

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for ALB Ingress Controller"
  value       = var.create_alb_controller ? aws_iam_role.alb_controller[0].arn : null
}

output "alb_controller_role_name" {
  description = "Name of the IAM role for ALB Ingress Controller"
  value       = var.create_alb_controller ? aws_iam_role.alb_controller[0].name : null
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler"
  value       = var.create_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "cluster_autoscaler_role_name" {
  description = "Name of the IAM role for Cluster Autoscaler"
  value       = var.create_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].name : null
} 
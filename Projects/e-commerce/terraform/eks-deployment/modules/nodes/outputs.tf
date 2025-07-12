output "node_group_arns" {
  description = "ARNs of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.arn }
}

output "node_group_ids" {
  description = "IDs of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.id }
}

output "node_group_status" {
  description = "Status of the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.status }
}

output "node_group_resources" {
  description = "Resources associated with the EKS node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.resources }
}

output "node_role_arn" {
  description = "ARN of the IAM role for the node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_role_name" {
  description = "Name of the IAM role for the node groups"
  value       = aws_iam_role.node_group.name
} 
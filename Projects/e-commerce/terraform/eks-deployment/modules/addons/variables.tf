variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "addons" {
  description = "Map of EKS addons to be installed"
  type        = map(any)
  default     = {}
}

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for the EKS cluster"
  type        = string
}

variable "oidc_provider_url" {
  description = "The URL of the OIDC Provider for the EKS cluster"
  type        = string
}

variable "create_alb_controller" {
  description = "Whether to create IAM role and policy for ALB Ingress Controller"
  type        = bool
  default     = true
}

variable "create_cluster_autoscaler" {
  description = "Whether to create IAM role and policy for Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
} 
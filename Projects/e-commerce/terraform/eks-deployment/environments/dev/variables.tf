variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ecommerce"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.27"
}

variable "endpoint_private_access" {
  description = "Whether to enable private access for the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether to enable public access for the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can access the EKS cluster public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "List of EKS cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 90
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for CloudWatch alarm"
  type        = number
  default     = 80
}

variable "node_groups" {
  description = "Map of EKS node group configurations"
  type        = map(any)
  default = {
    app = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      disk_size      = 20
      labels = {
        "role" = "app"
      }
    },
    monitoring = {
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      disk_size      = 20
      labels = {
        "role" = "monitoring"
      }
      taints = [
        {
          key    = "dedicated"
          value  = "monitoring"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}

variable "eks_addons" {
  description = "Map of EKS addons to be installed"
  type        = map(any)
  default = {
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    },
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    },
    coredns = {
      resolve_conflicts = "OVERWRITE"
    },
    aws-ebs-csi-driver = {
      resolve_conflicts = "OVERWRITE"
    }
  }
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
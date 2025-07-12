variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS node groups"
  type        = list(string)
}

variable "node_groups" {
  description = "Map of EKS node group configurations"
  type        = map(any)
  default     = {}
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for CloudWatch alarm"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "List of ARNs to notify when CPU alarm is triggered"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when CPU alarm returns to OK state"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
} 
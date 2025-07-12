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

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "flow_log_role_arn" {
  description = "IAM role ARN for VPC Flow Logs"
  type        = string
}

variable "flow_log_destination" {
  description = "Destination ARN for VPC Flow Logs (CloudWatch Log Group)"
  type        = string
} 
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
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

variable "app_port" {
  description = "Port on which the application listens"
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port on which the database listens"
  type        = number
  default     = 5432  # Default PostgreSQL port
}

variable "create_bastion_sg" {
  description = "Whether to create a security group for bastion host"
  type        = bool
  default     = false
}

variable "bastion_security_group_id" {
  description = "ID of the bastion security group, if applicable"
  type        = string
  default     = null
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks from which SSH is allowed"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Default is to allow from anywhere, should be restricted in production
} 
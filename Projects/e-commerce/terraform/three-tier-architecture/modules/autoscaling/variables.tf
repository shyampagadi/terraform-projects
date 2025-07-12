variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of SSH key pair"
  type        = string
  default     = null
}

variable "security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "user_data_template_path" {
  description = "Path to user data template file"
  type        = string
}

variable "user_data_vars" {
  description = "Variables to pass to user data template"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "Subnet IDs for Auto Scaling Group"
  type        = list(string)
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 10
}

variable "target_group_arn" {
  description = "ARN of target group for load balancer"
  type        = string
}

variable "cooldown_period" {
  description = "Cooldown period for scaling activities"
  type        = number
  default     = 300
}

variable "scale_up_threshold" {
  description = "CPU threshold for scaling up"
  type        = number
  default     = 75
}

variable "scale_down_threshold" {
  description = "CPU threshold for scaling down"
  type        = number
  default     = 25
} 
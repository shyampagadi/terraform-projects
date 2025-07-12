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

variable "app_port" {
  description = "Port on which the application listens"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/health"
}

variable "db_port" {
  description = "Port for database connections"
  type        = number
  default     = 5432
}

variable "create_bastion" {
  description = "Whether to create a bastion host security group"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks from which SSH is allowed to bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # In production, restrict to specific IP ranges
}

variable "instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.micro"
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "admin"
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "14.5"
}

variable "db_major_engine_version" {
  description = "Major engine version"
  type        = string
  default     = "14"
}

variable "db_parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "postgres14"
}

variable "db_instance_class" {
  description = "Instance class for the database"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the database in GB"
  type        = number
  default     = 20
} 
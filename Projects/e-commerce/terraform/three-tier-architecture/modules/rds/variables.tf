variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "Subnet IDs for the RDS DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the RDS instance"
  type        = string
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

variable "db_port" {
  description = "Port for the database"
  type        = number
  default     = 5432  # Default PostgreSQL port
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "14.5"
}

variable "major_engine_version" {
  description = "Major engine version"
  type        = string
  default     = "14"
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "postgres14"
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Allocated storage size in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage size in GB for autoscaling"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type for the database"
  type        = string
  default     = "gp3"
}

variable "multi_az" {
  description = "If true, a multi-AZ deployment will be created"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Time window for automated backups"
  type        = string
  default     = "03:00-05:00"  # UTC time
}

variable "maintenance_window" {
  description = "Time window for maintenance"
  type        = string
  default     = "Sun:06:00-Sun:08:00"  # UTC time
}

variable "skip_final_snapshot" {
  description = "If true, no final snapshot will be created when the DB instance is deleted"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "If true, the database cannot be deleted"
  type        = bool
  default     = true
}

variable "delete_automated_backups" {
  description = "If true, automated backups will be deleted when the DB instance is deleted"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "If true, minor engine upgrades will be applied automatically"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Interval in seconds for enhanced monitoring"
  type        = number
  default     = 60
}

variable "monitoring_role_arn" {
  description = "ARN of the IAM role for enhanced monitoring"
  type        = string
  default     = null
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to enable for export to CloudWatch Logs"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "performance_insights_enabled" {
  description = "If true, Performance Insights will be enabled"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Retention period for Performance Insights in days"
  type        = number
  default     = 7  # Free tier is 7 days
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ID for encrypting Performance Insights data"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting database storage"
  type        = string
  default     = null
}

variable "prevent_destroy" {
  description = "If true, prevents accidental destruction of the database"
  type        = bool
  default     = true
}

variable "db_parameters" {
  description = "List of DB parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "db_options" {
  description = "List of DB options"
  type = list(object({
    option_name = string
    option_settings = list(object({
      name  = string
      value = string
    }))
  }))
  default = []
}

variable "cpu_threshold" {
  description = "Threshold for CPU utilization alarm"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Threshold for free memory alarm in bytes"
  type        = number
  default     = 268435456  # 256 MB
}

variable "disk_threshold" {
  description = "Threshold for free storage space alarm in bytes"
  type        = number
  default     = 2147483648  # 2 GB
}

variable "alarm_actions" {
  description = "Actions to take when an alarm is triggered"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Actions to take when an alarm returns to OK state"
  type        = list(string)
  default     = []
} 
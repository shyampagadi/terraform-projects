variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "internal" {
  description = "If true, ALB will be internal"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Idle timeout for ALB connections"
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "If true, deletion protection will be enabled for the ALB"
  type        = bool
  default     = true
}

variable "log_bucket" {
  description = "S3 bucket for ALB logs"
  type        = string
}

variable "target_port" {
  description = "Port for target group"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Interval for health check"
  type        = number
  default     = 30
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health check successes before considering target healthy"
  type        = number
  default     = 3
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures before considering target unhealthy"
  type        = number
  default     = 3
}

variable "health_check_timeout" {
  description = "Timeout for health check"
  type        = number
  default     = 5
}

variable "health_check_matcher" {
  description = "HTTP codes to use when checking for a successful response from a target"
  type        = string
  default     = "200-399"
}

variable "stickiness_enabled" {
  description = "If true, enable stickiness"
  type        = bool
  default     = false
}

variable "deregistration_delay" {
  description = "Delay in seconds before deregistering a target"
  type        = number
  default     = 300
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "certificate_arn" {
  description = "ARN of SSL certificate"
  type        = string
}

variable "error_threshold" {
  description = "Threshold for 5XX errors before triggering alarm"
  type        = number
  default     = 10
}

variable "alarm_actions" {
  description = "Actions to take when alarm is triggered"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Actions to take when alarm returns to OK state"
  type        = list(string)
  default     = []
} 
# AWS 3-Tier Architecture Deployment Guide - Part 6
# Monitoring, Logging, and Alerting

## Monitoring Overview

A comprehensive monitoring, logging, and alerting strategy is essential for maintaining the health, performance, and security of your AWS 3-tier architecture. This part covers:

1. **CloudWatch Monitoring** - Metrics collection and visualization
2. **CloudWatch Logs** - Centralized log management
3. **CloudWatch Alarms** - Automated alerting
4. **CloudTrail** - AWS API activity tracking
5. **X-Ray** - Distributed tracing
6. **Dashboards** - Custom monitoring dashboards

## Terraform Configuration

Let's create the Terraform modules for our monitoring components:

### 1. CloudWatch Logs Module

```hcl
# terraform/modules/cloudwatch_logs/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "log_groups" {
  description = "List of log groups to create"
  type = list(object({
    name              = string
    retention_in_days = number
  }))
}
```

```hcl
# terraform/modules/cloudwatch_logs/main.tf
resource "aws_cloudwatch_log_group" "log_group" {
  for_each = { for lg in var.log_groups : lg.name => lg }
  
  name              = "/aws/${var.environment}/${each.value.name}"
  retention_in_days = each.value.retention_in_days
  
  tags = {
    Name        = "${var.environment}-${each.value.name}"
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/cloudwatch_logs/outputs.tf
output "log_group_arns" {
  description = "ARNs of the CloudWatch Log Groups"
  value       = { for name, log_group in aws_cloudwatch_log_group.log_group : name => log_group.arn }
}

output "log_group_names" {
  description = "Names of the CloudWatch Log Groups"
  value       = { for name, log_group in aws_cloudwatch_log_group.log_group : name => log_group.name }
}
```

### 2. CloudWatch Alarms Module

```hcl
# terraform/modules/cloudwatch_alarms/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alarms" {
  description = "List of alarms to create"
  type = list(object({
    name                = string
    description         = string
    comparison_operator = string
    evaluation_periods  = number
    metric_name         = string
    namespace           = string
    period              = number
    statistic           = string
    threshold           = number
    alarm_actions       = list(string)
    dimensions          = map(string)
  }))
}
```

```hcl
# terraform/modules/cloudwatch_alarms/main.tf
resource "aws_cloudwatch_metric_alarm" "alarm" {
  for_each = { for alarm in var.alarms : alarm.name => alarm }
  
  alarm_name          = "${var.environment}-${each.value.name}"
  alarm_description   = each.value.description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_actions       = each.value.alarm_actions
  dimensions          = each.value.dimensions
  
  tags = {
    Name        = "${var.environment}-${each.value.name}"
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/cloudwatch_alarms/outputs.tf
output "alarm_arns" {
  description = "ARNs of the CloudWatch Alarms"
  value       = { for name, alarm in aws_cloudwatch_metric_alarm.alarm : name => alarm.arn }
}
```

### 3. CloudWatch Dashboard Module

```hcl
# terraform/modules/cloudwatch_dashboard/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  type        = string
}

variable "dashboard_body" {
  description = "JSON string of the dashboard body"
  type        = string
}
```

```hcl
# terraform/modules/cloudwatch_dashboard/main.tf
resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "${var.environment}-${var.dashboard_name}"
  dashboard_body = var.dashboard_body
}
```

```hcl
# terraform/modules/cloudwatch_dashboard/outputs.tf
output "dashboard_arn" {
  description = "ARN of the CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.dashboard.dashboard_arn
}
```

### 4. SNS Topic for Alerts

```hcl
# terraform/modules/sns/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "topic_name" {
  description = "Name of the SNS topic"
  type        = string
}

variable "email_subscriptions" {
  description = "List of email addresses to subscribe to the topic"
  type        = list(string)
  default     = []
}
```

```hcl
# terraform/modules/sns/main.tf
resource "aws_sns_topic" "topic" {
  name = "${var.environment}-${var.topic_name}"
  
  tags = {
    Name        = "${var.environment}-${var.topic_name}"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email_subscription" {
  for_each = toset(var.email_subscriptions)
  
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "email"
  endpoint  = each.value
}
```

```hcl
# terraform/modules/sns/outputs.tf
output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.topic.arn
}
```

### 5. CloudTrail Module

```hcl
# terraform/modules/cloudtrail/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  type        = string
}

variable "include_global_service_events" {
  description = "Include global service events"
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Is this a multi-region trail"
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Enable log file validation"
  type        = bool
  default     = true
}
```

```hcl
# terraform/modules/cloudtrail/main.tf
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "${var.environment}-${var.s3_bucket_name}-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "${var.environment}-${var.s3_bucket_name}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/${var.environment}/cloudtrail"
  retention_in_days = 90
  
  tags = {
    Name        = "${var.environment}-cloudtrail-logs"
    Environment = var.environment
  }
}

resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name = "${var.environment}-cloudtrail-to-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.environment}-cloudtrail-to-cloudwatch"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch" {
  name   = "${var.environment}-cloudtrail-to-cloudwatch"
  role   = aws_iam_role.cloudtrail_to_cloudwatch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "trail" {
  name                          = "${var.environment}-${var.trail_name}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.is_multi_region_trail
  enable_log_file_validation    = var.enable_log_file_validation
  
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cloudwatch.arn
  
  tags = {
    Name        = "${var.environment}-${var.trail_name}"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}
```

```hcl
# terraform/modules/cloudtrail/outputs.tf
output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.trail.arn
}

output "cloudtrail_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail_log_group.arn
}

output "cloudtrail_bucket_id" {
  description = "ID of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_bucket.id
}
```

### 6. X-Ray Module

```hcl
# terraform/modules/xray/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "encryption_enabled" {
  description = "Enable encryption for X-Ray data"
  type        = bool
  default     = true
}
```

```hcl
# terraform/modules/xray/main.tf
resource "aws_xray_encryption_config" "encryption" {
  type = var.encryption_enabled ? "KMS" : "NONE"
}

resource "aws_xray_sampling_rule" "sampling_rule" {
  rule_name      = "${var.environment}-default-sampling-rule"
  priority       = 1000
  version        = 1
  reservoir_size = 5
  fixed_rate     = 0.05
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_name   = "*"
  service_type   = "*"
  
  attributes = {
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/xray/outputs.tf
output "sampling_rule_arn" {
  description = "ARN of the X-Ray sampling rule"
  value       = aws_xray_sampling_rule.sampling_rule.arn
}
```

### 7. Integrating the Monitoring Modules

```hcl
# terraform/environments/prod/monitoring.tf
# SNS Topic for Alerts
module "alerts_sns" {
  source = "../../modules/sns"

  environment         = "prod"
  topic_name          = "alerts"
  email_subscriptions = ["alerts@yourdomain.com", "oncall@yourdomain.com"]
}

# CloudWatch Logs
module "cloudwatch_logs" {
  source = "../../modules/cloudwatch_logs"

  environment = "prod"
  log_groups = [
    {
      name              = "web-tier"
      retention_in_days = 30
    },
    {
      name              = "app-tier"
      retention_in_days = 30
    },
    {
      name              = "data-tier"
      retention_in_days = 90
    }
  ]
}

# CloudWatch Alarms
module "cloudwatch_alarms" {
  source = "../../modules/cloudwatch_alarms"

  environment = "prod"
  alarms = [
    # Web Tier Alarms
    {
      name                = "web-high-cpu"
      description         = "High CPU utilization for Web Tier"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_actions       = [module.alerts_sns.topic_arn]
      dimensions          = { AutoScalingGroupName = module.asg.asg_name }
    },
    {
      name                = "web-high-memory"
      description         = "High Memory utilization for Web Tier"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "mem_used_percent"
      namespace           = "CWAgent"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_actions       = [module.alerts_sns.topic_arn]
      dimensions          = { AutoScalingGroupName = module.asg.asg_name }
    },
    # App Tier Alarms
    {
      name                = "app-high-cpu"
      description         = "High CPU utilization for App Tier"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_actions       = [module.alerts_sns.topic_arn]
      dimensions          = { AutoScalingGroupName = module.app_asg.asg_name }
    },
    # Database Alarms
    {
      name                = "db-high-cpu"
      description         = "High CPU utilization for Database"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_actions       = [module.alerts_sns.topic_arn]
      dimensions          = { DBClusterIdentifier = module.aurora.db_cluster_identifier }
    },
    {
      name                = "db-low-storage"
      description         = "Low free storage space for Database"
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 2
      metric_name         = "FreeStorageSpace"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = 10000000000 # 10 GB
      alarm_actions       = [module.alerts_sns.topic_arn]
      dimensions          = { DBClusterIdentifier = module.aurora.db_cluster_identifier }
    },
    # Load Balancer Alarms
    {
      name                = "alb-high-5xx"
      description         = "High 5XX error rate for ALB"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "HTTPCode_ELB_5XX_Count"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Sum"
      threshold           = 10
      alarm_actions       = [module.alerts_sns.topic_arn]
      dimensions          = { LoadBalancer = module.alb.alb_id }
    }
  ]
}

# CloudTrail
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  environment                  = "prod"
  trail_name                   = "management-events"
  s3_bucket_name               = "cloudtrail-logs"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}

# X-Ray
module "xray" {
  source = "../../modules/xray"

  environment       = "prod"
  encryption_enabled = true
}

# CloudWatch Dashboard
module "dashboard" {
  source = "../../modules/cloudwatch_dashboard"

  environment    = "prod"
  dashboard_name = "ecommerce-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.asg.asg_name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Web Tier CPU"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.app_asg.asg_name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "App Tier CPU"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", module.aurora.db_cluster_identifier]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Database CPU"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.alb_id]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "ALB Request Count"
        }
      }
    ]
  })
}

data "aws_region" "current" {}
```

## CloudWatch Agent Configuration

To collect custom metrics and logs from EC2 instances, you need to configure the CloudWatch Agent:

### 1. CloudWatch Agent Configuration File

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/prod/web-tier",
            "log_stream_name": "{instance_id}/nginx/access",
            "retention_in_days": 30
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/prod/web-tier",
            "log_stream_name": "{instance_id}/nginx/error",
            "retention_in_days": 30
          },
          {
            "file_path": "/var/log/docker/backend.log",
            "log_group_name": "/aws/prod/app-tier",
            "log_stream_name": "{instance_id}/backend",
            "retention_in_days": 30
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "resources": [
          "*"
        ],
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_user", "rename": "CPU_USER", "unit": "Percent"},
          {"name": "cpu_usage_system", "rename": "CPU_SYSTEM", "unit": "Percent"}
        ],
        "totalcpu": true
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEMORY_USED", "unit": "Percent"}
        ]
      },
      "disk": {
        "resources": [
          "/"
        ],
        "measurement": [
          {"name": "disk_used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ]
      }
    },
    "append_dimensions": {
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}",
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}"
    }
  }
}
```

### 2. Store the Configuration in SSM Parameter Store

```hcl
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name        = "/${var.environment}/cloudwatch-agent/config"
  description = "CloudWatch Agent configuration"
  type        = "String"
  value       = file("${path.module}/cloudwatch_agent_config.json")
  
  tags = {
    Name        = "${var.environment}-cloudwatch-agent-config"
    Environment = var.environment
  }
}
```

### 3. Update User Data Script to Install and Configure CloudWatch Agent

```bash
# Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch Agent
aws ssm get-parameter \
  --name /${var.environment}/cloudwatch-agent/config \
  --region ${data.aws_region.current.name} \
  --query "Parameter.Value" \
  --output text > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Start CloudWatch Agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
```

## Monitoring Best Practices

1. **Comprehensive Metrics Collection**:
   - Collect system-level metrics (CPU, memory, disk, network)
   - Collect application-level metrics (request rates, response times, error rates)
   - Collect business metrics (transactions, user activity)

2. **Effective Log Management**:
   - Centralize logs in CloudWatch Logs
   - Use structured logging formats (JSON)
   - Implement log retention policies
   - Set up log-based metrics and alarms

3. **Proactive Alerting**:
   - Define clear alerting thresholds
   - Implement different severity levels
   - Avoid alert fatigue by tuning thresholds
   - Set up escalation paths for critical alerts

4. **Distributed Tracing**:
   - Implement X-Ray tracing for microservices
   - Track request flows across services
   - Identify performance bottlenecks
   - Monitor service dependencies

5. **Visualization and Dashboards**:
   - Create role-specific dashboards (operations, development, business)
   - Include key performance indicators
   - Implement real-time monitoring
   - Set up trend analysis

6. **Security Monitoring**:
   - Track API calls with CloudTrail
   - Monitor for unauthorized access attempts
   - Set up alerts for security group changes
   - Implement compliance monitoring

7. **Cost Monitoring**:
   - Track resource utilization
   - Set up billing alerts
   - Implement cost allocation tags
   - Monitor for cost anomalies

In the next part, we will cover CI/CD pipeline setup and deployment strategies. 
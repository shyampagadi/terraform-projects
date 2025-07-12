# AWS 3-Tier Architecture Deployment Guide - Part 5
# Data Tier Setup

## Data Tier Overview

The Data Tier is the persistence layer of our architecture that stores and manages application data. This tier consists of:

1. **Aurora PostgreSQL** - Managed relational database for structured data
2. **S3 Bucket** - Object storage for files, backups, and other unstructured data
3. **AWS Backup** - Centralized backup service for data protection
4. **AWS Secrets Manager** - Secure storage for database credentials

## Terraform Configuration

Let's create the Terraform modules for our Data Tier components:

### 1. Aurora PostgreSQL Module

```hcl
# terraform/modules/aurora/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "data_subnet_ids" {
  description = "List of data tier subnet IDs"
  type        = list(string)
}

variable "data_security_group_id" {
  description = "Security group ID for data tier"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "13.7"
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "02:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:05:00-sun:07:00"
}
```

```hcl
# terraform/modules/aurora/main.tf
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.environment}-aurora-subnet-group"
  subnet_ids = var.data_subnet_ids

  tags = {
    Name        = "${var.environment}-aurora-subnet-group"
    Environment = var.environment
  }
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  name   = "${var.environment}-aurora-pg-params"
  family = "aurora-postgresql13"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name        = "${var.environment}-aurora-pg-params"
    Environment = var.environment
  }
}

resource "aws_db_parameter_group" "aurora" {
  name   = "${var.environment}-aurora-db-params"
  family = "aurora-postgresql13"

  tags = {
    Name        = "${var.environment}-aurora-db-params"
    Environment = var.environment
  }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.environment}-aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = var.db_engine_version
  availability_zones      = [for s in var.data_subnet_ids : data.aws_subnet.selected[s].availability_zone]
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [var.data_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  
  storage_encrypted       = true
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.environment}-aurora-final-snapshot"
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = {
    Name        = "${var.environment}-aurora-cluster"
    Environment = var.environment
  }
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count                = 2
  identifier           = "${var.environment}-aurora-instance-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = var.db_instance_class
  engine               = "aurora-postgresql"
  engine_version       = var.db_engine_version
  db_parameter_group_name = aws_db_parameter_group.aurora.name
  
  monitoring_interval  = 60
  monitoring_role_arn  = aws_iam_role.rds_monitoring_role.arn
  performance_insights_enabled = true
  
  tags = {
    Name        = "${var.environment}-aurora-instance-${count.index + 1}"
    Environment = var.environment
  }
}

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-rds-monitoring-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_attachment" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Lookup subnet AZs
data "aws_subnet" "selected" {
  for_each = toset(var.data_subnet_ids)
  id       = each.value
}
```

```hcl
# terraform/modules/aurora/outputs.tf
output "db_endpoint" {
  description = "The endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora.endpoint
}

output "db_reader_endpoint" {
  description = "The reader endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "db_port" {
  description = "The port of the Aurora cluster"
  value       = aws_rds_cluster.aurora.port
}

output "db_name" {
  description = "The database name"
  value       = aws_rds_cluster.aurora.database_name
}

output "db_cluster_identifier" {
  description = "The cluster identifier"
  value       = aws_rds_cluster.aurora.cluster_identifier
}
```

### 2. S3 Storage Module

```hcl
# terraform/modules/s3/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_name" {
  description = "Base name for the S3 bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the S3 bucket"
  type = list(object({
    id                       = string
    prefix                   = string
    enabled                  = bool
    expiration_days          = number
    noncurrent_version_days  = number
    transition_days          = number
    transition_storage_class = string
  }))
  default = []
}
```

```hcl
# terraform/modules/s3/main.tf
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "storage" {
  bucket = "${var.environment}-${var.bucket_name}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.environment}-${var.bucket_name}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id
  
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.storage.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      expiration {
        days = rule.value.expiration_days
      }

      noncurrent_version_expiration {
        noncurrent_days = rule.value.noncurrent_version_days
      }

      transition {
        days          = rule.value.transition_days
        storage_class = rule.value.transition_storage_class
      }
    }
  }
}
```

```hcl
# terraform/modules/s3/outputs.tf
output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.storage.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.storage.arn
}

output "bucket_domain_name" {
  description = "The domain name of the S3 bucket"
  value       = aws_s3_bucket.storage.bucket_domain_name
}
```

### 3. AWS Secrets Manager Module

```hcl
# terraform/modules/secrets/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "secret_name" {
  description = "Name of the secret"
  type        = string
}

variable "secret_value" {
  description = "Value of the secret"
  type        = map(string)
  sensitive   = true
}

variable "recovery_window_in_days" {
  description = "Recovery window in days"
  type        = number
  default     = 7
}
```

```hcl
# terraform/modules/secrets/main.tf
resource "aws_secretsmanager_secret" "secret" {
  name                    = "${var.environment}/${var.secret_name}"
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name        = "${var.environment}-${var.secret_name}"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = jsonencode(var.secret_value)
}
```

```hcl
# terraform/modules/secrets/outputs.tf
output "secret_id" {
  description = "The ID of the secret"
  value       = aws_secretsmanager_secret.secret.id
}

output "secret_arn" {
  description = "The ARN of the secret"
  value       = aws_secretsmanager_secret.secret.arn
}
```

### 4. AWS Backup Module

```hcl
# terraform/modules/backup/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "backup_resources" {
  description = "List of ARNs of resources to backup"
  type        = list(string)
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "cron(0 5 ? * * *)" # Daily at 5 AM UTC
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}
```

```hcl
# terraform/modules/backup/main.tf
resource "aws_backup_vault" "backup_vault" {
  name = "${var.environment}-backup-vault"
  
  tags = {
    Name        = "${var.environment}-backup-vault"
    Environment = var.environment
  }
}

resource "aws_backup_plan" "backup_plan" {
  name = "${var.environment}-backup-plan"

  rule {
    rule_name         = "${var.environment}-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = var.backup_schedule
    
    lifecycle {
      delete_after = var.backup_retention_days
    }
  }

  tags = {
    Name        = "${var.environment}-backup-plan"
    Environment = var.environment
  }
}

resource "aws_backup_selection" "backup_selection" {
  name         = "${var.environment}-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.backup_plan.id

  resources = var.backup_resources
}

resource "aws_iam_role" "backup_role" {
  name = "${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-backup-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
```

```hcl
# terraform/modules/backup/outputs.tf
output "backup_vault_id" {
  description = "The ID of the backup vault"
  value       = aws_backup_vault.backup_vault.id
}

output "backup_vault_arn" {
  description = "The ARN of the backup vault"
  value       = aws_backup_vault.backup_vault.arn
}

output "backup_plan_id" {
  description = "The ID of the backup plan"
  value       = aws_backup_plan.backup_plan.id
}
```

### 5. Integrating the Data Tier Modules

```hcl
# terraform/environments/prod/data.tf
# Database credentials in Secrets Manager
module "db_secrets" {
  source = "../../modules/secrets"

  environment = "prod"
  secret_name = "db-credentials"
  secret_value = {
    username = "postgres"
    password = var.db_password
  }
  recovery_window_in_days = 7
}

# Aurora PostgreSQL Database
module "aurora" {
  source = "../../modules/aurora"

  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  data_subnet_ids       = module.vpc.data_subnet_ids
  data_security_group_id = module.vpc.data_security_group_id
  
  db_name               = "ecommerce"
  db_username           = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  db_password           = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]
  db_instance_class     = "db.t3.medium"
  db_engine_version     = "13.7"
  
  backup_retention_period = 7
  preferred_backup_window = "02:00-04:00"
  preferred_maintenance_window = "sun:05:00-sun:07:00"
}

# S3 bucket for application data
module "app_data_bucket" {
  source = "../../modules/s3"

  environment       = "prod"
  bucket_name       = "app-data"
  versioning_enabled = true
  
  lifecycle_rules = [
    {
      id                       = "archive-rule"
      prefix                   = "archive/"
      enabled                  = true
      expiration_days          = 0
      noncurrent_version_days  = 90
      transition_days          = 30
      transition_storage_class = "STANDARD_IA"
    },
    {
      id                       = "logs-rule"
      prefix                   = "logs/"
      enabled                  = true
      expiration_days          = 90
      noncurrent_version_days  = 30
      transition_days          = 30
      transition_storage_class = "GLACIER"
    }
  ]
}

# S3 bucket for database backups
module "db_backup_bucket" {
  source = "../../modules/s3"

  environment       = "prod"
  bucket_name       = "db-backups"
  versioning_enabled = true
  
  lifecycle_rules = [
    {
      id                       = "db-backups-rule"
      prefix                   = ""
      enabled                  = true
      expiration_days          = 90
      noncurrent_version_days  = 30
      transition_days          = 30
      transition_storage_class = "GLACIER"
    }
  ]
}

# AWS Backup for Aurora and S3
module "backup" {
  source = "../../modules/backup"

  environment         = "prod"
  backup_resources    = [
    module.aurora.db_cluster_identifier,
    module.app_data_bucket.bucket_arn
  ]
  backup_schedule      = "cron(0 2 ? * * *)" # Daily at 2 AM UTC
  backup_retention_days = 30
}

# Get the database credentials from Secrets Manager
data "aws_secretsmanager_secret" "db_credentials" {
  name = "${module.db_secrets.secret_id}"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}
```

## Database Migration Process

Migrating your on-premises database to Amazon Aurora requires a careful approach to minimize downtime and ensure data integrity. AWS Database Migration Service (DMS) is the recommended tool for this process, as it allows for continuous data replication while the migration is in progress.

### 1. Initial Data Dump and Load (Optional but Recommended)

For very large databases, a combination of a native dump/restore and DMS for change data capture (CDC) is often the most efficient method.

**Create a Database Dump:**

```bash
# On your on-premises PostgreSQL server
pg_dump -h localhost -U postgres -d ecommerce -F c -b -v -f ecommerce_backup.dump
```

**Upload the Dump to S3:**

This S3 bucket can be the one created by the `db_backup_bucket` module.

```bash
# Upload the dump file to an S3 bucket for migrations
aws s3 cp ecommerce_backup.dump s3://<your-db-backup-bucket-name>/initial-migration/ecommerce_backup.dump
```

**Restore the Dump to Aurora:**

Once the Aurora cluster is provisioned by Terraform, you can restore this initial dump.

```bash
# Get the Aurora endpoint from Terraform output
AURORA_ENDPOINT=$(terraform output -raw db_endpoint)

# Restore the dump to Aurora
pg_restore -h $AURORA_ENDPOINT -U postgres -d ecommerce -v ecommerce_backup.dump
```

### 2. Setting Up AWS DMS for Continuous Replication

After the initial data load, DMS will be used to replicate any data changes that occurred on your on-premises database since the dump was created. This ensures your Aurora database is fully synchronized before the final cutover.

The following Terraform configuration sets up the necessary DMS components.

#### DMS Terraform Module (`terraform/modules/dms/main.tf`)

This module creates a replication instance, source and target endpoints, and the replication task.

```hcl
# terraform/modules/dms/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for DMS instance"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DMS instance"
  type        = list(string)
}

variable "source_server_name" {
  description = "Hostname or IP of the source database"
  type        = string
}
# ... other variables for source and target DB credentials

# terraform/modules/dms/main.tf
resource "aws_dms_replication_instance" "replication_instance" {
  replication_instance_id      = "${var.environment}-dms-instance"
  replication_instance_class   = "dms.t3.medium"
  allocated_storage            = 50
  vpc_security_group_ids       = [var.security_group_id]
  replication_subnet_group_id  = aws_dms_replication_subnet_group.dms_subnet_group.id
  publicly_accessible          = false
  
  tags = {
    Name        = "${var.environment}-dms-instance"
    Environment = var.environment
  }
}

resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_id          = "${var.environment}-dms-subnet-group"
  replication_subnet_group_description = "DMS subnet group for ${var.environment}"
  subnet_ids                           = var.subnet_ids
  
  tags = {
    Name        = "${var.environment}-dms-subnet-group"
    Environment = var.environment
  }
}

resource "aws_dms_endpoint" "source" {
  endpoint_id                  = "${var.environment}-source-endpoint"
  endpoint_type                = "source"
  engine_name                  = "postgres"
  server_name                  = var.source_server_name
  port                         = 5432
  database_name                = var.source_database_name
  username                     = var.source_username
  password                     = var.source_password
  
  tags = {
    Name        = "${var.environment}-source-endpoint"
    Environment = var.environment
  }
}

resource "aws_dms_endpoint" "target" {
  endpoint_id                  = "${var.environment}-target-endpoint"
  endpoint_type                = "target"
  engine_name                  = "aurora-postgresql"
  server_name                  = var.target_server_name
  port                         = 5432
  database_name                = var.target_database_name
  username                     = var.target_username
  password                     = var.target_password
  
  tags = {
    Name        = "${var.environment}-target-endpoint"
    Environment = var.environment
  }
}

resource "aws_dms_replication_task" "replication_task" {
  replication_task_id          = "${var.environment}-replication-task"
  replication_instance_arn     = aws_dms_replication_instance.replication_instance.replication_instance_arn
  source_endpoint_arn          = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn          = aws_dms_endpoint.target.endpoint_arn
  migration_type               = "cdc" # Change Data Capture only
  
  replication_task_settings    = jsonencode({
    "TargetMetadata": {
      "TargetSchema": "",
      "SupportLobs": true,
      "FullLobMode": false,
      "LobChunkSize": 64,
      "LimitedSizeLobMode": true,
      "LobMaxSize": 32
    },
    "FullLoadSettings": {
      "TargetTablePrepMode": "DO_NOTHING"
    },
    "Logging": {
      "EnableLogging": true
    }
  })
  
  table_mappings = jsonencode({
    "rules": [
      {
        "rule-type": "selection",
        "rule-id": "1",
        "rule-name": "1",
        "object-locator": {
          "schema-name": "public",
          "table-name": "%"
        },
        "rule-action": "include"
      }
    ]
  })
  
  tags = {
    Name        = "${var.environment}-replication-task"
    Environment = var.environment
  }
}
```

### 3. Executing the DMS Migration

1.  **Provision DMS Resources**: Apply the Terraform configuration to create the DMS replication instance, endpoints, and task.
2.  **Test Endpoints**: From the AWS DMS console, test the connections to both the source (on-premises) and target (Aurora) endpoints to ensure connectivity. This may require adjusting security groups or network ACLs.
3.  **Start the Replication Task**:
    -   Once the initial `pg_restore` is complete, start the DMS replication task from the AWS console or using the AWS CLI.
    -   Since `migration_type` is set to `cdc` (Change Data Capture), the task will only replicate changes that have occurred since the initial dump.
    -   Monitor the task status in the DMS console. Look at the "Task monitoring" tab to see replication latency and other key metrics.
4.  **Monitor Replication Lag**: Keep an eye on the `CDCLatencySource` and `CDCLatencyTarget` metrics in CloudWatch for your DMS task. The goal is to get this lag as close to zero as possible before the final cutover.
5.  **Perform the Cutover**:
    -   Schedule a maintenance window.
    -   Stop the application services that write to the on-premises database.
    -   Wait for the DMS replication lag to drop to zero, ensuring all pending changes are written to Aurora.
    -   Stop the DMS replication task.
    -   Update your application's configuration to point to the new Aurora database endpoint.
    -   Start your application services.
    -   Perform thorough testing to ensure the application is working correctly with the new database.
6.  **Decommission On-Premises Database**: Once you are confident that the migration was successful and the application is stable, you can decommission the on-premises database.

## Data Tier Best Practices

1. **Database Performance Optimization**:
   - Use appropriate instance types for your workload
   - Implement connection pooling
   - Create proper indexes for frequently queried columns
   - Monitor and optimize slow queries

2. **High Availability and Disaster Recovery**:
   - Deploy Aurora across multiple Availability Zones
   - Configure automated backups
   - Set up point-in-time recovery
   - Implement cross-region replication for critical data

3. **Security Best Practices**:
   - Store database credentials in Secrets Manager
   - Encrypt data at rest and in transit
   - Implement least privilege access
   - Use IAM authentication for database access
   - Regularly rotate credentials

4. **Backup Strategy**:
   - Implement automated daily backups
   - Test backup restoration regularly
   - Store backups in multiple regions
   - Implement a backup retention policy

5. **Monitoring and Alerting**:
   - Set up CloudWatch alarms for database metrics
   - Monitor connection count, CPU utilization, and memory usage
   - Configure alerts for storage thresholds
   - Enable Performance Insights for query monitoring

6. **Cost Optimization**:
   - Right-size database instances
   - Use Aurora Serverless for variable workloads
   - Implement storage lifecycle policies
   - Monitor and optimize database costs

In the next part, we will cover monitoring, logging, and alerting for the entire architecture. 
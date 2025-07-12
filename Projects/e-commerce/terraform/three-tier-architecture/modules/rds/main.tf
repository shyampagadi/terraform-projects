resource "aws_db_subnet_group" "main" {
  name        = "${var.environment}-db-subnet-group"
  description = "Database subnet group for ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-subnet-group"
    }
  )
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.environment}-db-parameter-group-${var.engine}-${var.engine_version}"
  family      = var.parameter_group_family
  description = "Database parameter group for ${var.environment}"

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-parameter-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_option_group" "main" {
  name                     = "${var.environment}-db-option-group-${var.engine}-${var.engine_version}"
  option_group_description = "Database option group for ${var.environment}"
  engine_name              = var.engine
  major_engine_version     = var.major_engine_version

  dynamic "option" {
    for_each = var.db_options
    content {
      option_name = option.value.option_name

      dynamic "option_settings" {
        for_each = option.value.option_settings == null ? [] : option.value.option_settings
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-option-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.environment}/db/credentials"
  description = "Database credentials for ${var.environment}"
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.engine
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

resource "aws_db_instance" "main" {
  identifier                  = "${var.environment}-${var.db_name}"
  engine                      = var.engine
  engine_version              = var.engine_version
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  max_allocated_storage       = var.max_allocated_storage
  storage_type                = var.storage_type
  storage_encrypted           = true
  kms_key_id                  = var.kms_key_id

  name                        = var.db_name
  username                    = var.db_username
  password                    = random_password.db_password.result
  port                        = var.db_port

  vpc_security_group_ids      = [var.security_group_id]
  db_subnet_group_name        = aws_db_subnet_group.main.name
  parameter_group_name        = aws_db_parameter_group.main.name
  option_group_name           = aws_db_option_group.main.name

  multi_az                    = var.multi_az
  publicly_accessible         = false
  backup_retention_period     = var.backup_retention_period
  backup_window               = var.backup_window
  maintenance_window          = var.maintenance_window
  skip_final_snapshot         = var.skip_final_snapshot
  final_snapshot_identifier   = var.skip_final_snapshot ? null : "${var.environment}-${var.db_name}-final-snapshot-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  deletion_protection         = var.deletion_protection
  delete_automated_backups    = var.delete_automated_backups
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  monitoring_interval         = var.monitoring_interval
  monitoring_role_arn         = var.monitoring_role_arn
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  performance_insights_kms_key_id = var.performance_insights_kms_key_id
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${var.db_name}"
    }
  )

  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "${var.environment}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors database cpu utilization"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-high-cpu-alarm"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "db_memory" {
  alarm_name          = "${var.environment}-db-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors database freeable memory"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-low-memory-alarm"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "db_disk" {
  alarm_name          = "${var.environment}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.disk_threshold
  alarm_description   = "This metric monitors database free storage space"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-db-low-storage-alarm"
    }
  )
} 
provider "aws" {
  region = var.region
}

locals {
  environment = "dev"
  common_tags = {
    Environment   = local.environment
    Project       = "e-commerce"
    ManagedBy     = "terraform"
    Owner         = "devops-team"
    BusinessUnit  = "digital"
    CostCenter    = "10001"
    ApplicationId = "ecom-${local.environment}"
  }
}

# Remote backend configuration
terraform {
  backend "s3" {
    bucket         = "e-commerce-terraform-state"
    key            = "three-tier/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Pre-requisite resources (should be created separately in production)
resource "aws_s3_bucket" "logs" {
  bucket = "e-commerce-${local.environment}-logs"

  tags = merge(
    local.common_tags,
    {
      Name = "e-commerce-${local.environment}-logs"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-rotation"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/${local.environment}-flow-logs"
  retention_in_days = 90

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-vpc-flow-log-group"
    }
  )
}

resource "aws_iam_role" "vpc_flow_log_role" {
  name = "${local.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-vpc-flow-log-role"
    }
  )
}

resource "aws_iam_policy" "vpc_flow_log_policy" {
  name        = "${local.environment}-vpc-flow-log-policy"
  description = "IAM policy for VPC flow logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log_attachment" {
  role       = aws_iam_role.vpc_flow_log_role.name
  policy_arn = aws_iam_policy.vpc_flow_log_policy.arn
}

resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/aws/ec2/${local.environment}-app-logs"
  retention_in_days = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-app-log-group"
    }
  )
}

resource "aws_sns_topic" "alerts" {
  name = "${local.environment}-alerts"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-alerts"
    }
  )
}

resource "aws_acm_certificate" "main" {
  domain_name       = "${local.environment}.example.com"
  validation_method = "DNS"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-certificate"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment        = local.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  common_tags        = local.common_tags
  flow_log_role_arn  = aws_iam_role.vpc_flow_log_role.arn
  flow_log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
}

# Security Module
module "security" {
  source = "../../modules/security"

  environment            = local.environment
  vpc_id                 = module.vpc.vpc_id
  common_tags            = local.common_tags
  app_port               = var.app_port
  db_port                = var.db_port
  create_bastion_sg      = var.create_bastion
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  environment                = local.environment
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.public_subnet_ids
  alb_security_group_id      = module.security.alb_security_group_id
  common_tags                = local.common_tags
  internal                   = false
  enable_deletion_protection = false  # Set to true for prod
  log_bucket                 = aws_s3_bucket.logs.bucket
  target_port                = var.app_port
  health_check_path          = var.health_check_path
  certificate_arn            = aws_acm_certificate.main.arn
  error_threshold            = 10
  alarm_actions              = [aws_sns_topic.alerts.arn]
  ok_actions                 = [aws_sns_topic.alerts.arn]
}

# Autoscaling Module
module "autoscaling" {
  source = "../../modules/autoscaling"

  environment              = local.environment
  common_tags              = local.common_tags
  subnet_ids               = module.vpc.private_app_subnet_ids
  security_group_id        = module.security.app_security_group_id
  target_group_arn         = module.alb.target_group_arn
  user_data_template_path  = "${path.module}/../../scripts/user_data.sh.tpl"
  user_data_vars = {
    environment = local.environment
    asg_name    = "${local.environment}-app-asg"
    log_group   = aws_cloudwatch_log_group.app_log_group.name
    server_id   = "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    app_version = "1.0.0"
    name        = "${local.environment}-app-server"
    region      = var.region
  }
  instance_type           = var.instance_type
  desired_capacity        = var.asg_desired_capacity
  min_size                = var.asg_min_size
  max_size                = var.asg_max_size
  scale_up_threshold      = 70
  scale_down_threshold    = 30
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  environment                = local.environment
  common_tags                = local.common_tags
  subnet_ids                 = module.vpc.private_db_subnet_ids
  security_group_id          = module.security.db_security_group_id
  db_name                    = var.db_name
  db_username                = var.db_username
  engine                     = var.db_engine
  engine_version             = var.db_engine_version
  major_engine_version       = var.db_major_engine_version
  parameter_group_family     = var.db_parameter_group_family
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  multi_az                   = false  # Set to true for prod
  backup_retention_period    = 7
  deletion_protection        = false  # Set to true for prod
  skip_final_snapshot        = true   # Set to false for prod
  prevent_destroy            = false  # Set to true for prod
  alarm_actions              = [aws_sns_topic.alerts.arn]
  ok_actions                 = [aws_sns_topic.alerts.arn]
  db_parameters = [
    {
      name  = "max_connections"
      value = "100"
    },
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/32768}MB"
    }
  ]
} 
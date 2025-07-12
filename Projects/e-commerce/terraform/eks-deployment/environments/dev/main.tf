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
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Pre-requisite resources
resource "aws_s3_bucket" "logs" {
  bucket = "e-commerce-${local.environment}-eks-logs"

  tags = merge(
    local.common_tags,
    {
      Name = "e-commerce-${local.environment}-eks-logs"
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

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/${local.environment}-eks-flow-logs"
  retention_in_days = 90

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-eks-vpc-flow-log-group"
    }
  )
}

resource "aws_iam_role" "vpc_flow_log_role" {
  name = "${local.environment}-eks-vpc-flow-log-role"

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
      Name = "${local.environment}-eks-vpc-flow-log-role"
    }
  )
}

resource "aws_iam_policy" "vpc_flow_log_policy" {
  name        = "${local.environment}-eks-vpc-flow-log-policy"
  description = "IAM policy for EKS VPC flow logs"

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

resource "aws_sns_topic" "alerts" {
  name = "${local.environment}-eks-alerts"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-eks-alerts"
    }
  )
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
  cluster_name       = var.cluster_name
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  environment              = local.environment
  cluster_name             = var.cluster_name
  kubernetes_version       = var.kubernetes_version
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = var.vpc_cidr
  subnet_ids               = module.vpc.private_subnet_ids
  endpoint_private_access  = var.endpoint_private_access
  endpoint_public_access   = var.endpoint_public_access
  public_access_cidrs      = var.public_access_cidrs
  enabled_cluster_log_types = var.enabled_cluster_log_types
  log_retention_days       = var.log_retention_days
  common_tags              = local.common_tags
}

# Node Groups Module
module "nodes" {
  source = "../../modules/nodes"

  environment       = local.environment
  cluster_name      = module.eks.cluster_id
  subnet_ids        = module.vpc.private_subnet_ids
  node_groups       = var.node_groups
  log_retention_days = var.log_retention_days
  cpu_threshold     = var.cpu_threshold
  alarm_actions     = [aws_sns_topic.alerts.arn]
  ok_actions        = [aws_sns_topic.alerts.arn]
  common_tags       = local.common_tags
}

# Addons Module
module "addons" {
  source = "../../modules/addons"

  environment             = local.environment
  cluster_name            = module.eks.cluster_id
  addons                  = var.eks_addons
  oidc_provider_arn       = module.eks.oidc_provider_arn
  oidc_provider_url       = module.eks.oidc_provider_url
  create_alb_controller   = var.create_alb_controller
  create_cluster_autoscaler = var.create_cluster_autoscaler
  common_tags             = local.common_tags
} 
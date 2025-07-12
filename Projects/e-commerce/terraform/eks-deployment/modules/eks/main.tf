data "aws_caller_identity" "current" {}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-cluster-role"
    }
  )
}

# Attach the required policies to the cluster role
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

# Security Group for the EKS cluster
resource "aws_security_group" "cluster" {
  name        = "${var.environment}-eks-cluster-sg"
  description = "Security group for the EKS cluster"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-cluster-sg"
    }
  )
}

# Security Group rules for the EKS cluster
resource "aws_security_group_rule" "cluster_ingress_https" {
  security_group_id = aws_security_group.cluster.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow HTTPS traffic from within the VPC"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.environment}-${var.cluster_name}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = [aws_security_group.cluster.id]
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.eks[0].arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-cluster"
    }
  )

  # Wait for IAM role to be available
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy
  ]
}

# KMS Key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "KMS key for EKS cluster ${var.environment}-${var.cluster_name} secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS service to use the key"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-kms-key"
    }
  )
}

# KMS Key alias
resource "aws_kms_alias" "eks" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${var.environment}-eks-${var.cluster_name}"
  target_key_id = aws_kms_key.eks[0].key_id
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.environment}-${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-log-group"
    }
  )
}

# OIDC Provider for the EKS cluster
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-oidc-provider"
    }
  )
} 
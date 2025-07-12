# IAM role for node groups
resource "aws_iam_role" "node_group" {
  name = "${var.environment}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-node-group-role"
    }
  )
}

# Attach necessary policies to the node group role
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node_group.name
}

# Create EKS managed node groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = var.cluster_name
  node_group_name = "${var.environment}-${each.key}"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids

  ami_type       = lookup(each.value, "ami_type", "AL2_x86_64")
  capacity_type  = lookup(each.value, "capacity_type", "ON_DEMAND")
  instance_types = lookup(each.value, "instance_types", ["t3.medium"])
  disk_size      = lookup(each.value, "disk_size", 20)

  scaling_config {
    desired_size = lookup(each.value, "desired_size", 2)
    max_size     = lookup(each.value, "max_size", 4)
    min_size     = lookup(each.value, "min_size", 1)
  }

  update_config {
    max_unavailable = lookup(each.value, "max_unavailable", 1)
  }

  labels = merge(
    lookup(each.value, "labels", {}),
    {
      "environment" = var.environment
      "node-group"  = each.key
    }
  )

  # Optional: Configure launch template
  dynamic "launch_template" {
    for_each = lookup(each.value, "launch_template_id", null) != null ? [1] : []
    content {
      id      = each.value.launch_template_id
      version = lookup(each.value, "launch_template_version", "$Latest")
    }
  }

  # Optional: Configure taints
  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Optional: Remote Access for SSH
  dynamic "remote_access" {
    for_each = lookup(each.value, "ec2_ssh_key", null) != null ? [1] : []
    content {
      ec2_ssh_key               = each.value.ec2_ssh_key
      source_security_group_ids = lookup(each.value, "source_security_group_ids", [])
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${each.key}-node-group"
    },
    lookup(each.value, "tags", {})
  )

  # Wait for IAM role to be available
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for node logs
resource "aws_cloudwatch_log_group" "nodes" {
  name              = "/aws/eks/${var.cluster_name}/nodes"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eks-nodes-log-group"
    }
  )
}

# CloudWatch Alarms for node groups
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  for_each = var.node_groups

  alarm_name          = "${var.environment}-${each.key}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization in the ${each.key} node group"
  
  dimensions = {
    AutoScalingGroupName = "${var.cluster_name}-${var.environment}-${each.key}-*"
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-${each.key}-node-cpu-high-alarm"
    }
  )
} 
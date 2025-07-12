# AWS 3-Tier Architecture Deployment Guide - Part 4
# Application Tier Setup

## Application Tier Overview

The Application Tier is the business logic layer of our architecture that processes data between the presentation and data tiers. This tier consists of:

1. **Internal Application Load Balancer** - Distributes traffic from the Web Tier to the Application Tier
2. **Auto Scaling Group** - Dynamically adjusts capacity based on demand
3. **EC2 Instances** - Hosts the backend application (FastAPI)
4. **ElastiCache** - Redis for session management and caching

## Terraform Configuration

Let's create the Terraform modules for our Application Tier components:

### 1. Internal Load Balancer Module

```hcl
# terraform/modules/internal_alb/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "app_subnet_ids" {
  description = "List of application tier subnet IDs"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID for application instances"
  type        = string
}
```

```hcl
# terraform/modules/internal_alb/main.tf
resource "aws_lb" "app" {
  name               = "${var.environment}-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.app_security_group_id]
  subnets            = var.app_subnet_ids

  enable_deletion_protection = true
  enable_http2               = true

  tags = {
    Name        = "${var.environment}-app-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name     = "${var.environment}-app-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name        = "${var.environment}-app-tg"
    Environment = var.environment
  }
}

# Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

```hcl
# terraform/modules/internal_alb/outputs.tf
output "internal_alb_id" {
  description = "ID of the internal Application Load Balancer"
  value       = aws_lb.app.id
}

output "internal_alb_dns_name" {
  description = "DNS name of the internal Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}
```

### 2. Application Auto Scaling Group Module

```hcl
# terraform/modules/app_asg/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "app_subnet_ids" {
  description = "List of application tier subnet IDs"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID for application instances"
  type        = string
}

variable "target_group_arns" {
  description = "List of target group ARNs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = ""
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "redis_host" {
  description = "Redis host"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = string
  default     = "6379"
}

variable "ecr_repository_url" {
  description = "ECR repository URL for backend container"
  type        = string
}
```

```hcl
# terraform/modules/app_asg/main.tf
# Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "app_instance_role" {
  name = "${var.environment}-app-instance-role"

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

  tags = {
    Name        = "${var.environment}-app-instance-role"
    Environment = var.environment
  }
}

# IAM Policy for ECR access
resource "aws_iam_policy" "ecr_access" {
  name        = "${var.environment}-ecr-access"
  description = "Policy to allow ECR access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.environment}-cloudwatch-logs"
  description = "Policy to allow CloudWatch Logs access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach policies to role
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "${var.environment}-app-instance-profile"
  role = aws_iam_role.app_instance_role.name
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.app_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Update system packages
    yum update -y
    
    # Install Docker
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    
    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent
    
    # Create environment file for backend container
    mkdir -p /app
    cat > /app/.env <<EOL
    DB_HOST=${var.db_host}
    DB_NAME=${var.db_name}
    DB_PORT=${var.db_port}
    DB_USER=$DB_USER
    DB_PASSWORD=$DB_PASSWORD
    REDIS_HOST=${var.redis_host}
    REDIS_PORT=${var.redis_port}
    DEBUG=False
    EOL
    
    # Pull and run backend container
    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${var.ecr_repository_url}
    docker pull ${var.ecr_repository_url}:latest
    docker run -d \
      --name backend \
      -p 8000:8000 \
      --env-file /app/.env \
      --restart always \
      ${var.ecr_repository_url}:latest
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-app-instance"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.environment}-app-lt"
    Environment = var.environment
  }
}

data "aws_region" "current" {}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.environment}-app-asg"
  vpc_zone_identifier = var.app_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns         = var.target_group_arns
  health_check_type         = "ELB"
  health_check_grace_period = 300

  default_cooldown          = 300
  force_delete              = false
  wait_for_capacity_timeout = "10m"

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.environment}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "app_scale_up" {
  name                   = "${var.environment}-app-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "app_scale_down" {
  name                   = "${var.environment}-app-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "app_high_cpu" {
  alarm_name          = "${var.environment}-app-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale up if CPU utilization is above 70% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.app_scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_low_cpu" {
  alarm_name          = "${var.environment}-app-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale down if CPU utilization is below 30% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.app_scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}
```

```hcl
# terraform/modules/app_asg/outputs.tf
output "asg_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.app.id
}
```

### 3. ElastiCache Redis Module

```hcl
# terraform/modules/elasticache/variables.tf
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

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.small"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}
```

```hcl
# terraform/modules/elasticache/main.tf
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = var.data_subnet_ids
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.environment}-redis-params"
  family = "redis6.x"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.environment}-redis"
  engine               = "redis"
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.data_security_group_id]
  port                 = 6379
  
  apply_immediately    = true
  auto_minor_version_upgrade = true
  maintenance_window   = "sun:05:00-sun:09:00"
  snapshot_window      = "00:00-04:00"
  snapshot_retention_limit = 7

  tags = {
    Name        = "${var.environment}-redis"
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/elasticache/outputs.tf
output "redis_endpoint" {
  description = "Redis endpoint address"
  value       = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.cache_nodes.0.port
}
```

### 4. Integrating the Application Tier Modules

```hcl
# terraform/environments/prod/app.tf
# Internal Application Load Balancer
module "internal_alb" {
  source = "../../modules/internal_alb"

  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  app_subnet_ids        = module.vpc.app_subnet_ids
  app_security_group_id = module.vpc.app_security_group_id
}

# ElastiCache Redis
module "elasticache" {
  source = "../../modules/elasticache"

  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  data_subnet_ids       = module.vpc.data_subnet_ids
  data_security_group_id = module.vpc.data_security_group_id
  
  node_type        = "cache.t3.small"
  num_cache_nodes  = 1
}

# Application Auto Scaling Group
module "app_asg" {
  source = "../../modules/app_asg"

  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  app_subnet_ids        = module.vpc.app_subnet_ids
  app_security_group_id = module.vpc.app_security_group_id
  target_group_arns     = [module.internal_alb.target_group_arn]
  
  instance_type    = "t3.small"
  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  key_name         = "your-key-pair"
  
  db_host          = module.aurora.db_endpoint
  db_name          = "ecommerce"
  db_port          = "5432"
  redis_host       = module.elasticache.redis_endpoint
  redis_port       = module.elasticache.redis_port
  ecr_repository_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/ecommerce/backend"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

## Containerizing the Backend Application

Before deploying to AWS, we need to containerize our backend application:

### 1. Create a Dockerfile for the Backend

```dockerfile
# Projects/e-commerce/backend/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
```

### 2. Build and Push Docker Image to ECR

```bash
# Create ECR repository
aws ecr create-repository --repository-name ecommerce/backend

# Get the repository URL
REPO_URL=$(aws ecr describe-repositories --repository-names ecommerce/backend --query 'repositories[0].repositoryUri' --output text)

# Authenticate Docker to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $REPO_URL

# Build the Docker image
cd Projects/e-commerce/backend
docker build -t ecommerce/backend:latest .

# Tag the image
docker tag ecommerce/backend:latest $REPO_URL:latest

# Push the image to ECR
docker push $REPO_URL:latest
```

## Application Tier Deployment Best Practices

1. **Stateless Application Design**:
   - Design your application to be stateless
   - Store session data in ElastiCache Redis
   - Ensure any instance can handle any request

2. **Auto Scaling Strategies**:
   - Scale based on CPU utilization
   - Scale based on request count
   - Consider custom metrics like queue depth

3. **Container Optimization**:
   - Use multi-stage builds to reduce image size
   - Implement proper health checks
   - Set appropriate resource limits

4. **Security Best Practices**:
   - Use IAM roles for EC2 instances
   - Implement least privilege access
   - Store secrets in AWS Secrets Manager
   - Encrypt data in transit

5. **High Availability**:
   - Deploy across multiple Availability Zones
   - Implement proper health checks
   - Configure appropriate timeouts and retries

6. **Monitoring and Logging**:
   - Implement structured logging
   - Set up CloudWatch Log Groups
   - Create custom dashboards for application metrics
   - Configure alarms for critical metrics

7. **Performance Optimization**:
   - Use connection pooling for database connections
   - Implement caching strategies
   - Configure appropriate instance types
   - Optimize container resource allocation

In the next part, we will cover the setup of the Data Tier with Aurora PostgreSQL and backup strategies. 
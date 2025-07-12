# AWS 3-Tier Architecture Deployment Guide - Part 3
# Web Tier Setup with Auto Scaling and Load Balancing

## Web Tier Overview

The Web Tier is the presentation layer of our application that handles HTTP requests from users and serves the frontend content. In our architecture, this tier consists of:

1. **Application Load Balancer (ALB)** - Distributes incoming traffic across multiple EC2 instances
2. **Auto Scaling Group (ASG)** - Dynamically adjusts capacity based on demand
3. **EC2 Instances** - Hosts the web server (Nginx) and frontend application
4. **CloudFront** - Content Delivery Network for static assets
5. **S3 Bucket** - Storage for static assets (images, CSS, JavaScript files)

## Terraform Configuration

Let's create the Terraform modules for our Web Tier components:

### 1. Load Balancer Module

```hcl
# terraform/modules/alb/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of SSL certificate"
  type        = string
  default     = ""
}
```

```hcl
# terraform/modules/alb/main.tf
resource "aws_lb" "web" {
  name               = "${var.environment}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true
  enable_http2               = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "${var.environment}-alb-logs"
    enabled = true
  }

  tags = {
    Name        = "${var.environment}-web-alb"
    Environment = var.environment
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.environment}-alb-logs-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.environment}-alb-logs"
    Environment = var.environment
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::elb-account-id:root"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/${var.environment}-alb-logs/AWSLogs/*"]
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Target Group
resource "aws_lb_target_group" "web" {
  name     = "${var.environment}-web-tg"
  port     = 80
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
    Name        = "${var.environment}-web-tg"
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/alb/outputs.tf
output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.web.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.web.arn
}
```

### 2. Auto Scaling Group Module

```hcl
# terraform/modules/asg/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "web_subnet_ids" {
  description = "List of web tier subnet IDs"
  type        = list(string)
}

variable "web_security_group_id" {
  description = "Security group ID for web instances"
  type        = string
}

variable "target_group_arns" {
  description = "List of target group ARNs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
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
```

```hcl
# terraform/modules/asg/main.tf
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
resource "aws_iam_role" "web_instance_role" {
  name = "${var.environment}-web-instance-role"

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
    Name        = "${var.environment}-web-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_instance_profile" "web_instance_profile" {
  name = "${var.environment}-web-instance-profile"
  role = aws_iam_role.web_instance_role.name
}

# Launch Template
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-web-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.web_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.web_security_group_id]
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
    
    # Install Nginx
    amazon-linux-extras install nginx1 -y
    systemctl enable nginx
    systemctl start nginx
    
    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent
    
    # Create health check endpoint
    cat > /usr/share/nginx/html/health <<EOF
    OK
    EOF
    
    # Install Docker for frontend container
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    
    # Pull and run frontend container
    docker pull ${var.ecr_repository_url}:latest
    docker run -d -p 80:80 ${var.ecr_repository_url}:latest
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-web-instance"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.environment}-web-lt"
    Environment = var.environment
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${var.environment}-web-asg"
  vpc_zone_identifier = var.web_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.web.id
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
    value               = "${var.environment}-web-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.environment}-web-scale-up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.environment}-web-scale-down"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.environment}-web-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale up if CPU utilization is above 70% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.environment}-web-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale down if CPU utilization is below 30% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
```

```hcl
# terraform/modules/asg/outputs.tf
output "asg_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.web.id
}
```

### 3. CloudFront and S3 Module for Static Assets

```hcl
# terraform/modules/cdn/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the CloudFront distribution"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
  default     = ""
}
```

```hcl
# terraform/modules/cdn/main.tf
# S3 bucket for static assets
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.environment}-static-assets-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.environment}-static-assets"
    Environment = var.environment
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Block public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  policy = data.aws_iam_policy_document.static_assets.json
}

data "aws_iam_policy_document" "static_assets" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_assets.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.static_assets.arn]
    }
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "static_assets" {
  name                              = "${var.environment}-static-assets-oac"
  description                       = "Origin Access Control for static assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "static_assets" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.environment} static assets distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.static_assets.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.static_assets.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.static_assets.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # 1 day
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # Cache behavior for images
  ordered_cache_behavior {
    path_pattern     = "images/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.static_assets.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # 1 day
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # Cache behavior for CSS/JS
  ordered_cache_behavior {
    path_pattern     = "*.{css,js}"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.static_assets.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # 1 day
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = {
    Name        = "${var.environment}-cloudfront"
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/cdn/outputs.tf
output "s3_bucket_id" {
  description = "ID of the S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_assets.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_assets.domain_name
}
```

### 4. SSL Certificate Module

```hcl
# terraform/modules/acm/variables.tf
variable "domain_name" {
  description = "Domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Subject alternative names for the certificate"
  type        = list(string)
  default     = []
}

variable "validation_method" {
  description = "Validation method for the certificate"
  type        = string
  default     = "DNS"
}
```

```hcl
# terraform/modules/acm/main.tf
resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.domain_name
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}
```

```hcl
# terraform/modules/acm/outputs.tf
output "certificate_arn" {
  description = "ARN of the certificate"
  value       = aws_acm_certificate.cert.arn
}

output "domain_validation_options" {
  description = "Domain validation options"
  value       = aws_acm_certificate.cert.domain_validation_options
}
```

### 5. Integrating the Web Tier Modules

```hcl
# terraform/environments/prod/web.tf
# ACM Certificate
module "acm" {
  source = "../../modules/acm"

  domain_name = "yourdomain.com"
  subject_alternative_names = ["www.yourdomain.com"]
}

# Application Load Balancer
module "alb" {
  source = "../../modules/alb"

  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.vpc.alb_security_group_id
  certificate_arn       = module.acm.certificate_arn
}

# Auto Scaling Group
module "asg" {
  source = "../../modules/asg"

  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  web_subnet_ids        = module.vpc.web_subnet_ids
  web_security_group_id = module.vpc.web_security_group_id
  target_group_arns     = [module.alb.target_group_arn]
  
  instance_type    = "t3.small"
  min_size         = 2
  max_size         = 10
  desired_capacity = 2
  key_name         = "your-key-pair"
}

# CloudFront and S3 for static assets
module "cdn" {
  source = "../../modules/cdn"

  environment     = "prod"
  domain_name     = "yourdomain.com"
  certificate_arn = module.acm.certificate_arn
}

# Route 53 record for ALB
resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "yourdomain.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = data.aws_route53_zone.main.zone_id
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "main" {
  name         = "yourdomain.com"
  private_zone = false
}
```

## Containerizing the Frontend Application

Before deploying to AWS, we need to containerize our frontend application:

### 1. Create a Dockerfile for the Frontend

```dockerfile
# Projects/e-commerce/frontend/Dockerfile
FROM node:16-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 2. Create Nginx Configuration

```nginx
# Projects/e-commerce/frontend/nginx.conf
server {
    listen 80;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://backend:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
```

### 3. Build and Push Docker Image to ECR

```bash
# Create ECR repository
aws ecr create-repository --repository-name ecommerce/frontend

# Get the repository URL
REPO_URL=$(aws ecr describe-repositories --repository-names ecommerce/frontend --query 'repositories[0].repositoryUri' --output text)

# Authenticate Docker to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin $REPO_URL

# Build the Docker image
cd Projects/e-commerce/frontend
docker build -t ecommerce/frontend:latest .

# Tag the image
docker tag ecommerce/frontend:latest $REPO_URL:latest

# Push the image to ECR
docker push $REPO_URL:latest
```

## Web Tier Deployment Best Practices

1. **Immutable Infrastructure**: Use immutable infrastructure patterns by creating new instances instead of updating existing ones.

2. **Blue-Green Deployment**: Implement blue-green deployments to minimize downtime during updates.

3. **Auto Scaling Strategies**:
   - Scale based on CPU utilization
   - Scale based on network traffic
   - Schedule scaling for predictable traffic patterns

4. **Load Balancer Health Checks**:
   - Implement robust health check endpoints
   - Configure appropriate health check intervals and thresholds

5. **CloudFront Optimization**:
   - Use appropriate cache behaviors for different content types
   - Implement origin failover for high availability
   - Enable compression for faster content delivery

6. **Security Best Practices**:
   - Enable WAF for protection against common web exploits
   - Implement rate limiting to prevent DDoS attacks
   - Use HTTPS only for all communications

7. **Monitoring and Alerting**:
   - Set up CloudWatch alarms for key metrics
   - Configure detailed access logs for troubleshooting
   - Implement real-time monitoring dashboards

In the next part, we will cover the setup of the Application Tier with Auto Scaling and internal load balancing. 
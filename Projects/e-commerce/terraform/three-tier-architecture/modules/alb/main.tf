resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.subnet_ids
  idle_timeout       = var.idle_timeout

  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = var.log_bucket
    prefix  = "${var.environment}-alb-logs"
    enabled = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-alb"
    }
  )
}

# Target group for HTTP
resource "aws_lb_target_group" "http" {
  name     = "${var.environment}-tg-http"
  port     = var.target_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    interval            = var.health_check_interval
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    matcher             = var.health_check_matcher
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = var.stickiness_enabled
  }

  deregistration_delay = var.deregistration_delay

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-tg-http"
    }
  )
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-listener-http"
    }
  )
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-listener-https"
    }
  )
}

# CloudWatch Alarm for high error rates
resource "aws_cloudwatch_metric_alarm" "http_5xx_error" {
  alarm_name          = "${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors ALB 5XX error count"
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-alb-5xx-error-alarm"
    }
  )
} 
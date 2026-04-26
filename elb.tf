# Application Load Balancer (ALB) Configuration

# Application Load Balancer
resource "aws_lb" "main" {
  name_prefix        = "al"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Target Group for HTTP
resource "aws_lb_target_group" "http" {
  name_prefix = "http"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = var.target_group_healthy_threshold
    unhealthy_threshold = var.target_group_unhealthy_threshold
    timeout             = var.target_group_health_check_timeout
    interval            = var.target_group_health_check_interval
    path                = var.target_group_health_check_path
    matcher             = "200-299"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.app_name}-tg-http"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for Application Port (8080)
resource "aws_lb_target_group" "app" {
  name_prefix = "app"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    healthy_threshold   = var.target_group_healthy_threshold
    unhealthy_threshold = var.target_group_unhealthy_threshold
    timeout             = var.target_group_health_check_timeout
    interval            = var.target_group_health_check_interval
    path                = var.target_group_health_check_path
    matcher             = "200-299"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.app_name}-tg-app"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
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

# HTTPS Listener (requires ACM certificate)
# Uncomment and update with your ACM certificate ARN
/*
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:region:account:certificate/certificate-id"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
*/

# ALB Listener Rule - Path-based routing example
resource "aws_lb_listener_rule" "api_path" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# ALB Listener Rule - Redirect root to health endpoint
resource "aws_lb_listener_rule" "root_health" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 2

  action {
    type = "redirect"

    redirect {
      path        = var.target_group_health_check_path
      protocol    = "HTTP"
      status_code = "HTTP_302"
    }
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# CloudWatch Alarms for ALB

# Unhealthy Host Count
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when ALB has unhealthy targets"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when response time exceeds 1 second"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# HTTP 5xx Error Count
resource "aws_cloudwatch_metric_alarm" "alb_http_5xx" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-alb-http-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when 5xx errors exceed threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Request Count
resource "aws_cloudwatch_metric_alarm" "alb_request_count" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-alb-request-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100000"
  alarm_description   = "Alert when request count exceeds threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# SNS Topic for ALB Alarms
resource "aws_sns_topic" "alarms" {
  count = var.enable_monitoring && var.alarm_email != "" ? 1 : 0
  name_prefix = "${var.app_name}-alarms"

  tags = {
    Name = "${var.app_name}-alarms-topic"
  }
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.enable_monitoring && var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

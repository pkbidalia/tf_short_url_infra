# Route 53 DNS Configuration

# Hosted Zone (if domain_name is provided)
resource "aws_route53_zone" "main" {
  count = var.route53_domain_name != "" && var.route53_zone_id == "" ? 1 : 0
  name  = var.route53_domain_name

  tags = {
    Name = "${var.app_name}-hosted-zone"
  }
}

# Alias for ALB (direct - for internal use or testing)
resource "aws_route53_record" "alb" {
  count           = var.route53_zone_id != "" || (var.route53_domain_name != "" && var.route53_zone_id == "") ? 1 : 0
  zone_id         = var.route53_zone_id != "" ? var.route53_zone_id : aws_route53_zone.main[0].zone_id
  name            = var.cloudfront_custom_domain != "" ? var.cloudfront_custom_domain : var.route53_domain_name
  type            = "A"
  
  # Use CloudFront if enabled, otherwise ALB
  alias {
    name                   = var.cloudfront_enabled ? aws_cloudfront_distribution.main[0].domain_name : aws_lb.main.dns_name
    zone_id                = var.cloudfront_enabled ? aws_cloudfront_distribution.main[0].hosted_zone_id : aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Alias for CloudFront (with alternative subdomain)
resource "aws_route53_record" "cdn" {
  count           = var.cloudfront_enabled && var.route53_domain_name != "" ? 1 : 0
  zone_id         = var.route53_zone_id != "" ? var.route53_zone_id : aws_route53_zone.main[0].zone_id
  name            = "cdn.${var.route53_domain_name}"
  type            = "A"

  alias {
    name                   = aws_cloudfront_distribution.main[0].domain_name
    zone_id                = aws_cloudfront_distribution.main[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# Geolocation routing policy example (for multi-region)
resource "aws_route53_record" "geolocation_us" {
  count           = var.route53_zone_id != "" || (var.route53_domain_name != "" && var.route53_zone_id == "") ? 1 : 0
  zone_id         = var.route53_zone_id != "" ? var.route53_zone_id : aws_route53_zone.main[0].zone_id
  name            = "geo.${var.route53_domain_name}"
  type            = "A"
  set_identifier  = "US-East"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  geolocation_continent_code = "NA"  # North America
}

# Health Check for ALB
resource "aws_route53_health_check" "alb" {
  count                 = var.route53_zone_id != "" || (var.route53_domain_name != "" && var.route53_zone_id == "") ? 1 : 0
  type                  = "HTTP"
  ip_address            = aws_lb.main.dns_name
  port                  = 80
  resource_path         = var.target_group_health_check_path
  failure_threshold     = 3
  request_interval      = 30
  measure_latency       = true
  enable_sni            = false

  tags = {
    Name = "${var.app_name}-alb-health-check"
  }
}

# Health Check for CloudFront
resource "aws_route53_health_check" "cloudfront" {
  count                 = var.cloudfront_enabled && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  type                  = "HTTPS"
  ip_address            = aws_cloudfront_distribution.main[0].domain_name
  port                  = 443
  resource_path         = var.target_group_health_check_path
  failure_threshold     = 3
  request_interval      = 30
  measure_latency       = true
  enable_sni            = true

  tags = {
    Name = "${var.app_name}-cloudfront-health-check"
  }
}

# CloudWatch Alarms for Route53 Health Checks

# ALB Health Check Failed
resource "aws_cloudwatch_metric_alarm" "route53_alb_health" {
  count               = var.enable_monitoring && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-r53-alb-health"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Alert when Route53 ALB health check fails"
  treat_missing_data  = "notBreaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb[0].id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# CloudFront Health Check Failed
resource "aws_cloudwatch_metric_alarm" "route53_cloudfront_health" {
  count               = var.cloudfront_enabled && var.enable_monitoring && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-r53-cf-health"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Alert when Route53 CloudFront health check fails"
  treat_missing_data  = "notBreaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.cloudfront[0].id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# ALB Health Check Latency
resource "aws_cloudwatch_metric_alarm" "route53_alb_latency" {
  count               = var.enable_monitoring && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-r53-alb-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckPercentageHealthy"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "Alert when Route53 ALB latency is high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb[0].id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# DNS Query Count (for monitoring traffic)
resource "aws_cloudwatch_metric_alarm" "route53_query_count" {
  count               = var.enable_monitoring && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-r53-query-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DNSQueries"
  namespace           = "AWS/Route53"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10000000"  # Alert if more than 10M queries per 5 min
  alarm_description   = "Alert when DNS query count exceeds threshold"
  treat_missing_data  = "notBreaching"

  # Note: This requires Route53 query logging to be enabled
  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Route53 Query Logging
resource "aws_cloudwatch_log_group" "route53_query_logs" {
  count             = var.enable_monitoring && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  name_prefix       = "/aws/route53/${var.app_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.app_name}-route53-query-logs"
  }
}

resource "aws_route53_query_log" "main" {
  count                    = var.enable_monitoring && (var.route53_zone_id != "" || var.route53_domain_name != "") ? 1 : 0
  zone_id                  = var.route53_zone_id != "" ? var.route53_zone_id : aws_route53_zone.main[0].zone_id
  cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.route53_query_logs[0].arn}:*"

  depends_on = [aws_cloudwatch_log_group.route53_query_logs]
}

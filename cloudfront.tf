# CloudFront CDN Configuration

# CloudFront Distribution for global content delivery
resource "aws_cloudfront_distribution" "main" {
  count   = var.cloudfront_enabled ? 1 : 0
  enabled = true

  # Origin configuration (points to ALB)
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "ALB"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Origin Shield for additional caching layer
    origin_shield {
      enabled              = true
      origin_shield_region = var.aws_region
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB"

    # Cache policy - allow most headers for dynamic content
    cache_policy_id         = aws_cloudfront_cache_policy.main[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.main[0].id

    # Compression
    compress = var.cloudfront_compress

    viewer_protocol_policy = "redirect-to-https"

    # Real-time logs
    realtime_log_config_arn = aws_cloudfront_realtime_log_config.main[0].arn
  }

  # Cache behavior for static assets (longer TTL)
  cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB"

    cache_policy_id          = aws_cloudfront_cache_policy.static[0].id
    compress                 = true
    viewer_protocol_policy   = "redirect-to-https"
    realtime_log_config_arn  = aws_cloudfront_realtime_log_config.main[0].arn
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer certificate
  viewer_certificate {
    cloudfront_default_certificate = var.cloudfront_custom_domain == "" ? true : false
    acm_certificate_arn            = var.cloudfront_custom_domain != "" ? var.cloudfront_acm_certificate_arn : null
    ssl_support_method             = var.cloudfront_custom_domain != "" ? "sni-only" : null
    minimum_protocol_version       = var.cloudfront_custom_domain != "" ? "TLSv1.2_2021" : null
  }

  # Aliases for custom domain
  aliases = var.cloudfront_custom_domain != "" ? [var.cloudfront_custom_domain] : []

  # Price class
  price_class = var.cloudfront_price_class

  # HTTP version
  http_version = "http2and3"

  # IPv6 support
  is_ipv6_enabled = true

  tags = {
    Name = "${var.app_name}-cloudfront"
  }

  depends_on = [aws_lb.main]
}

# Cache Policy for Dynamic Content
resource "aws_cloudfront_cache_policy" "main" {
  count       = var.cloudfront_enabled ? 1 : 0
  name_prefix = "${var.app_name}-dynamic-"

  default_ttl = var.cloudfront_default_ttl
  max_ttl     = var.cloudfront_max_ttl
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    query_strings_config {
      query_string_behavior = "all"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Host", "Accept", "Authorization", "Content-Type"]
      }
    }

    cookies_config {
      cookie_behavior = "all"
    }
  }
}

# Cache Policy for Static Content
resource "aws_cloudfront_cache_policy" "static" {
  count       = var.cloudfront_enabled ? 1 : 0
  name_prefix = "${var.app_name}-static-"

  default_ttl = 86400   # 1 day
  max_ttl     = 31536000  # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    query_strings_config {
      query_string_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "main" {
  count       = var.cloudfront_enabled ? 1 : 0
  name_prefix = "${var.app_name}-origin-request-"

  query_strings_config {
    query_string_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = ["CloudFront-Forwarded-Proto", "Host"]
    }
  }

  cookies_config {
    cookie_behavior = "all"
  }
}

# Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "main" {
  count       = var.cloudfront_enabled ? 1 : 0
  name_prefix = "${var.app_name}-response-headers-"

  security_headers_config {
    frame_options {
      frame_option = "DENY"
      override     = false
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = false
    }

    content_type_options {
      override = false
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = false
    }

    strict_transport_security {
      access_control_max_age_secs = 31536000
      include_subdomains          = true
      override                    = false
    }
  }

  custom_headers_config {
    items {
      header   = "X-Content-Type-Options"
      value    = "nosniff"
      override = false
    }

    items {
      header   = "X-Frame-Options"
      value    = "DENY"
      override = false
    }

    items {
      header   = "X-XSS-Protection"
      value    = "1; mode=block"
      override = false
    }
  }
}

# CloudFront Real-time Logs
resource "aws_cloudfront_realtime_log_config" "main" {
  count  = var.cloudfront_enabled ? 1 : 0
  name   = "${var.app_name}-realtime-logs"
  fields = [
    "timestamp",
    "c-ip",
    "c-country",
    "cs-uri-stem",
    "cs-uri-query",
    "cs-host",
    "cs-protocol",
    "cs-method",
    "cs-status",
    "sc-bytes-sent",
    "time-taken",
    "cs-host-header",
    "http-version",
    "user-agent",
    "referer"
  ]

  endpoints {
    kinesis_stream_config {
      role_arn   = aws_iam_role.cloudfront_logs[0].arn
      stream_arn = aws_kinesis_stream.cloudfront_logs[0].arn
    }
  }

  depends_on = [aws_kinesis_stream.cloudfront_logs, aws_iam_role.cloudfront_logs]
}

# Kinesis Data Stream for CloudFront Real-time Logs
resource "aws_kinesis_stream" "cloudfront_logs" {
  count           = var.cloudfront_enabled ? 1 : 0
  name            = "${var.app_name}-cloudfront-logs"
  retention_period = 24
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Name = "${var.app_name}-cloudfront-logs-stream"
  }
}

# IAM Role for CloudFront Logs
resource "aws_iam_role" "cloudfront_logs" {
  count       = var.cloudfront_enabled ? 1 : 0
  name_prefix = "${var.app_name}-cloudfront-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-cloudfront-logs-role"
  }
}

resource "aws_iam_role_policy" "cloudfront_logs" {
  count       = var.cloudfront_enabled ? 1 : 0
  name_prefix = "${var.app_name}-cloudfront-logs-"
  role        = aws_iam_role.cloudfront_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.cloudfront_logs[0].arn
      }
    ]
  })
}

# CloudWatch Alarms for CloudFront

# 4xx Error Rate
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  count               = var.cloudfront_enabled && var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cf-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Alert when CloudFront 4xx error rate exceeds 5%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main[0].id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# 5xx Error Rate
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  count               = var.cloudfront_enabled && var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cf-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when CloudFront 5xx error rate exceeds 1%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main[0].id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Cache Hit Rate
resource "aws_cloudwatch_metric_alarm" "cloudfront_cache_hit_rate" {
  count               = var.cloudfront_enabled && var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cf-cache-hit"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when CloudFront cache hit rate falls below 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main[0].id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

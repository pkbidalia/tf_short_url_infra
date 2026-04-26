# CloudWatch Dashboards and Monitoring Configuration

# Main application monitoring dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_monitoring ? 1 : 0
  dashboard_name = "${var.app_name}-main-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }],
            [".", "HealthyHostCount", { stat = "Average" }],
            [".", "UnHealthyHostCount", { stat = "Average" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            [".", "NetworkIn", { stat = "Sum" }],
            [".", "NetworkOut", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EC2 Metrics"
          dimensions = {
            AutoScalingGroupName = aws_autoscaling_group.app.name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
            [".", "DatabaseConnections", { stat = "Average" }],
            [".", "ReadLatency", { stat = "Average" }],
            [".", "WriteLatency", { stat = "Average" }],
            [".", "FreeableMemory", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
          dimensions = {
            DBInstanceIdentifier = aws_db_instance.main.id
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", { stat = "Average" }],
            [".", "EngineCPUUtilization", { stat = "Average" }],
            [".", "NetworkBytesIn", { stat = "Average" }],
            [".", "NetworkBytesOut", { stat = "Average" }],
            [".", "CacheHitRate", { stat = "Average" }],
            [".", "Evictions", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ElastiCache (Redis) Metrics"
          dimensions = {
            ReplicationGroupId = aws_elasticache_replication_group.main.id
          }
        }
      }
    ]
  })
}

# Application-specific dashboard
resource "aws_cloudwatch_dashboard" "application" {
  count          = var.enable_monitoring ? 1 : 0
  dashboard_name = "${var.app_name}-application-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }],
            [".", "TargetResponseTime", { stat = "p99" }]
          ]
          period = 60
          stat   = "Sum"
          region = var.aws_region
          title  = "Request Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average" }],
            [".", "UnHealthyHostCount", { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Target Health"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type = "log"
        properties = {
          query   = "fields @timestamp, @message | stats count() by @log | sort @timestamp desc"
          region  = var.aws_region
          title   = "Application Logs"
        }
      }
    ]
  })
}

# Infrastructure dashboard
resource "aws_cloudwatch_dashboard" "infrastructure" {
  count          = var.enable_monitoring ? 1 : 0
  dashboard_name = "${var.app_name}-infrastructure-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", { stat = "Average" }],
            [".", "GroupInServiceInstances", { stat = "Average" }],
            [".", "GroupPendingInstances", { stat = "Average" }],
            [".", "GroupTerminatingInstances", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Auto Scaling Group Status"
          dimensions = {
            AutoScalingGroupName = aws_autoscaling_group.app.name
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "BinLogDiskUsage", { stat = "Average" }],
            [".", "FreeStorageSpace", { stat = "Average" }],
            [".", "DatabaseConnections", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Database Storage & Connections"
          dimensions = {
            DBInstanceIdentifier = aws_db_instance.main.id
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", { stat = "Average" }],
            [".", "SwapUsage", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Cache Memory Usage"
          dimensions = {
            ReplicationGroupId = aws_elasticache_replication_group.main.id
          }
        }
      }
    ]
  })
}

# Performance dashboard
resource "aws_cloudwatch_dashboard" "performance" {
  count          = var.cloudfront_enabled && var.enable_monitoring ? 1 : 0
  dashboard_name = "${var.app_name}-performance-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", { stat = "Average" }],
            [".", "BytesDownloaded", { stat = "Sum" }],
            [".", "BytesUploaded", { stat = "Sum" }],
            [".", "Requests", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CloudFront CDN Performance"
          dimensions = {
            DistributionId = aws_cloudfront_distribution.main[0].id
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudFront", "4xxErrorRate", { stat = "Average" }],
            [".", "5xxErrorRate", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "CloudFront Error Rates"
          dimensions = {
            DistributionId = aws_cloudfront_distribution.main[0].id
          }
        }
      }
    ]
  })
}

# Log Groups for centralized logging
resource "aws_cloudwatch_log_group" "application" {
  count             = var.enable_monitoring ? 1 : 0
  name_prefix       = "/aws/application/${var.app_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.app_name}-application-logs"
  }
}

resource "aws_cloudwatch_log_group" "alb_access" {
  count             = var.enable_monitoring ? 1 : 0
  name_prefix       = "/aws/alb/${var.app_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.app_name}-alb-access-logs"
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket_prefix = "${var.app_name}-alb-logs"

  tags = {
    Name = "${var.app_name}-alb-logs-bucket"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS CloudTrail for audit logging
resource "aws_cloudtrail" "main" {
  count                      = var.enable_monitoring ? 1 : 0
  name                       = "${var.app_name}-trail"
  s3_bucket_name             = aws_s3_bucket.flow_logs.id
  include_global_service_events = true
  is_multi_region_trail      = true
  enable_log_file_validation = true
  depends_on                 = [aws_iam_role_policy.cloudtrail_policy]

  tags = {
    Name = "${var.app_name}-cloudtrail"
  }
}

# SNS topic for critical alerts
resource "aws_sns_topic" "critical_alarms" {
  count       = var.enable_monitoring && var.alarm_email != "" ? 1 : 0
  name_prefix = "${var.app_name}-critical-alarms"

  tags = {
    Name = "${var.app_name}-critical-alarms-topic"
  }
}

resource "aws_sns_topic_subscription" "critical_alarms" {
  count     = var.enable_monitoring && var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical_alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Lambda for custom metrics
resource "aws_lambda_function" "custom_metrics" {
  count            = var.enable_monitoring ? 1 : 0
  filename         = "lambda_function.zip"
  function_name    = "${var.app_name}-custom-metrics"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      NAMESPACE = "${var.app_name}-custom"
    }
  }

  tags = {
    Name = "${var.app_name}-custom-metrics-lambda"
  }
}

# EventBridge Rule for Lambda invocation
resource "aws_cloudwatch_event_rule" "metrics_collection" {
  count               = var.enable_monitoring ? 1 : 0
  name_prefix         = "${var.app_name}-metrics-collection"
  description         = "Trigger custom metrics collection"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name = "${var.app_name}-metrics-collection-rule"
  }
}

resource "aws_cloudwatch_event_target" "metrics_lambda" {
  count     = var.enable_monitoring ? 1 : 0
  rule      = aws_cloudwatch_event_rule.metrics_collection[0].name
  target_id = "CustomMetricsLambda"
  arn       = aws_lambda_function.custom_metrics[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count          = var.enable_monitoring ? 1 : 0
  statement_id   = "AllowExecutionFromEventBridge"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.custom_metrics[0].function_name
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.metrics_collection[0].arn
}

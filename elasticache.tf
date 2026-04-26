# ElastiCache (Redis) Configuration

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name_prefix = "${var.app_name}-cache-sg"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.app_name}-cache-subnet-group"
  }
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  family      = var.elasticache_parameter_group_family
  name_prefix = "${var.app_name}-cache-params"

  # Optimization parameters for high throughput
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"  # Evict least recently used keys
  }

  parameter {
    name  = "tcp-backlog"
    value = "511"
  }

  parameter {
    name  = "timeout"
    value = "600"  # Close idle connections after 600 seconds
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  tags = {
    Name = "${var.app_name}-cache-parameter-group"
  }
}

# ElastiCache Replication Group (Redis Cluster)
resource "aws_elasticache_replication_group" "main" {
  replication_group_description = "Redis cluster for ${var.app_name}"
  engine                        = var.elasticache_engine
  engine_version                = var.elasticache_engine_version
  port                          = 6379
  node_type                     = var.elasticache_node_type
  num_cache_clusters            = var.elasticache_num_cache_nodes
  parameter_group_name          = aws_elasticache_parameter_group.main.name
  subnet_group_name             = aws_elasticache_subnet_group.main.name
  security_group_ids            = [aws_security_group.elasticache.id]

  # Cluster mode for horizontal scaling
  automatic_failover_enabled = var.elasticache_automatic_failover_enabled
  multi_az_enabled           = var.elasticache_automatic_failover_enabled

  # Encryption
  at_rest_encryption_enabled = var.elasticache_at_rest_encryption_enabled
  transit_encryption_enabled = var.elasticache_transit_encryption_enabled
  kms_key_id                 = aws_kms_key.secrets.arn

  # Auth Token (optional)
  auth_token = var.elasticache_auth_token != "" ? var.elasticache_auth_token : null

  # Apply immediately for critical updates
  apply_immediately = false

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_slow_log[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
    enabled          = var.enable_monitoring
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_engine_log[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
    enabled          = var.enable_monitoring
  }

  tags = {
    Name = "${var.app_name}-redis-cluster"
  }

  depends_on = [aws_security_group.elasticache]

  lifecycle {
    ignore_changes = [num_cache_clusters]
  }
}

# CloudWatch Log Groups for ElastiCache
resource "aws_cloudwatch_log_group" "elasticache_slow_log" {
  count             = var.enable_monitoring ? 1 : 0
  name_prefix       = "/aws/elasticache/${var.app_name}-slow-log"
  retention_in_days = 7

  tags = {
    Name = "${var.app_name}-elasticache-slow-log"
  }
}

resource "aws_cloudwatch_log_group" "elasticache_engine_log" {
  count             = var.enable_monitoring ? 1 : 0
  name_prefix       = "/aws/elasticache/${var.app_name}-engine-log"
  retention_in_days = 7

  tags = {
    Name = "${var.app_name}-elasticache-engine-log"
  }
}

# CloudWatch Alarms for ElastiCache

# Cache CPU
resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cache-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "Alert when ElastiCache CPU exceeds 75%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Evictions (indicates memory pressure)
resource "aws_cloudwatch_metric_alarm" "cache_evictions" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cache-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "Alert when Redis evictions exceed 1000"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Cache Hit Rate
resource "aws_cloudwatch_metric_alarm" "cache_hit_rate" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cache-hit-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"  # Alert if hit rate below 80%
  alarm_description   = "Alert when cache hit rate drops below 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Database Memory Usage
resource "aws_cloudwatch_metric_alarm" "cache_database_memory_usage_percentage" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cache-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "Alert when ElastiCache memory usage exceeds 90%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Network Bytes In
resource "aws_cloudwatch_metric_alarm" "cache_network_bytes_in" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cache-network-in"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkBytesIn"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000000000"  # 1GB/s
  alarm_description   = "Alert when ElastiCache network input exceeds 1GB/s"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Replication Lag
resource "aws_cloudwatch_metric_alarm" "cache_replication_lag" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-cache-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReplicationLag"
  namespace           = "AWS/ElastiCache"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "5"  # seconds
  alarm_description   = "Alert when ElastiCache replication lag exceeds 5 seconds"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

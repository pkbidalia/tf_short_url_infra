# RDS Database Configuration

# RDS DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.app_name}-db-subnet-group"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# RDS DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family      = "mysql8.0"
  name_prefix = "${var.app_name}-db-params"
  
  # Performance optimizations for high-volume URL lookups
  parameter {
    name  = "max_connections"
    value = "1000"
  }

  parameter {
    name  = "query_cache_size"
    value = "0"
    apply_method = "immediate"
  }

  parameter {
    name  = "query_cache_type"
    value = "0"
    apply_method = "immediate"
  }

  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "innodb_log_file_size"
    value = "512"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
    apply_method = "immediate"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
    apply_method = "immediate"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
    apply_method = "immediate"
  }

  tags = {
    Name = "${var.app_name}-db-parameter-group"
  }
}

# RDS DB Option Group (if needed for extensions)
resource "aws_db_option_group" "main" {
  name_prefix          = "${var.app_name}-db-opts"
  option_group_description = "Option group for ${var.app_name}"
  engine_name          = var.rds_engine
  major_engine_version = "8.0"

  tags = {
    Name = "${var.app_name}-db-option-group"
  }
}

# Enhanced Monitoring IAM Role for RDS
resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "${var.app_name}-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Database Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.app_name}-db"
  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = var.rds_enable_storage_encryption
  kms_key_id            = aws_kms_key.secrets.arn

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  option_group_name      = aws_db_option_group.main.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = var.rds_backup_window
  maintenance_window     = var.rds_maintenance_window
  copy_tags_to_snapshot  = true
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.app_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Monitoring & Logging
  monitoring_interval           = 60
  monitoring_role_arn           = aws_iam_role.rds_monitoring.arn
  enable_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  # Security & Compliance
  enable_iam_database_authentication = var.rds_enable_iam_database_authentication
  enable_performance_insights        = var.rds_performance_insights_enabled
  performance_insights_retention_period = 7
  performance_insights_kms_key_id    = aws_kms_key.secrets.arn

  # Backup & Restore
  deletion_protection = true
  
  # Network & Storage
  storage_throughput = 125  # gp3 optimization

  tags = {
    Name = "${var.app_name}-database"
  }

  depends_on = [
    aws_security_group.rds,
    aws_kms_key.secrets,
    aws_iam_role.rds_monitoring
  ]
}

# RDS Read Replica (for read-heavy workloads in same region)
resource "aws_db_instance" "read_replica" {
  identifier            = "${var.app_name}-db-read-replica"
  replicate_source_db   = aws_db_instance.main.identifier
  instance_class        = var.rds_instance_class
  publicly_accessible   = false
  auto_minor_version_upgrade = false
  skip_final_snapshot   = true

  tags = {
    Name = "${var.app_name}-db-read-replica"
  }

  depends_on = [aws_db_instance.main]
}

# CloudWatch Alarms for RDS

# Database CPU
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when RDS CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Database Free Memory
resource "aws_cloudwatch_metric_alarm" "rds_free_memory" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-free-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "268435456"  # 256 MB
  alarm_description   = "Alert when RDS free memory is below 256 MB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Database Connections
resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "800"
  alarm_description   = "Alert when RDS connections exceed 800"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Read Latency
resource "aws_cloudwatch_metric_alarm" "rds_read_latency" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"  # milliseconds
  alarm_description   = "Alert when RDS read latency exceeds 1ms"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Write Latency
resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"  # milliseconds
  alarm_description   = "Alert when RDS write latency exceeds 2ms"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Disk Queue Depth (IO bottleneck indicator)
resource "aws_cloudwatch_metric_alarm" "rds_disk_queue_depth" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-disk-queue"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "Alert when RDS disk queue depth exceeds 10"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Free Storage Space
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-rds-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10737418240"  # 10 GB
  alarm_description   = "Alert when RDS free storage is below 10 GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

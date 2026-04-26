# Terraform Outputs

# VPC Information
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

# Public Subnets
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Private Subnets
output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# Database Subnets
output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = aws_subnet.database[*].id
}

# ALB Information
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "ALB Zone ID"
  value       = aws_lb.main.zone_id
}

output "target_group_app_arn" {
  description = "Target group ARN for application"
  value       = aws_lb_target_group.app.arn
}

output "target_group_app_name" {
  description = "Target group name for application"
  value       = aws_lb_target_group.app.name
}

# Auto Scaling Group Information
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = aws_autoscaling_group.app.arn
}

output "asg_desired_capacity" {
  description = "ASG desired capacity"
  value       = aws_autoscaling_group.app.desired_capacity
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.app.id
}

# RDS Database Information
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "RDS database address"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS database port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_resource_id" {
  description = "RDS resource ID"
  value       = aws_db_instance.main.resource_id
}

output "rds_read_replica_endpoint" {
  description = "RDS read replica endpoint"
  value       = aws_db_instance.read_replica.endpoint
  sensitive   = true
}

# ElastiCache (Redis) Information
output "elasticache_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "elasticache_port" {
  description = "ElastiCache port"
  value       = aws_elasticache_replication_group.main.port
}

output "elasticache_configuration_endpoint" {
  description = "ElastiCache configuration endpoint"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
  sensitive   = true
}

output "elasticache_replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.main.id
}

output "elasticache_member_clusters" {
  description = "ElastiCache member cluster IDs"
  value       = aws_elasticache_replication_group.main.member_clusters
}

# CloudFront Information
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.cloudfront_enabled ? aws_cloudfront_distribution.main[0].domain_name : "CloudFront not enabled"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.cloudfront_enabled ? aws_cloudfront_distribution.main[0].id : "CloudFront not enabled"
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  value       = var.cloudfront_enabled ? aws_cloudfront_distribution.main[0].hosted_zone_id : "CloudFront not enabled"
}

# Route53 Information
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.route53_zone_id != "" ? var.route53_zone_id : (var.route53_domain_name != "" ? aws_route53_zone.main[0].zone_id : "Route53 not configured")
}

output "route53_name_servers" {
  description = "Route53 name servers"
  value       = var.route53_domain_name != "" && var.route53_zone_id == "" ? aws_route53_zone.main[0].name_servers : "Route53 not configured"
}

# Security Groups
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "elasticache_security_group_id" {
  description = "ElastiCache security group ID"
  value       = aws_security_group.elasticache.id
}

# IAM Roles
output "ec2_role_arn" {
  description = "EC2 IAM role ARN"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda_role.arn
}

# CloudWatch
output "application_log_group" {
  description = "CloudWatch application log group name"
  value       = var.enable_monitoring ? aws_cloudwatch_log_group.application[0].name : "CloudWatch monitoring not enabled"
}

output "alb_log_group" {
  description = "CloudWatch ALB log group name"
  value       = var.enable_monitoring ? aws_cloudwatch_log_group.alb_access[0].name : "CloudWatch monitoring not enabled"
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = var.enable_monitoring ? "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : "CloudWatch monitoring not enabled"
}

# S3 Buckets
output "flow_logs_bucket" {
  description = "S3 bucket for VPC flow logs"
  value       = aws_s3_bucket.flow_logs.id
}

output "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

# KMS Key
output "secrets_kms_key_id" {
  description = "KMS key ID for secrets encryption"
  value       = aws_kms_key.secrets.id
}

output "secrets_kms_key_arn" {
  description = "KMS key ARN for secrets encryption"
  value       = aws_kms_key.secrets.arn
}

# AMI Information
output "ami_id" {
  description = "AMI ID used for EC2 instances"
  value       = data.aws_ami.amazon_linux_2.id
}

output "ami_name" {
  description = "AMI name used for EC2 instances"
  value       = data.aws_ami.amazon_linux_2.name
}

# Connection Strings (for developers)
output "mysql_connection_string" {
  description = "MySQL connection string"
  value       = "mysql -h ${aws_db_instance.main.address} -P ${aws_db_instance.main.port} -u ${var.rds_username} -p"
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "redis-cli -h ${aws_elasticache_replication_group.main.primary_endpoint_address} -p ${aws_elasticache_replication_group.main.port}"
}

# Quick Reference
output "quick_reference" {
  description = "Quick reference information"
  value = {
    region                = var.aws_region
    environment           = var.environment
    application_name      = var.app_name
    alb_dns               = aws_lb.main.dns_name
    rds_endpoint          = aws_db_instance.main.address
    redis_endpoint        = aws_elasticache_replication_group.main.primary_endpoint_address
    cloudfront_enabled    = var.cloudfront_enabled
    monitoring_enabled    = var.enable_monitoring
    asg_min_capacity      = aws_autoscaling_group.app.min_size
    asg_max_capacity      = aws_autoscaling_group.app.max_size
    asg_desired_capacity  = aws_autoscaling_group.app.desired_capacity
    rds_instance_class    = aws_db_instance.main.instance_class
    cache_node_type       = aws_elasticache_replication_group.main.node_type
    cache_num_nodes       = aws_elasticache_replication_group.main.num_cache_clusters
  }
}

# Summary Output
output "infrastructure_summary" {
  description = "Summary of the deployed infrastructure"
  value       = "\n${var.app_name} infrastructure deployed successfully!\n\nKey Resources:\n- ALB: ${aws_lb.main.dns_name}\n- RDS: ${aws_db_instance.main.address}\n- ElastiCache: ${aws_elasticache_replication_group.main.primary_endpoint_address}\n${var.cloudfront_enabled ? "- CloudFront: ${aws_cloudfront_distribution.main[0].domain_name}\n" : ""}- ASG: ${aws_autoscaling_group.app.name}\n- Region: ${var.aws_region}\n- Environment: ${var.environment}\n"
}

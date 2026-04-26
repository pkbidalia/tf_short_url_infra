variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "short-url"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "availability_zones" {
  description = "Number of availability zones for multi-AZ deployment"
  type        = number
  default     = 3
  
  validation {
    condition     = var.availability_zones >= 2 && var.availability_zones <= 4
    error_message = "Availability zones must be between 2 and 4."
  }
}

# EC2 & Auto Scaling Configuration
variable "instance_type" {
  description = "EC2 instance type for application servers"
  type        = string
  default     = "t3.medium"
}

variable "ami_name_filter" {
  description = "Filter for AMI name (Amazon Linux 2, Ubuntu, etc.)"
  type        = string
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "ami_owner" {
  description = "Owner of the AMI (amazon, self, etc.)"
  type        = string
  default     = "amazon"
}

variable "instance_count_per_az" {
  description = "Number of EC2 instances per availability zone"
  type        = number
  default     = 2
  
  validation {
    condition     = var.instance_count_per_az > 0 && var.instance_count_per_az <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 60
}

variable "desired_capacity" {
  description = "Desired capacity of ASG"
  type        = number
  default     = 9
}

# Load Balancer Configuration
variable "alb_internal" {
  description = "Whether ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "target_group_health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/health"
}

variable "target_group_health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.target_group_health_check_interval >= 5 && var.target_group_health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "target_group_health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "target_group_healthy_threshold" {
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2
}

variable "target_group_unhealthy_threshold" {
  description = "Number of consecutive failed health checks required"
  type        = number
  default     = 3
}

# RDS Configuration
variable "rds_engine" {
  description = "RDS database engine (mysql, postgres, mariadb)"
  type        = string
  default     = "mysql"
  
  validation {
    condition     = contains(["mysql", "postgres", "mariadb"], var.rds_engine)
    error_message = "RDS engine must be mysql, postgres, or mariadb."
  }
}

variable "rds_engine_version" {
  description = "RDS database engine version"
  type        = string
  default     = "8.0"
}

variable "rds_instance_class" {
  description = "RDS instance class (db.t3.small to db.r5.4xlarge)"
  type        = string
  default     = "db.r5.large"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 65536
    error_message = "RDS storage must be between 20 and 65536 GB."
  }
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 500
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days (0 to 35)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "Backup retention must be between 0 and 35 days."
  }
}

variable "rds_backup_window" {
  description = "Preferred backup window (UTC, format: HH:MM-HH:MM)"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Preferred maintenance window (format: ddd:HH:MM-ddd:HH:MM UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "rds_multi_az" {
  description = "Enable RDS Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "rds_db_name" {
  description = "RDS initial database name"
  type        = string
  default     = "shorturl"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "rds_password" {
  description = "RDS master password (min 8 chars, alphanumeric + special)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.rds_password) >= 8
    error_message = "RDS password must be at least 8 characters long."
  }
}

variable "rds_enable_storage_encryption" {
  description = "Enable RDS encryption at rest"
  type        = bool
  default     = true
}

variable "rds_enable_iam_database_authentication" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = true
}

variable "rds_performance_insights_enabled" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = true
}

# ElastiCache Configuration
variable "elasticache_engine" {
  description = "ElastiCache engine (redis)"
  type        = string
  default     = "redis"
  
  validation {
    condition     = var.elasticache_engine == "redis"
    error_message = "Only Redis is supported in this template."
  }
}

variable "elasticache_engine_version" {
  description = "ElastiCache Redis version"
  type        = string
  default     = "7.0"
}

variable "elasticache_node_type" {
  description = "ElastiCache node type (cache.t3.micro to cache.r6g.16xlarge)"
  type        = string
  default     = "cache.t3.micro"
}

variable "elasticache_num_cache_nodes" {
  description = "Number of ElastiCache nodes"
  type        = number
  default     = 3
  
  validation {
    condition     = var.elasticache_num_cache_nodes >= 1 && var.elasticache_num_cache_nodes <= 500
    error_message = "Number of cache nodes must be between 1 and 500."
  }
}

variable "elasticache_parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
  default     = "redis7"
}

variable "elasticache_automatic_failover_enabled" {
  description = "Enable automatic failover for Redis cluster"
  type        = bool
  default     = true
}

variable "elasticache_at_rest_encryption_enabled" {
  description = "Enable encryption at rest for ElastiCache"
  type        = bool
  default     = true
}

variable "elasticache_transit_encryption_enabled" {
  description = "Enable encryption in transit for ElastiCache"
  type        = bool
  default     = true
}

variable "elasticache_auth_token" {
  description = "Auth token for Redis (min 16 chars)"
  type        = string
  sensitive   = true
  default     = ""
}

# CloudFront Configuration
variable "cloudfront_enabled" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, _200, _All)"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "Price class must be PriceClass_100, _200, or _All."
  }
}

variable "cloudfront_default_ttl" {
  description = "CloudFront default TTL in seconds"
  type        = number
  default     = 3600
}

variable "cloudfront_max_ttl" {
  description = "CloudFront max TTL in seconds"
  type        = number
  default     = 86400
}

variable "cloudfront_compress" {
  description = "Enable automatic compression in CloudFront"
  type        = bool
  default     = true
}

variable "cloudfront_custom_domain" {
  description = "Custom domain name for CloudFront (optional)"
  type        = string
  default     = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (required if custom_domain is set)"
  type        = string
  default     = ""
}

# Route53 Configuration
variable "route53_zone_id" {
  description = "Route53 hosted zone ID (optional for existing zone)"
  type        = string
  default     = ""
}

variable "route53_domain_name" {
  description = "Domain name for Route53 (required for DNS setup)"
  type        = string
  default     = ""
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address for SNS alarm notifications"
  type        = string
  default     = ""
}

variable "alarm_actions_enabled" {
  description = "Enable alarm actions (SNS notifications)"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms"
  type        = number
  default     = 80
  
  validation {
    condition     = var.cpu_alarm_threshold > 0 && var.cpu_alarm_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

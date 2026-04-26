# Main Terraform Configuration

# Local values for common configurations
locals {
  common_tags = {
    Project     = var.app_name
    Environment = var.environment
    CreatedBy   = "Terraform"
    CreatedDate = timestamp()
  }

  all_tags = merge(local.common_tags, var.additional_tags)
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# This is the main entry point for the infrastructure
# All modules and resources are defined in separate files:
# - provider.tf: AWS provider configuration
# - variables.tf: Variable definitions
# - vpc.tf: VPC and networking
# - security_groups.tf: Security group rules
# - iam.tf: IAM roles and policies
# - elb.tf: Application Load Balancer
# - asg.tf: Auto Scaling Group configuration
# - rds.tf: RDS database
# - elasticache.tf: Redis cluster
# - cloudfront.tf: CloudFront CDN
# - route53.tf: DNS configuration
# - cloudwatch.tf: Monitoring and dashboards
# - outputs.tf: Output values

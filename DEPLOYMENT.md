# Deployment Guide

## Prerequisites

### Required Tools

1. **Terraform** (v1.0+)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Windows
   choco install terraform
   ```

2. **AWS CLI** (v2.x)
   ```bash
   # macOS
   brew install awscliv2
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Windows
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

3. **jq** (optional, for JSON processing)
   ```bash
   brew install jq  # macOS
   sudo apt install jq  # Ubuntu/Debian
   ```

### AWS Account Setup

1. **Create AWS Account** (if needed)
2. **Create IAM User** with AdministratorAccess policy
3. **Generate Access Keys**:
   - Go to AWS Console → IAM → Users → Security credentials
   - Create access key
   - Save Access Key ID and Secret Access Key

4. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter:
   # AWS Access Key ID: [Your Key ID]
   # AWS Secret Access Key: [Your Secret Key]
   # Default region: us-east-1
   # Default output format: json
   ```

### Verify AWS Credentials

```bash
aws sts get-caller-identity
# Expected output:
# {
#     "UserId": "AIDAI...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/terraform-user"
# }
```

## Step-by-Step Deployment

### Step 1: Clone/Download Repository

```bash
git clone https://github.com/your-org/tf-short-url-infra.git
cd tf-short-url-infra
```

Or download and extract the files to your workspace.

### Step 2: Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
vim terraform.tfvars
```

**Key variables to customize**:

```hcl
# AWS Configuration
aws_region = "us-east-1"
environment = "production"
app_name = "short-url"

# Database Credentials (CHANGE THIS!)
rds_password = "YourSecurePassword123!"

# Monitoring
alarm_email = "your-email@example.com"

# DNS (optional)
route53_domain_name = "shorturl.example.com"

# SSL Certificate (optional, for HTTPS)
cloudfront_custom_domain = "api.shorturl.example.com"
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

This command:
- Downloads AWS provider
- Initializes backend (local by default)
- Creates `.terraform` directory

**Optional: Setup Remote State (S3 Backend)**

For production, store Terraform state in S3:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket terraform-state-$(date +%s) \
  --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

Uncomment and update the `backend` block in `provider.tf`:

```hcl
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "short-url-infra/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-lock"
}
```

Then reinitialize:

```bash
terraform init -migrate-state
```

### Step 4: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### Step 5: Plan Deployment

```bash
# Generate and review the execution plan
terraform plan -out=tfplan

# Review the plan carefully
# Expected: ~50-60 resources will be created
```

**Review the plan output**:
- Check resource names and counts
- Verify no unexpected deletions
- Ensure correct region (us-east-1)
- Confirm instance types and sizes

### Step 6: Apply Configuration

```bash
# Apply the Terraform configuration
terraform apply tfplan

# This will take 15-30 minutes
# Terraform will display progress messages
```

**During deployment, Terraform will create**:
1. VPC, Subnets, Route Tables
2. Security Groups
3. IAM Roles and Policies
4. Application Load Balancer
5. Auto Scaling Group with EC2 instances
6. RDS Database Instance
7. ElastiCache Redis Cluster
8. CloudFront Distribution
9. Route53 Records (if configured)
10. CloudWatch Dashboards and Alarms
11. CloudTrail and Logging

### Step 7: Verify Deployment

```bash
# Display outputs
terraform output

# Example outputs:
# alb_dns_name = "short-url-alb-123456789.us-east-1.elb.amazonaws.com"
# rds_address = "short-url-db.c9akciq32.us-east-1.rds.amazonaws.com"
# elasticache_endpoint = "short-url-001.abcdef.ng.0001.use1.cache.amazonaws.com"
```

**Health Checks**:

```bash
# Check ALB targets (may show "draining" initially)
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_app_arn)

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier short-url-db \
  --query 'DBInstances[0].[DBInstanceStatus,MultiAZ]'

# Check ElastiCache cluster
aws elasticache describe-replication-groups \
  --replication-group-id short-url-001 \
  --query 'ReplicationGroups[0].[Status,AutomaticFailover]'

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names short-url-asg \
  --query 'AutoScalingGroups[0].[DesiredCapacity,Instances]'
```

### Step 8: Access Infrastructure

**Application Load Balancer**:

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -v http://$ALB_DNS/health
```

Expected response: JSON with health status

**RDS Database**:

```bash
RDS_ENDPOINT=$(terraform output -raw rds_address)
mysql -h $RDS_ENDPOINT -u admin -p
# Enter password: (what you set in terraform.tfvars)
```

**ElastiCache Redis**:

```bash
REDIS_ENDPOINT=$(terraform output -raw elasticache_endpoint)
redis-cli -h $REDIS_ENDPOINT ping
# Expected: PONG
```

**CloudFront Distribution**:

```bash
CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CF_DOMAIN/health
```

### Step 9: Configure Application

1. **Deploy Application Code**:
   ```bash
   # SSH into EC2 instance (via Systems Manager Session Manager)
   INSTANCE_ID=$(aws ec2 describe-instances \
     --filters "Name=instance.state.name,Values=running" \
     --query 'Reservations[0].Instances[0].InstanceId' -o text)
   
   aws ssm start-session --target $INSTANCE_ID
   
   # Check application status
   systemctl status short-url
   
   # View application logs
   journalctl -u short-url -f
   ```

2. **Set Database Credentials**:
   ```bash
   # Store credentials in AWS Secrets Manager
   aws secretsmanager create-secret \
     --name short-url/rds-credentials \
     --secret-string '{"username":"admin","password":"YourSecurePassword123!"}'
   ```

3. **Configure Application Environment**:
   ```bash
   # SSH into instance via Systems Manager
   aws ssm start-session --target $INSTANCE_ID
   
   # Edit application config
   sudo nano /opt/short-url/.env
   ```

### Step 10: Test Infrastructure

**Load Testing**:

```bash
# Install Apache Bench
sudo apt install apache2-utils  # Ubuntu/Debian
brew install httpd               # macOS

# Run load test
ab -n 10000 -c 100 http://$ALB_DNS/health
```

**Failover Testing**:

```bash
# Test RDS failover
aws rds reboot-db-instance \
  --db-instance-identifier short-url-db \
  --force-failover

# Test EC2 instance replacement
aws ec2 terminate-instances \
  --instance-ids <instance-id>

# Monitor Auto Scaling Group replacement
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names short-url-asg \
  --query "AutoScalingGroups[0].[DesiredCapacity,Instances]"'
```

## Post-Deployment Configuration

### Enable HTTPS (SSL/TLS)

1. **Request ACM Certificate**:
   ```bash
   aws acm request-certificate \
     --domain-name shorturl.example.com \
     --validation-method DNS \
     --region us-east-1
   ```

2. **Update Route53 records** with DNS validation
3. **Update terraform.tfvars**:
   ```hcl
   cloudfront_custom_domain = "shorturl.example.com"
   cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
   ```

4. **Apply changes**:
   ```bash
   terraform plan
   terraform apply
   ```

### Setup Email Alerts

Update terraform.tfvars:
```hcl
alarm_email = "ops-team@example.com"
```

The SNS email subscription will require confirmation - check email for link.

### Initialize Database Schema

```bash
# Connect to RDS
mysql -h $(terraform output -raw rds_address) -u admin -p

# Create tables (run SQL from earlier)
CREATE TABLE urls (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  short_code VARCHAR(10) UNIQUE NOT NULL,
  long_url TEXT NOT NULL,
  ...
);

# Verify
SHOW TABLES;
```

## Scaling & Management

### Increase Capacity

```bash
# Update desired capacity
terraform apply -var="desired_capacity=20"

# Or edit terraform.tfvars
desired_capacity = 20

terraform apply tfplan
```

### Change Instance Type

```bash
# Update instance type
terraform apply -var="instance_type=t3.large"

# Auto Scaling Group performs rolling update
```

### Modify RDS

```bash
# Scale up RDS
terraform apply -var="rds_instance_class=db.r5.xlarge"
# Will cause brief downtime during maintenance window
```

## Monitoring

### View CloudWatch Dashboards

```bash
DASHBOARD_URL=$(terraform output -raw cloudwatch_dashboard_url)
echo "Open in browser: $DASHBOARD_URL"
```

### Check Alarms

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix short-url \
  --query 'MetricAlarms[*].[AlarmName,StateValue]'
```

### View Logs

```bash
# Application logs
aws logs tail /aws/application/short-url --follow

# ALB logs
aws logs tail /aws/alb/short-url --follow

# RDS logs
aws logs tail /aws/rds/short-url-db --follow
```

## Troubleshooting

### Issue: EC2 Instances Not Becoming Healthy

```bash
# Check instance user data logs
aws ssm start-session --target <instance-id>
tail -f /var/log/user_data.log

# Check application logs
journalctl -u short-url -n 50

# Test connectivity
curl http://localhost:8080/health
```

### Issue: RDS Connection Errors

```bash
# Verify security group allows EC2 to RDS
aws ec2 describe-security-groups \
  --group-ids <rds-sg-id> \
  --query 'SecurityGroups[0].IpPermissions'

# Test from EC2 instance
mysql -h <rds-endpoint> -u admin -p
```

### Issue: CloudFront Showing Errors

```bash
# Check CloudFront distribution
AWS_CF_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront get-distribution-config --id $AWS_CF_ID

# Check origin (ALB) health
curl -v http://<alb-dns>/health
```

### Issue: Auto Scaling Not Triggering

```bash
# Check Auto Scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name short-url-asg \
  --max-records 20

# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name short-url-asg
```

## Cleanup & Destruction

### Destroy All Resources

```bash
# Plan destruction
terraform plan -destroy

# Destroy resources
terraform destroy

# Confirm by typing: yes

# This will:
# - Terminate all EC2 instances
# - Delete RDS database (if skip_final_snapshot=true)
# - Delete ElastiCache cluster
# - Delete CloudFront distribution
# - Delete VPC and subnets
# - Remove IAM roles and policies
```

### Selective Destruction

```bash
# Destroy only RDS
terraform destroy -target=aws_db_instance.main

# Destroy only ASG (without disabling protection)
terraform destroy -target=aws_autoscaling_group.app
```

## Best Practices

1. **Always use terraform.tfvars for sensitive data** - don't commit to git
2. **Use tfstate backend** in S3 for production deployments
3. **Enable VCS integration** - use Terraform Cloud or GitOps
4. **Tag all resources** - helps with cost tracking and automation
5. **Test in staging first** - before production deployment
6. **Monitor continuously** - set up appropriate alarms
7. **Regular backups** - RDS automated backups are enabled by default
8. **Review IAM policies** - follow principle of least privilege
9. **Update regularly** - patch EC2 instances and update Terraform modules
10. **Document changes** - maintain deployment runbooks

## Support & Troubleshooting

For additional help:
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for design details
- Review [README.md](README.md) for overview
- Check AWS documentation: https://docs.aws.amazon.com/
- Review Terraform AWS provider docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

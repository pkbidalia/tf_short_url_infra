# Quick Start Guide

## 5-Minute Setup

### 1. Prerequisites
```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Install AWS CLI
brew install awscliv2

# Configure AWS credentials
aws configure
```

### 2. Clone Repository
```bash
git clone git@github.com:pkbidalia/tf-short-url-infra.git
cd tf-short-url-infra
```

### 3. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars

# Edit and update:
# - rds_password (IMPORTANT: Change this!)
# - alarm_email (your email)
# - aws_region (if not using us-east-1)
nano terraform.tfvars
```

### 4. Deploy
```bash
terraform init
terraform plan
terraform apply

# Wait 15-30 minutes for deployment
```

### 5. Verify
```bash
# Get load balancer DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health endpoint
curl http://$ALB_DNS/health

# Done! 🎉
```

---

## File Structure Overview

```
tf_short_url_infra/
├── README.md                    # Main documentation
├── ARCHITECTURE.md              # Detailed architecture
├── DEPLOYMENT.md                # Deployment guide
├── .gitignore                   # Git ignore file
│
├── provider.tf                  # AWS provider config
├── main.tf                      # Entry point
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output values
│
├── vpc.tf                       # Networking (VPC, subnets, gateways)
├── security_groups.tf           # Security group rules
├── iam.tf                       # IAM roles and policies
├── elb.tf                       # Load balancer configuration
├── asg.tf                       # Auto Scaling Group
├── rds.tf                       # RDS database
├── elasticache.tf               # Redis cluster
├── cloudfront.tf                # CDN configuration
├── route53.tf                   # DNS configuration
├── cloudwatch.tf                # Monitoring dashboards
│
├── terraform.tfvars.example     # Example variables
└── user_data.sh                 # EC2 initialization script
```

---

## Resource Summary

| Component | Type | Count | Details |
|-----------|------|-------|---------|
| VPC | Networking | 1 | 10.0.0.0/16 CIDR |
| Subnets | Networking | 9 | 3 per AZ (public, private, database) |
| NAT Gateways | Networking | 3 | 1 per AZ |
| Security Groups | Security | 5 | ALB, EC2, RDS, ElastiCache, VPC Endpoints |
| ALB | Load Balancing | 1 | HTTP/HTTPS, multi-AZ |
| Target Groups | Load Balancing | 2 | HTTP and Application ports |
| Auto Scaling Group | Compute | 1 | 3-60 instances |
| EC2 Instances | Compute | 9 | t3.medium (scalable) |
| RDS Database | Database | 1 | db.r5.large, multi-AZ, 100GB |
| RDS Read Replica | Database | 1 | Same region |
| ElastiCache Cluster | Cache | 1 | Redis 7.0, 3 nodes |
| CloudFront Distribution | CDN | 1 | Global edge locations |
| Route53 Zone | DNS | 1 | Optional, based on config |
| CloudWatch Dashboards | Monitoring | 3 | Main, Application, Infrastructure |
| CloudWatch Alarms | Monitoring | 15+ | CPU, memory, response time, etc. |
| **Total Resources** | | **~60** | |

---

## Common Usage

### Deploy
```bash
terraform apply
```

### View Current Resources
```bash
terraform show
```

### Get Outputs
```bash
terraform output
```

### Scale Up
```bash
terraform apply -var="desired_capacity=20"
```

### Change Instance Type
```bash
terraform apply -var="instance_type=t3.large"
```

### Destroy (Delete Everything)
```bash
terraform destroy
```

---

## Important Outputs After Deployment

Run `terraform output` to see:

- **alb_dns_name**: Load balancer URL (e.g., `short-url-alb-123.us-east-1.elb.amazonaws.com`)
- **rds_address**: Database endpoint
- **elasticache_endpoint**: Redis endpoint
- **cloudfront_domain_name**: CDN URL (if enabled)
- **asg_name**: Auto Scaling Group name
- **cloudwatch_dashboard_url**: Monitoring dashboard

---

## Key Features

✅ **Global Distribution**: CloudFront CDN with 200+ edge locations  
✅ **High Availability**: Multi-AZ across 3+ availability zones  
✅ **Auto-Scaling**: Scales from 3 to 60 instances automatically  
✅ **Database**: RDS MySQL with Multi-AZ failover  
✅ **Caching**: Redis cluster with 3 nodes  
✅ **Monitoring**: CloudWatch dashboards and alarms  
✅ **Security**: Encrypted data, VPC security groups, IAM roles  
✅ **Disaster Recovery**: Multi-AZ backup, read replicas  
✅ **Cost Optimized**: Right-sized resources, scalable architecture  

---

## Configuration Options

### Networking
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `availability_zones`: Number of AZs (default: 3)

### Compute
- `instance_type`: EC2 type (default: t3.medium)
- `min_size`, `max_size`, `desired_capacity`: ASG scaling

### Database
- `rds_engine`: MySQL, PostgreSQL, or MariaDB
- `rds_instance_class`: db.t3.small to db.r6i.4xlarge
- `rds_allocated_storage`: Initial storage (100-65536 GB)
- `rds_backup_retention_period`: 0-35 days

### Cache
- `elasticache_node_type`: cache.t3.micro to cache.r6g.16xlarge
- `elasticache_num_cache_nodes`: 1-500 nodes

### CDN
- `cloudfront_enabled`: true/false
- `cloudfront_price_class`: PriceClass_100, _200, or _All
- `cloudfront_custom_domain`: Custom domain (optional)

### Monitoring
- `enable_monitoring`: true/false
- `alarm_email`: Email for SNS alerts

---

## Estimated Costs

| Component | Monthly |
|-----------|---------|
| ALB | $16 |
| EC2 (6 × t3.medium) | $88 |
| RDS (db.r5.large) | $330 |
| ElastiCache (3 nodes) | $150 |
| CloudFront | $800+ |
| Data Transfer | $500+ |
| **Total** | **~$1,884** |

*Costs vary with usage. Use AWS Cost Explorer for actual estimates.*

---

## Architecture Layers

### Layer 1: Edge
- CloudFront CDN (global caching)
- Route 53 (DNS with geolocation routing)

### Layer 2: Load Balancing
- Application Load Balancer (multi-AZ)
- Health checks and auto-failover

### Layer 3: Compute
- Auto Scaling Group (elastic capacity)
- EC2 instances (stateless application servers)

### Layer 4: Data
- RDS MySQL (primary database)
- ElastiCache Redis (caching layer)
- S3 (logs and assets)

### Layer 5: Management
- CloudWatch (monitoring and alerts)
- CloudTrail (audit logging)
- VPC Flow Logs (network traffic analysis)

---

## Next Steps

1. **Review** the full documentation:
   - [README.md](README.md) - Overview
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed design
   - [DEPLOYMENT.md](DEPLOYMENT.md) - Step-by-step guide

2. **Customize** `terraform.tfvars` for your use case

3. **Deploy** using `terraform apply`

4. **Test** infrastructure with load tests

5. **Monitor** with CloudWatch dashboards

6. **Scale** as needed for your traffic

---

## Support & Troubleshooting

**Check Terraform status**:
```bash
terraform state list
terraform state show <resource>
```

**View CloudWatch Logs**:
```bash
aws logs tail /aws/application/short-url --follow
```

**SSH to EC2 Instance**:
```bash
aws ssm start-session --target <instance-id>
```

**View Alarms**:
```bash
aws cloudwatch describe-alarms --alarm-name-prefix short-url
```

**Check RDS**:
```bash
aws rds describe-db-instances --db-instance-identifier short-url-db
```

---

## IAM Requirements

Terraform requires IAM permissions for:
- EC2 (instances, security groups, AMI access)
- RDS (database creation and management)
- ElastiCache (cluster management)
- ALB (load balancer operations)
- Auto Scaling (ASG management)
- CloudWatch (dashboards, alarms, logs)
- VPC (subnets, route tables, gateways)
- IAM (roles, policies)
- S3 (bucket creation for logs)
- KMS (encryption key management)
- CloudFront (distribution management)
- Route53 (hosted zones, records)

**Recommended Policy**: `AdministratorAccess` for first deployment, then restrict to specific services.

---

## Customization Examples

### Use Different AWS Region
```bash
terraform apply -var="aws_region=eu-west-1"
```

### Larger Database for Production
```bash
terraform apply -var="rds_instance_class=db.r6i.2xlarge"
```

### Enable Custom Domain
Update `terraform.tfvars`:
```hcl
cloudfront_custom_domain = "api.shorturl.example.com"
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
```

### Disable CloudFront (Direct ALB)
```bash
terraform apply -var="cloudfront_enabled=false"
```

---

## Maintenance Checklist

- [ ] Set up SNS email alerts (check spam for confirmation)
- [ ] Configure RDS database schema
- [ ] Deploy application code to EC2 instances
- [ ] Test URL shortening endpoint
- [ ] Load test infrastructure
- [ ] Set up CI/CD pipeline
- [ ] Configure DNS records (if using Route53)
- [ ] Enable HTTPS/SSL (if using custom domain)
- [ ] Set up backup policies
- [ ] Document any custom configurations

---

## Security Checklist

- [ ] Change RDS password from default
- [ ] Enable MFA for AWS account
- [ ] Review IAM policies (principle of least privilege)
- [ ] Enable VPC Flow Logs
- [ ] Enable CloudTrail
- [ ] Configure WAF rules on ALB
- [ ] Rotate RDS credentials regularly
- [ ] Use Secrets Manager for sensitive data
- [ ] Enable RDS automated backups (done by default)
- [ ] Enable encryption at rest and in transit (done by default)

---

**Version**: 1.0  
**Last Updated**: 2026-04-26  
**Maintained By**: DevOps / Infrastructure Team

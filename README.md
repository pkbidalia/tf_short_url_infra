# URL Shortening Application - Global Infrastructure

## Overview

This Terraform configuration deploys a highly available, globally-distributed infrastructure for a URL shortening application on AWS. The architecture is designed to handle billions of users worldwide with low-latency responses and robust reliability.

## Architecture Highlights

### Global Distribution & Performance
- **CloudFront CDN**: Multi-region edge locations worldwide for sub-100ms latency
- **Route 53**: Global DNS with geolocation routing for traffic distribution
- **Multi-Region Readiness**: DynamoDB global tables / RDS read replicas for active-active failover

### Scalability & Load Balancing
- **Auto Scaling Groups**: EC2 instances scale based on CPU/memory metrics
- **Application Load Balancer (ALB)**: Layer 7 load balancing with path-based routing
- **ElastiCache (Redis)**: In-memory caching for frequently accessed URLs
- **DynamoDB or RDS**: Primary data store with provisioned capacity/reserved instances

### Security & Compliance
- **VPC with Private/Public Subnets**: Layered architecture across 3 availability zones
- **Security Groups**: Network-level access control
- **IAM Roles & Policies**: Least privilege access for EC2, Lambda, and other services
- **Encryption**: EBS encryption, RDS encryption at rest, TLS/HTTPS in transit
- **VPC Flow Logs & CloudTrail**: Audit logging for compliance

### Monitoring & High Availability
- **CloudWatch Metrics & Alarms**: Real-time monitoring with SNS notifications
- **Auto Scaling Policies**: Target tracking for CPU, memory, and custom metrics
- **Multi-AZ Deployment**: RDS with automatic failover, ALB health checks
- **X-Ray Integration**: Distributed tracing for performance optimization

## Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                     GLOBAL USERS                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │      Route 53 (DNS)        │
         │  Geolocation Routing       │
         └─────────────┬──────────────┘
                       │
         ┌─────────────▼──────────────┐
         │    CloudFront CDN          │
         │  Edge Locations Worldwide  │
         └─────────────┬──────────────┘
                       │
         ┌─────────────▼──────────────────────┐
         │  Application Load Balancer (ALB)   │
         │  Multi-AZ High Availability        │
         └─────────────┬──────────────────────┘
                       │
         ┌─────────────┴──────────────────────────────────────┐
         │                                                    │
    ┌────▼────┐  ┌────────┐  ┌────────┐   ┌────────┐
    │   AZ-1  │  │  AZ-2  │  │  AZ-3  │   │ Others │
    │┌──────┐ │  │┌──────┐│  │┌──────┐│   │┌──────┐│
    ││ EC2  │ │  ││ EC2  ││  ││ EC2  ││   ││ EC2  ││
    │└──────┘ │  │└──────┘│  │└──────┘│   │└──────┘│
    │┌──────┐ │  │┌──────┐│  │┌──────┐│   │        │
    ││ EC2  │ │  ││ EC2  ││  ││ EC2  ││   │        │
    │└──────┘ │  │└──────┘│  │└──────┘│   │        │
    └────┬────┘  └────┬───┘  └────┬───┘   └────────┘
         │            │           │
         │      ┌─────┴───────────┴────┐
         │      │                      │
         │  ┌───▼────┐          ┌──────▼──┐
         │  │ Elastic│          │   RDS   │
         │  │ Cache  │          │ Multi-AZ│
         │  │(Redis) │          │ (Wriet) │
         │  └────────┘          └─────────┘
         │
         └─────────────────────────────────┐
                                          │
                    ┌─────────────────────▼────────┐
                    │  DynamoDB / RDS Read Replicas│
                    │  Multi-AZ + Global Tables    │
                    └──────────────────────────────┘
```

## Deployment Guide

### Prerequisites

1. **AWS Account**: With appropriate IAM permissions
2. **Terraform**: v1.0+ installed locally
3. **AWS CLI**: Configured with credentials
4. **Environment Variables**: Set AWS region and other configs

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=default
```

### Initial Setup

1. **Clone/Download** this repository
2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Review Variables** in `terraform.tfvars` and customize:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Plan Deployment**:
   ```bash
   terraform plan -out=tfplan
   ```

5. **Apply Configuration**:
   ```bash
   terraform apply tfplan
   ```

### Scaling Parameters

Key variables to tune for your scale:

- `instance_count`: Number of EC2 instances per AZ (default: 2)
- `instance_type`: EC2 instance type (t3.medium → t3.2xlarge)
- `min_size`, `max_size`: Auto Scaling Group bounds
- `rds_allocated_storage`: Database size (100GB → 5TB+)
- `elasticache_num_cache_nodes`: Redis cluster nodes
- `endpoint_enabled`: Enable for highly concurrent workloads

## Estimated Costs (Monthly)

| Component | Est. Usage | Est. Cost |
|-----------|-----------|----------|
| ALB | 1 × 730h | $16 |
| EC2 t3.medium | 6 × 730h | $88 |
| RDS db.r5.large | 730h | $330 |
| ElastiCache Redis | 3 nodes × 730h | $150 |
| CloudFront | 10TB/month | $800 |
| Data Transfer | 10TB/month | $500 |
| **Total** | | **~$1,884/month** |

*Costs scale with traffic volume and instance types. Use AWS Cost Explorer for accurate estimates.*

## Monitoring & Alerts

Access monitoring dashboards:

- **CloudWatch**: VPC → CloudWatch → Dashboards → `url-shortener-dashboard`
- **ALB Metrics**: Application → Load Balancers → Health checks
- **RDS Metrics**: Databases → Performance Insights
- **Auto Scaling**: EC2 → Auto Scaling Groups → Activity history

Key metrics to monitor:

- **Request Rate**: Target Group metrics
- **Latency**: p50, p99 response times
- **Error Rate**: HTTP 5xx responses
- **CPU/Memory**: EC2 and RDS utilization
- **Cache Hit Ratio**: ElastiCache metrics
- **Database Connections**: Active connections

## Cost Optimization

1. **Reserved Instances**: 1-3 year terms for 30-40% savings
2. **Savings Plans**: Compute savings for variable workloads
3. **Spot Instances**: Worker pools for 70%+ savings (via ASG)
4. **RDS Aurora**: Consider Aurora Serverless for variable workloads
5. **CloudFront Optimization**: Enable compression, cache policies
6. **Data Transfer**: Use VPC endpoints to avoid NAT costs

## Security Best Practices

- [ ] Enable VPC Flow Logs to S3
- [ ] Enable CloudTrail for audit logging
- [ ] Implement WAF rules on ALB
- [ ] Rotate database credentials regularly
- [ ] Use Secrets Manager for sensitive data
- [ ] Enable MFA for AWS Console access
- [ ] Implement DLP (Data Loss Prevention) policies
- [ ] Conduct regular security audits

## Auto-Scaling Configuration

The infrastructure automatically scales based on:

- **CPU Utilization**: Scale up at 70%, down at 30%
- **Target Tracking**: Maintains specified ALB request count
- **Scheduled Scaling**: Time-based capacity adjustments
- **Custom Metrics**: Application-specific scaling signals

Scaling limits:
- Min instances: 3 per AZ (9 total)
- Max instances: 20 per AZ (60 total)

## Disaster Recovery

- **RTO (Recovery Time Objective)**: < 5 minutes
- **RPO (Recovery Point Objective)**: < 1 minute

### Failover Scenarios

| Failure | RTO | Recovery Method |
|---------|-----|-----------------|
| Single AZ Down | 2 min | ALB routes to remaining AZs |
| Single EC2 Down | 30 sec | ASG replaces instance |
| RDS Primary Down | < 1 min | Multi-AZ automatic failover |
| Region Down | 10 min | Terraform apply in new region |

## File Structure

```
.
├── README.md                    # This file
├── ARCHITECTURE.md              # Detailed architecture documentation
├── provider.tf                  # AWS provider configuration
├── main.tf                      # Main infrastructure
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output values
├── vpc.tf                       # VPC, subnets, route tables
├── security_groups.tf           # Security group rules
├── iam.tf                       # IAM roles and policies
├── elb.tf                       # Load balancer configuration
├── asg.tf                       # Auto Scaling Group
├── rds.tf                       # RDS database
├── elasticache.tf               # Redis cluster
├── cloudfront.tf                # CDN configuration
├── cloudwatch.tf                # Monitoring dashboards
├── route53.tf                   # DNS configuration
├── terraform.tfvars.example     # Example variables file
└── modules/                     # Reusable Terraform modules
    ├── vpc/
    ├── compute/
    ├── database/
    └── monitoring/
```

## Troubleshooting

### ALB Target Group Unhealthy

```bash
# Check EC2 instance logs
aws ssm start-session --target <instance-id>
tail -f /var/log/application.log
```

### High Database Latency

```bash
# Analyze slow query logs
aws rds describe-db-log-files --db-instance-identifier short-url-db
```

### CloudFront Cache Misses

- Verify cache policies in CloudFront distribution
- Check origin headers for Cache-Control directives
- Monitor CloudFront metrics in CloudWatch

## Support & Contributions

For issues or improvements, please review:
- AWS Well-Architected Framework
- Terraform AWS Provider Documentation
- AWS Best Practices guides

## License

MIT License - See LICENSE file for details

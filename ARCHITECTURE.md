# URL Shortening Infrastructure - Detailed Architecture

## Table of Contents

1. [Overview](#overview)
2. [Architecture Components](#architecture-components)
3. [Network Architecture](#network-architecture)
4. [Compute Architecture](#compute-architecture)
5. [Database Architecture](#database-architecture)
6. [Caching Architecture](#caching-architecture)
7. [Content Delivery](#content-delivery)
8. [Scalability & Performance](#scalability--performance)
9. [Security Architecture](#security-architecture)
10. [Disaster Recovery](#disaster-recovery)
11. [Cost Optimization](#cost-optimization)

## Overview

This infrastructure is designed to support a URL shortening service serving billions of users globally with:

- **Global Distribution**: CloudFront CDN with edge locations worldwide
- **High Availability**: Multi-AZ deployment across 3+ availability zones
- **Auto-Scaling**: Automatic capacity scaling based on demand
- **Low Latency**: In-memory caching with Redis and optimized routing
- **Durability**: Multi-AZ RDS with automated backups and read replicas
- **Monitoring**: Comprehensive CloudWatch dashboards and alarms

## Architecture Components

### Core Infrastructure

```
┌──────────────────────────────────────────────────────────────┐
│                     GLOBAL EDGE LOCATIONS                    │
│                   (CloudFront - 200+ locations)              │
└────┬──────────────────────────────────────┬────────────────┬─┘
     │                                      │                │
┌────▼──────────────────────────────────────▼──────────────┬─▼──┐
│                 Route 53 (Global DNS)                     │    │
│          Geolocation routing / Health checks              │    │
└────┬──────────────────────────────────────┬──────────────┴──┬─┘
     │                                      │                 │
┌────▼──────────────────────────────────────▼────────────────▼────┐
│                                                                    │
│         Availability Zone 1 | AZ 2 | AZ 3 (+ more regions)    │
│                                                                    │
│  ┌─────────────────────────────────────┐                        │
│  │  ALB (Application Load Balancer)    │                        │
│  │  - HTTP/HTTPS Termination           │                        │
│  │  - Health Checks                    │                        │
│  │  - Cross-zone load balancing        │                        │
│  │  - SSL/TLS offloading               │                        │
│  └──────────────────┬──────────────────┘                        │
│                     │                                            │
│     ┌───────────────┼───────────────┐                          │
│     │               │               │                          │
│  ┌──▼──┐         ┌──▼──┐        ┌──▼──┐                      │
│  │ EC2 │         │ EC2 │        │ EC2 │   (ASG)             │
│  │ AZ1 │         │ AZ2 │        │ AZ3 │                      │
│  │ x2  │         │ x2  │        │ x2  │   + Scale up to 60  │
│  └─────┘         └─────┘        └─────┘                      │
│                                                                │
│  ┌──────────────────────────┐  ┌──────────────────────────┐ │
│  │  ElastiCache (Redis)     │  │   RDS (MySQL)            │ │
│  │  - Port: 6379            │  │   - Primary (Write)      │ │
│  │  - 3+ nodes Multi-AZ     │  │   - Standby (Read)       │ │
│  │  - Auth token            │  │   - Read Replica         │ │
│  │  - Encryption enabled    │  │   - Multi-AZ failover    │ │
│  │  - LRU eviction policy   │  │   - Automated backups    │ │
│  └──────────────────────────┘  └──────────────────────────┘ │
│                                                                │
└─────────────────────────────────────────────────────────────┘
```

## Network Architecture

### VPC Design

- **CIDR Block**: 10.0.0.0/16 (65,536 addresses)
- **Subnets per AZ**: 3 (Public, Private, Database)
- **NAT Gateway**: One per AZ for high availability
- **Internet Gateway**: Single IGW for inbound traffic distribution

### Subnet Allocation

```
Public Subnets (Tier 1)
├─ AZ1: 10.0.1.0/24 (256 addresses)
├─ AZ2: 10.0.2.0/24 (256 addresses)
└─ AZ3: 10.0.3.0/24 (256 addresses)

Private Subnets (Tier 2 - Application)
├─ AZ1: 10.0.11.0/24 (256 addresses)
├─ AZ2: 10.0.12.0/24 (256 addresses)
└─ AZ3: 10.0.13.0/24 (256 addresses)

Database Subnets (Tier 3)
├─ AZ1: 10.0.21.0/24 (256 addresses)
├─ AZ2: 10.0.22.0/24 (256 addresses)
└─ AZ3: 10.0.23.0/24 (256 addresses)
```

### Security Architecture (Network)

**Security Groups**:

1. **ALB Security Group**
   - Inbound: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
   - Outbound: All traffic

2. **EC2 Security Group**
   - Inbound: 80, 443, 8080 from ALB SG
   - Inbound: 22 (SSH) from VPC CIDR
   - Outbound: All traffic

3. **RDS Security Group**
   - Inbound: 3306 (MySQL) from EC2 SG
   - Inbound: 5432 (PostgreSQL) from EC2 SG
   - Outbound: All traffic

4. **ElastiCache Security Group**
   - Inbound: 6379 (Redis) from EC2 SG
   - Inbound: 16379 (Redis Cluster) from EC2 SG
   - Outbound: All traffic

5. **VPC Endpoints Security Group**
   - Inbound: 443 (HTTPS) from VPC CIDR
   - Outbound: All traffic

## Compute Architecture

### Auto Scaling Group (ASG)

**Configuration**:
- **Min Size**: 3 instances (1 per AZ minimum)
- **Desired Capacity**: 9 instances (3 per AZ)
- **Max Size**: 60 instances (20 per AZ)

**Launch Template**:
```
Instance Type: t3.medium → t3.2xlarge (configurable)
AMI: Amazon Linux 2 (latest)
EBS Root Volume: 20 GB, gp3, encrypted
IAM Role: EC2 Role with CloudWatch/SSM/RDS access
Monitoring: Enabled (detailed monitoring)
User Data: Automated setup script
```

### Scaling Policies

1. **CPU-Based Scaling** (Target: 70% utilization)
   - Scale up quickly when CPU > 70%
   - Scale down gradually when CPU < 30%

2. **ALB Request Count Scaling** (Target: 1000 requests/target)
   - Additional scaling metric for request volume
   - Complements CPU-based scaling

3. **Scheduled Scaling** (Optional)
   - Scale up at 8 AM on weekdays
   - Scale down at 6 PM on weekdays

### Instance Configuration

**User Data Script Includes**:
- System package updates
- Docker installation
- Node.js/npm installation
- CloudWatch agent setup
- Health check endpoint
- RDS/Redis connectivity testing
- Application logging configuration

## Database Architecture

### RDS MySQL Configuration

**Instance Details**:
```
Engine: MySQL 8.0
Instance Class: db.r5.large (16 GB RAM)
Storage: 100 GB initial, auto-scale to 500 GB
Type: Multi-AZ with automatic failover
Backup: 30-day retention with daily snapshots
```

**Performance Optimizations**:
```
max_connections: 1000
query_cache_type: 0 (disabled for better performance)
innodb_buffer_pool_size: 75% of available RAM
slow_query_log: Enabled (2s threshold)
```

**High Availability Features**:
- Multi-AZ deployment with automatic failover
- Read replica in same region for offloading read queries
- Enhanced monitoring with CloudWatch
- Performance Insights enabled
- IAM database authentication enabled
- Encryption at rest with customer-managed KMS key

### Schema Recommendations

```sql
CREATE TABLE urls (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  short_code VARCHAR(10) UNIQUE NOT NULL,
  long_url TEXT NOT NULL,
  user_id INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  click_count INT DEFAULT 0,
  last_accessed TIMESTAMP,
  INDEX idx_short_code (short_code),
  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE analytics (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  url_id BIGINT NOT NULL,
  user_agent VARCHAR(500),
  referer VARCHAR(500),
  country_code VARCHAR(2),
  ip_address VARCHAR(45),
  accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (url_id) REFERENCES urls(id),
  INDEX idx_url_id (url_id),
  INDEX idx_accessed_at (accessed_at)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## Caching Architecture

### ElastiCache Redis Cluster

**Configuration**:
```
Engine: Redis 7.0
Port: 6379
Cluster Mode: Disabled (but Multi-AZ enabled)
Nodes: 3 (1 primary, 2 replicas across AZs)
Node Type: cache.t3.micro → cache.r6g.xlarge
```

**Features**:
- Multi-AZ automatic failover
- Encryption in transit (TLS)
- Encryption at rest (customer-managed KMS)
- Auth token for access control
- Persistence: RDB snapshots (optional)
- LRU eviction policy (allkeys-lru)

**Cache Strategy**:

```
1. URL Lookups (Most Frequent)
   - Key Pattern: "short:{code}"
   - TTL: 24 hours
   - Value: { url_id, long_url, metadata }

2. User Sessions
   - Key Pattern: "session:{user_id}"
   - TTL: 7 days
   - Value: { user_data, preferences }

3. Popular URLs (Hot Set)
   - Key Pattern: "trending:{timewindow}"
   - TTL: 1 hour
   - Value: List of top URLs

4. Rate Limiting / Throttling
   - Key Pattern: "ratelimit:{ip}:{endpoint}"
   - TTL: 60 seconds
   - Value: Request counter

5. Analytics Aggregations
   - Key Pattern: "stats:{url_id}:{period}"
   - TTL: 1 hour
   - Value: Click counts, locations
```

**Cache Hit Ratio Target**: > 80%

## Content Delivery

### CloudFront Distribution

**Configuration**:
- **Origin**: Application Load Balancer (HTTP backend)
- **Price Class**: PriceClass_100 (minimum cost, can upgrade to PriceClass_All)
- **Compression**: gzip and Brotli enabled
- **IPv6**: Enabled
- **HTTP/2**: Enabled (with HTTP/3 support)

**Cache Behaviors**:

```
1. Dynamic Content (Default)
   Cache Policy: Minimum TTL: 0, Default: 3600s, Max: 86400s
   Compress: Yes
   Query Strings: All
   Headers: Authorization, Host, Accept, Content-Type
   Cookies: All
   Viewer Protocol: Redirect HTTPS

2. Static Assets (/static/*)
   Cache Policy: Min: 0, Default: 86400s, Max: 31536000s (1 year)
   Compress: Yes
   Query Strings: None
   Cookies: None
   Viewer Protocol: HTTPS

3. Origin Shield: Enabled in same region for extra caching layer
```

**Real-time Logs**:
- Streamed to Kinesis Data Stream
- Includes: timestamps, IPs, URIs, status codes, bytes transferred, latency

## Scalability & Performance

### Load Balancing Strategy

**Traffic Flow**:
```
Users → Route 53 (Geo-routing) → CloudFront (Global Cache)
  ↓ (Cache miss)
ALB (us-east-1) → EC2 (ASG, 3 AZs)
  ↓
RDS (MySQL) + ElastiCache (Redis)
```

### Expected Performance

**Latency Targets** (with CloudFront):
- Global requests: < 100ms (p95) from nearest edge location
- Direct to ALB: < 50ms (p95) within region
- Database queries: < 10ms (p95) via cache
- Database queries: < 50ms (p95) on cache miss

**Throughput Targets**:
- URL redirects: 100,000+ requests/second
- URL creations: 10,000+ requests/second
- Analytics ingestion: 50,000+ events/second

### Metrics to Monitor

**Application Metrics**:
- Requests per second (RPS)
- Response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Cache hit ratio

**Infrastructure Metrics**:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)
- Network throughput
- Disk I/O operations

## Security Architecture

### Network Security

1. **DDoS Protection**
   - AWS Shield Standard (automatic)
   - AWS WAF on ALB (optional add-on)
   - CloudFront DDoS mitigation

2. **Encryption**
   - TLS 1.2+ for all HTTPS
   - Encryption in transit for all inter-service communication
   - Encryption at rest for:
     - RDS data and backups (KMS)
     - ElastiCache data (KMS)
     - S3 buckets (AES-256)
     - EBS volumes

3. **Access Control**
   - Security groups with least privilege
   - NACLs for additional layer
   - IAM roles with specific permissions
   - RDS IAM database authentication
   - Redis AUTH tokens

### Data Security

1. **Database Security**
   - Credentials stored in AWS Secrets Manager
   - IAM database authentication
   - Automated encryption at rest
   - Multi-AZ for data redundancy

2. **Application Secrets**
   - API keys in Secrets Manager
   - Rotation policies for credentials
   - KMS encryption for sensitive data

3. **Audit Logging**
   - CloudTrail for API auditing
   - VPC Flow Logs for network traffic
   - RDS audit logging
   - CloudFront logs to S3

## Disaster Recovery

### RTO and RPO Targets

| Scenario | RTO | RPO | Recovery Method |
|----------|-----|-----|-----------------|
| Single EC2 instance fails | 2-5 min | 0 | ASG replaces instance |
| Single AZ fails | 5 min | < 1 min | Traffic routes to other AZs |
| RDS primary fails | < 2 min | < 1 min | Automatic Multi-AZ failover |
| ElastiCache node fails | 1 min | 0 | Cluster replaces node |
| ALB fails | 2 min | 0 | AWS manages (automatic) |
| Complete region failure | 30 min | 5 min | Terraform redeploy in new region |

### Backup Strategy

1. **RDS Backups**
   - Daily automated snapshots (30-day retention)
   - Read replica for read-heavy offloading
   - Point-in-time recovery (up to 35 days)
   - Cross-region backup (optional)

2. **Redis Backups**
   - RDB snapshots (optional, disabled by default)
   - Cluster mode ensures replication

3. **Application Data**
   - S3 versioning enabled for logs
   - 7-day retention for VPC Flow Logs
   - CloudTrail logs stored in S3

## Cost Optimization

### Resource Right-Sizing

**Development/Staging**:
- Instance type: t3.small (1 GB RAM)
- RDS: db.t3.small (2 GB RAM)
- ElastiCache: cache.t3.micro

**Production**:
- Instance type: t3.medium to t3.large
- RDS: db.r5.large to db.r6i.xlarge
- ElastiCache: cache.t3.small to cache.r6g.xlarge

### Cost Reduction Strategies

1. **Reserved Instances**: 1-3 year terms for 30-40% savings
2. **Savings Plans**: 1-3 year compute savings for variable workloads
3. **Spot Instances**: For stateless worker nodes (70%+ savings)
4. **OnDemand**: For critical components (current pricing)

### Estimated Monthly Costs

| Component | Quantity | Cost |
|-----------|----------|------|
| ALB | 1 × 730h | $16 |
| EC2 (t3.medium) | 6 × 730h | $88 |
| RDS (db.r5.large) | 1 × 730h | $330 |
| ElastiCache (3 nodes) | 3 × 730h | $150 |
| CloudFront | 10 TB | $800 |
| Data Transfer | 10 TB | $500 |
| **Total (base)** | | **$1,884** |
| *With Reserved Instances (30% off)* | | *$1,319* |
| *With Spot Instances* | | *$800* |

*Costs scale linearly with traffic; actual costs depend on usage patterns.*

## Monitoring & Observability

### CloudWatch Dashboards

1. **Main Dashboard**: Overview of all components
2. **Application Dashboard**: Request metrics and health
3. **Infrastructure Dashboard**: EC2, RDS, ElastiCache
4. **Performance Dashboard**: CloudFront and CDN metrics

### Key Alarms

- CPU > 80%
- Memory < 256 MB (RDS)
- Cache evictions > 1000/min
- Unhealthy targets in ALB
- Response time > 1 second
- Error rate > 1%
- Replication lag > 5 seconds

### Logging

- **Application Logs**: CloudWatch Logs (/aws/application/*)
- **ALB Logs**: S3 + CloudWatch Logs
- **RDS Logs**: CloudWatch Logs (error, general, slowquery)
- **VPC Flow Logs**: CloudWatch Logs + S3
- **API Calls**: CloudTrail
- **DNS Queries**: Route53 query logging

## Deployment Workflow

### Initial Deployment

```bash
# 1. Initialize Terraform
terraform init

# 2. Plan infrastructure
terraform plan -out=tfplan

# 3. Review and apply
terraform apply tfplan

# 4. Retrieve outputs
terraform output
```

### Post-Deployment Steps

1. Verify all resources are healthy:
   ```bash
   # Check ALB target health
   aws elbv2 describe-target-health --target-group-arn <ARN>
   
   # Check RDS status
   aws rds describe-db-instances --db-instance-identifier short-url-db
   
   # Check ElastiCache cluster
   aws elasticache describe-replication-groups --replication-group-id short-url-001
   ```

2. Configure application secrets:
   ```bash
   # Add database credentials to Secrets Manager
   aws secretsmanager create-secret --name short-url/db-credentials
   ```

3. Deploy application:
   - Push API code to EC2 instances or use ECS/Lambda
   - Set up CI/CD pipeline for deployments

4. Test infrastructure:
   - Run load tests
   - Verify failover scenarios
   - Test backup/restore

## Maintenance & Operations

### Regular Tasks

- **Weekly**: Review CloudWatch alarms and logs
- **Monthly**: Update EC2 AMIs and apply patches
- **Quarterly**: Test disaster recovery procedures
- **Annually**: Review and optimize costs, architecture review

### Upgrades & Changes

- Use `instance_refresh` in ASG for zero-downtime deployments
- Update RDS during maintenance windows
- Use blue-green deployments for major changes

## Further Customizations

See the main [README.md](README.md) and [terraform.tfvars.example](terraform.tfvars.example) for:
- Custom domain setup
- HTTPS/SSL configuration
- Route53 geolocation routing
- Multi-region deployment
- Advanced security configurations

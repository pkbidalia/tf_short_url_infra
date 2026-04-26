# VPC and Networking Configuration

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

# Public Subnets for ALB and NAT Gateway
resource "aws_subnet" "public" {
  count                   = var.availability_zones
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-subnet-${count.index + 1}"
  }
}

# Private Subnets for EC2 instances
resource "aws_subnet" "private" {
  count              = var.availability_zones
  vpc_id             = aws_vpc.main.id
  cidr_block         = var.private_subnet_cidrs[count.index]
  availability_zone  = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.app_name}-private-subnet-${count.index + 1}"
  }
}

# Database Subnets for RDS
resource "aws_subnet" "database" {
  count              = var.availability_zones
  vpc_id             = aws_vpc.main.id
  cidr_block         = var.database_subnet_cidrs[count.index]
  availability_zone  = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.app_name}-db-subnet-${count.index + 1}"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.availability_zones
  domain = "vpc"

  tags = {
    Name = "${var.app_name}-eip-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways (One per AZ for High Availability)
resource "aws_nat_gateway" "main" {
  count         = var.availability_zones
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.app_name}-nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public" {
  count          = var.availability_zones
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables for Private Subnets (one per AZ with NAT Gateway)
resource "aws_route_table" "private" {
  count  = var.availability_zones
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.app_name}-private-rt-${count.index + 1}"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count          = var.availability_zones
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Route Table for Database Subnets (no internet access, only internal)
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-database-rt"
  }
}

# Route Table Associations for Database Subnets
resource "aws_route_table_association" "database" {
  count          = var.availability_zones
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# VPC Flow Logs (for monitoring and troubleshooting)
resource "aws_flow_log_cloudwatch_iam_role" "flow_log_role" {
  count = var.enable_monitoring ? 1 : 0
  name_prefix = "${var.app_name}-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name   = "flow-log-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }

  tags = {
    Name = "${var.app_name}-flow-log-role"
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count             = var.enable_monitoring ? 1 : 0
  name_prefix       = "/aws/vpc/flowlogs/${var.app_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.app_name}-flow-log-group"
  }
}

resource "aws_flow_log" "vpc_flow_log" {
  count                   = var.enable_monitoring ? 1 : 0
  iam_role_arn            = aws_flow_log_cloudwatch_iam_role.flow_log_role[0].arn
  log_destination         = aws_cloudwatch_log_group.flow_log[0].arn
  traffic_type            = "ALL"
  vpc_id                  = aws_vpc.main.id
  log_destination_type    = "cloud-watch-logs"
  log_format              = "${"\u0024{version} \u0024{account_id} \u0024{interface_id} \u0024{srcaddr} \u0024{dstaddr} \u0024{srcport} \u0024{dstport} \u0024{protocol} \u0024{packets} \u0024{bytes} \u0024{windowstart} \u0024{windowend} \u0024{action} \u0024{tcpflags} \u0024{type} \u0024{pkt_srcaddr} \u0024{pkt_dstaddr} \u0024{region} \u0024{sublocation_type} \u0024{sublocation_id}"}"

  tags = {
    Name = "${var.app_name}-flow-log"
  }
}

# S3 bucket for VPC Flow Logs (optional, for long-term storage)
resource "aws_s3_bucket" "flow_logs" {
  bucket_prefix = "${var.app_name}-flow-logs"

  tags = {
    Name = "${var.app_name}-flow-logs-bucket"
  }
}

resource "aws_s3_bucket_versioning" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# VPC Endpoints for AWS Services (reduce data transfer costs)
resource "aws_vpc_endpoint" "s3" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = concat(aws_route_table.private[*].id, [aws_route_table.database.id])

  tags = {
    Name = "${var.app_name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.app_name}-secretsmanager-endpoint"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.app_name}-vpc-endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-vpc-endpoints-sg"
  }
}

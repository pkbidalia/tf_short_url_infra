# IAM Roles and Policies Configuration

# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name_prefix = "${var.app_name}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-ec2-role"
  }
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${var.app_name}-ec2-profile"
  role        = aws_iam_role.ec2_role.name
}

# CloudWatch Agent Policy
resource "aws_iam_role_policy" "cloudwatch_agent" {
  name_prefix = "${var.app_name}-cloudwatch-agent"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# Systems Manager (SSM) Session Manager Policy for EC2
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Logs for EC2
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name_prefix = "${var.app_name}-cloudwatch-logs"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

# S3 Access for Application Logs and Assets
resource "aws_iam_role_policy" "s3_access" {
  name_prefix = "${var.app_name}-s3-access"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.flow_logs.id}",
          "arn:aws:s3:::${aws_s3_bucket.flow_logs.id}/*"
        ]
      }
    ]
  })
}

# RDS Database Access
resource "aws_iam_role_policy" "rds_access" {
  name_prefix = "${var.app_name}-rds-access"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.app_name}/*"
      }
    ]
  })
}

# ElastiCache Access
resource "aws_iam_role_policy" "elasticache_access" {
  name_prefix = "${var.app_name}-elasticache-access"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# EC2 Auto Scaling Service Role
resource "aws_iam_role" "asg_role" {
  name_prefix = "${var.app_name}-asg-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-asg-role"
  }
}

resource "aws_iam_role_policy" "asg_policy" {
  name_prefix = "${var.app_name}-asg-policy"
  role        = aws_iam_role.asg_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Lambda (if using Lambda for URL shortening service)
resource "aws_iam_role" "lambda_role" {
  name_prefix = "${var.app_name}-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-lambda-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_rds_access" {
  name_prefix = "${var.app_name}-lambda-rds-access"
  role        = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# Secrets Manager KMS Key for database credentials
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.app_name}-secrets-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.app_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Policy for CloudTail (audit logging)
resource "aws_iam_role" "cloudtrail_role" {
  name_prefix = "${var.app_name}-cloudtrail-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.app_name}-cloudtrail-role"
  }
}

resource "aws_iam_role_policy" "cloudtrail_policy" {
  name_prefix = "${var.app_name}-cloudtrail-policy"
  role        = aws_iam_role.cloudtrail_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.flow_logs.id}",
          "arn:aws:s3:::${aws_s3_bucket.flow_logs.id}/*"
        ]
      }
    ]
  })
}

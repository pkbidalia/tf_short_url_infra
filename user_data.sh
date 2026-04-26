#!/bin/bash
# User Data Script for URL Shortening Application
# This script runs on EC2 instance launch to configure the application

set -e

# Variables passed from Terraform
APP_NAME="${app_name}"
ENVIRONMENT="${environment}"
RDS_ENDPOINT="${rds_endpoint}"
REDIS_ENDPOINT="${redis_endpoint}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/user_data.log
}

log "Starting user data script for $APP_NAME in $ENVIRONMENT environment"

# Update system packages
log "Updating system packages..."
yum update -y
yum install -y \
    amazon-cloudwatch-agent \
    curl \
    wget \
    git \
    docker \
    mysql \
    redis \
    telnet \
    htop \
    net-tools \
    gcc \
    python3 \
    python3-pip

# Start Docker daemon
log "Starting Docker daemon..."
systemctl start docker
usermod -a -G docker ec2-user

# Install Docker Compose (optional for local testing)
log "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js and npm (for URL shortening service)
log "Installing Node.js and npm..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Python packages for monitoring
log "Installing Python packages..."
pip3 install --upgrade pip
pip3 install boto3 requests

# Create application directory
log "Creating application directory..."
APP_DIR="/opt/${APP_NAME}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create environment file for application
log "Creating environment configuration file..."
cat > "$APP_DIR/.env" << EOF
APP_NAME=${APP_NAME}
ENVIRONMENT=${ENVIRONMENT}
RDS_HOST=$(echo ${RDS_ENDPOINT} | cut -d: -f1)
RDS_PORT=3306
RDS_DATABASE=shorturl
REDIS_HOST=${REDIS_ENDPOINT}
REDIS_PORT=6379
NODE_ENV=${ENVIRONMENT}
LOG_LEVEL=info
API_PORT=8080
HEALTH_CHECK_PATH=/health
EOF

log "Environment file created at $APP_DIR/.env"

# Create a basic health check endpoint service
log "Creating health check service..."
cat > "$APP_DIR/health_check.js" << 'HEALTHCHECK_EOF'
const http = require('http');
const os = require('os');
const fs = require('fs');

const server = http.createServer((req, res) => {
  if (req.url === '/health' && req.method === 'GET') {
    const healthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      hostname: os.hostname(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      environment: process.env.ENVIRONMENT || 'unknown'
    };
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(healthStatus));
  } else if (req.url === '/' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('URL Shortening Service - Healthy\n');
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found\n');
  }
});

const port = process.env.API_PORT || 8080;
server.listen(port, () => {
  console.log(`Health check service running on port ${port}`);
});
HEALTHCHECK_EOF

log "Health check service created"

# Create systemd service for application
log "Creating systemd service..."
cat > /etc/systemd/system/${APP_NAME}.service << EOF
[Unit]
Description=${APP_NAME} Application Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=/usr/bin/node ${APP_DIR}/health_check.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${APP_NAME}
systemctl start ${APP_NAME}

log "Application service started"

# Configure CloudWatch Agent
log "Configuring CloudWatch Agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWCONFIG_EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/application/${APP_NAME}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/user_data.log",
            "log_group_name": "/aws/application/${APP_NAME}",
            "log_stream_name": "{instance_id}-user-data"
          },
          {
            "file_path": "/var/log/journal/*",
            "log_group_name": "/aws/application/${APP_NAME}",
            "log_stream_name": "{instance_id}-systemd"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${APP_NAME}-metrics",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_time_guest"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
CWCONFIG_EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

log "CloudWatch Agent configured"

# Test database connectivity
log "Testing RDS connectivity..."
if command -v mysql &> /dev/null; then
    mysql -h $(echo ${RDS_ENDPOINT} | cut -d: -f1) -u admin --password='YourSecurePassword123!' -e "SELECT 1" || log "WARNING: Could not connect to RDS"
fi

# Test Redis connectivity
log "Testing Redis connectivity..."
if command -v redis-cli &> /dev/null; then
    redis-cli -h ${REDIS_ENDPOINT} ping || log "WARNING: Could not connect to Redis"
fi

# Create application performance monitoring script
log "Creating performance monitoring script..."
cat > "$APP_DIR/monitor.py" << 'MONITOR_EOF'
#!/usr/bin/env python3
import boto3
import os
import json
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')
namespace = os.environ.get('APP_NAME', 'short-url') + '-custom'

def push_custom_metric(metric_name, value, unit='Count'):
    """Push a custom metric to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        print(f"Pushed metric: {metric_name} = {value} {unit}")
    except Exception as e:
        print(f"Error pushing metric {metric_name}: {str(e)}")

if __name__ == '__main__':
    # Example: Push a custom metric
    push_custom_metric('ApplicationHealth', 1.0)
MONITOR_EOF

chmod +x "$APP_DIR/monitor.py"

# Schedule monitoring script to run every 5 minutes
log "Scheduling monitoring script..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/python3 $APP_DIR/monitor.py") | crontab -

# Final setup confirmation
log "Creating application info file..."
cat > "$APP_DIR/instance_info.json" << EOF
{
  "app_name": "${APP_NAME}",
  "environment": "${ENVIRONMENT}",
  "instance_id": "$(ec2-metadata --instance-id | cut -d' ' -f2)",
  "availability_zone": "$(ec2-metadata --availability-zone | cut -d' ' -f2)",
  "launched_at": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "rds_endpoint": "${RDS_ENDPOINT}",
  "redis_endpoint": "${REDIS_ENDPOINT}"
}
EOF

log "User data script completed successfully!"
log "=============================================\n"

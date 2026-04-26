# Auto Scaling Group (ASG) and Launch Template Configuration

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template for EC2 instances
resource "aws_launch_template" "app" {
  name_prefix   = "${var.app_name}-lt"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Enable detailed monitoring
  monitoring {
    enabled = true
  }

  # Root volume configuration
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # CloudWatch agent and application setup
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name        = var.app_name
    environment     = var.environment
    rds_endpoint    = aws_db_instance.main.endpoint
    redis_endpoint  = aws_elasticache_replication_group.main.primary_endpoint_address
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.app_name}-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.app_name}-volume"
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                      = "${var.app_name}-asg"
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  default_cooldown          = 300
  termination_policies      = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 90
      instance_warmup_seconds = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.app_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_lb.main,
    aws_db_instance.main,
    aws_elasticache_replication_group.main
  ]
}

# Target Tracking Scaling Policy (Scale based on CPU)
resource "aws_autoscaling_policy" "cpu_scaling_up" {
  name                   = "${var.app_name}-cpu-scaling-up"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Target Tracking Scaling Policy (Scale based on ALB Requests)
resource "aws_autoscaling_policy" "alb_request_count_scaling" {
  name                   = "${var.app_name}-alb-request-count-scaling"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value = 1000.0
  }
}

# Scheduled Action - Scale up during business hours (optional)
resource "aws_autoscaling_schedule" "scale_up_morning" {
  scheduled_action_name  = "${var.app_name}-scale-up-morning"
  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.max_size / 2
  recurrence             = "0 8 * * MON-FRI"  # 8 AM on weekdays
  time_zone              = "UTC"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# Scheduled Action - Scale down during off-hours (optional)
resource "aws_autoscaling_schedule" "scale_down_evening" {
  scheduled_action_name  = "${var.app_name}-scale-down-evening"
  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.min_size
  recurrence             = "0 18 * * MON-FRI"  # 6 PM on weekdays
  time_zone              = "UTC"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# CloudWatch Alarms for ASG

# High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "asg_high_cpu" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-asg-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Alert when average CPU exceeds ${var.cpu_alarm_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Failed to Launch
resource "aws_cloudwatch_metric_alarm" "asg_failed_to_launch" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-asg-failed-to-launch"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "GroupFailedLaunchInstances"
  namespace           = "AWS/AutoScaling"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when instances fail to launch"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# Desired Capacity vs Group In Service
resource "aws_cloudwatch_metric_alarm" "asg_groupinserviceinstances" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name_prefix   = "${var.app_name}-asg-in-service"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = "300"
  statistic           = "Average"
  threshold           = var.min_size
  alarm_description   = "Alert when in-service instances fall below minimum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = var.alarm_actions_enabled && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

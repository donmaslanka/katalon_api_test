# Data source to get the latest AMI (if not explicitly provided)
data "aws_ami" "jenkins" {
  count       = var.jenkins_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.jenkins_ami_name_filter]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security Group for Jenkins Server
resource "aws_security_group" "jenkins" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-"
  description = "Security group for Jenkins server"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # Jenkins web interface
  ingress {
    description = "Jenkins web interface"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.jenkins_web_allowed_cidrs
  }

  # HTTPS for Jenkins (if using reverse proxy)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.jenkins_web_allowed_cidrs
  }

  # Outbound internet access
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for Jenkins (optional but recommended)
resource "aws_eip" "jenkins" {
  count  = var.allocate_elastic_ip ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-eip"
  }
}

# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami           = var.jenkins_ami_id != "" ? var.jenkins_ami_id : data.aws_ami.jenkins[0].id
  instance_type = var.instance_type
  key_name      = var.key_name

  # Network configuration
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = var.associate_public_ip

  # IAM role for ECS access
  iam_instance_profile = var.jenkins_instance_profile_name

  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-${var.environment}-jenkins-root"
    }
  }

  # Additional EBS volume for Jenkins data (optional)
  dynamic "ebs_block_device" {
    for_each = var.create_data_volume ? [1] : []
    content {
      device_name           = "/dev/sdf"
      volume_type           = var.data_volume_type
      volume_size           = var.data_volume_size
      delete_on_termination = false
      encrypted             = true

      tags = {
        Name = "${var.project_name}-${var.environment}-jenkins-data"
      }
    }
  }

  # User data script (optional)
  user_data = var.user_data_script != "" ? var.user_data_script : templatefile("${path.module}/user-data.sh", {
    ecs_cluster_name       = var.ecs_cluster_name
    task_definition_family = var.task_definition_family
    aws_region             = var.aws_region
    s3_results_bucket      = var.s3_results_bucket
  })

  # Enable detailed monitoring
  monitoring = var.enable_detailed_monitoring

  # Metadata options for IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins"
    Environment = var.environment
    Role        = "Jenkins"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [
      ami,  # Prevent recreation when AMI is updated
    ]
  }

  depends_on = [aws_security_group.jenkins]
}

# Associate Elastic IP with Jenkins instance
resource "aws_eip_association" "jenkins" {
  count         = var.allocate_elastic_ip ? 1 : 0
  instance_id   = aws_instance.jenkins.id
  allocation_id = aws_eip.jenkins[0].id
}

# CloudWatch Log Group for Jenkins logs
resource "aws_cloudwatch_log_group" "jenkins" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/${var.project_name}-${var.environment}-jenkins"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-logs"
  }
}

# CloudWatch Alarms for Jenkins
resource "aws_cloudwatch_metric_alarm" "jenkins_cpu" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-jenkins-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors Jenkins EC2 CPU utilization"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = aws_instance.jenkins.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "jenkins_status_check" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-jenkins-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors Jenkins EC2 status checks"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    InstanceId = aws_instance.jenkins.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-status-alarm"
  }
}

# Route53 DNS record for Jenkins (optional)
resource "aws_route53_record" "jenkins" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.jenkins_hostname
  type    = "A"
  ttl     = 300
  records = var.allocate_elastic_ip ? [aws_eip.jenkins[0].public_ip] : [aws_instance.jenkins.public_ip]

  depends_on = [aws_instance.jenkins]
}

# Backup plan for Jenkins (optional)
resource "aws_backup_selection" "jenkins" {
  count        = var.enable_backup ? 1 : 0
  name         = "${var.project_name}-${var.environment}-jenkins-backup"
  iam_role_arn = var.backup_iam_role_arn
  plan_id      = var.backup_plan_id

  resources = [
    aws_instance.jenkins.arn
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = var.environment
    }
  }
}

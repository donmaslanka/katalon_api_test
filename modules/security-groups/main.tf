# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-tasks-"
  description = "Security group for ECS Katalon tasks"
  vpc_id      = var.vpc_id

  # Allow outbound HTTPS for pulling images and accessing websites
  egress {
    description = "HTTPS to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTP for accessing websites
  egress {
    description = "HTTP to internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow DNS queries
  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Optional: Security group for Jenkins to trigger ECS tasks
resource "aws_security_group" "jenkins_to_ecs" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-to-ecs-"
  description = "Allow Jenkins server to trigger ECS tasks"
  vpc_id      = var.vpc_id

  # Jenkins doesn't need direct ingress to ECS tasks
  # Communication happens through AWS API

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-to-ecs-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security group rule to allow Jenkins IP to access AWS services
resource "aws_security_group_rule" "jenkins_to_aws_api" {
  count             = var.jenkins_server_ip != "" ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.jenkins_server_ip]
  security_group_id = aws_security_group.jenkins_to_ecs.id
  description       = "Allow Jenkins server to access AWS API"
}

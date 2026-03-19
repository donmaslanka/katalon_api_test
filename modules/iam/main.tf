# ECS Task Execution Role
# This role is used by ECS to pull container images and write logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for ECR access (for private ECR images)
resource "aws_iam_role_policy" "ecs_task_execution_ecr_policy" {
  name_prefix = "${var.project_name}-${var.environment}-ecr-"
  role        = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Role
# This role is used by the container itself during runtime
resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-role"
  }
}

# Policy for Katalon tests to store results in S3 (optional)
resource "aws_iam_role_policy" "katalon_s3_policy" {
  name_prefix = "${var.project_name}-${var.environment}-s3-"
  role        = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-katalon-results/*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-katalon-results"
        ]
      }
    ]
  })
}

# IAM Role for Jenkins to trigger ECS tasks
resource "aws_iam_role" "jenkins_ecs_role" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-ecs-"

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
    Name = "${var.project_name}-${var.environment}-jenkins-ecs-role"
  }
}

# Policy for Jenkins to run ECS tasks
resource "aws_iam_role_policy" "jenkins_ecs_policy" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-"
  role        = aws_iam_role.jenkins_ecs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile for Jenkins EC2
resource "aws_iam_instance_profile" "jenkins_profile" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-"
  role        = aws_iam_role.jenkins_ecs_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-instance-profile"
  }
}

# ============================================================
# main.tf
# ECS/Fargate resources for Katalon test execution
# Revised to support Jenkins -> ECS -> Katalon runner pattern
# ============================================================

# Data source for current AWS region
data "aws_region" "current" {}

# ------------------------------------------------------------
# CloudWatch Log Group for ECS
# ------------------------------------------------------------
resource "aws_cloudwatch_log_group" "katalon" {
  name              = "/ecs/${var.project_name}-${var.environment}-katalon"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-katalon-logs"
  }
}

# ------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-cluster"
  }
}

# ------------------------------------------------------------
# ECS Cluster Capacity Providers
# ------------------------------------------------------------
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    "FARGATE",
    "FARGATE_SPOT"
  ]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ------------------------------------------------------------
# Katalon Task Definition
#
# Important:
# - container name is "katalon-container" to match Jenkinsfile
# - image should be a real Katalon runner image, not jenkins-agent
# - Jenkins passes runtime CLI args via ECS container overrides
# ------------------------------------------------------------
resource "aws_ecs_task_definition" "katalon" {
  family                   = "${var.project_name}-${var.environment}-katalon"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.katalon_cpu
  memory                   = var.katalon_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "katalon-container"
      image     = var.katalon_image
      essential = true

      # Let the image entrypoint run Katalon directly.
      # Jenkins supplies command overrides at runtime.

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.katalon.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      linuxParameters = {
        initProcessEnabled = true
      }

      mountPoints = []
      volumesFrom = []

      environment  = []
      portMappings = []
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-katalon-task"
  }
}

# ------------------------------------------------------------
# Optional ECS Service
#
# Keep desired_count = 0 if you only want on-demand run-task usage
# from Jenkins. This service is optional and only created when
# katalon_desired_count > 0.
# ------------------------------------------------------------
resource "aws_ecs_service" "katalon" {
  count           = var.katalon_desired_count > 0 ? 1 : 0
  name            = "${var.project_name}-${var.environment}-katalon-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.katalon.arn
  desired_count   = var.katalon_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_task_security_group_id]
    assign_public_ip = false
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-katalon-service"
  }
}

# ------------------------------------------------------------
# S3 Bucket for Test Results
# ------------------------------------------------------------
resource "aws_s3_bucket" "katalon_results" {
  bucket_prefix = "${var.project_name}-${var.environment}-katalon-results-"

  tags = {
    Name = "${var.project_name}-${var.environment}-katalon-results"
  }
}

# ------------------------------------------------------------
# S3 Bucket Versioning
# ------------------------------------------------------------
resource "aws_s3_bucket_versioning" "katalon_results" {
  bucket = aws_s3_bucket.katalon_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ------------------------------------------------------------
# S3 Bucket Lifecycle Policy
# ------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "katalon_results" {
  bucket = aws_s3_bucket.katalon_results.id

  rule {
    id     = "delete-old-results"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ------------------------------------------------------------
# S3 Bucket Encryption
# ------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "katalon_results" {
  bucket = aws_s3_bucket.katalon_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------------------------------
# Block Public Access to S3 Bucket
# ------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "katalon_results" {
  bucket = aws_s3_bucket.katalon_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

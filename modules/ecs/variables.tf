variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_task_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  type        = string
}

variable "katalon_image" {
  description = "Katalon Docker image"
  type        = string
  default     = "katalonstudio/katalon:latest"
}

variable "katalon_cpu" {
  description = "CPU units for Katalon task"
  type        = number
  default     = 2048
}

variable "katalon_memory" {
  description = "Memory for Katalon task in MB"
  type        = number
  default     = 4096
}

variable "katalon_desired_count" {
  description = "Desired number of Katalon tasks"
  type        = number
  default     = 0
}

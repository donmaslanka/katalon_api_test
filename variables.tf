variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "318798562215"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "katalon-testing"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# Jenkins Configuration
variable "jenkins_server_ip" {
  description = "IP address of existing Jenkins EC2 server in CIDR format (e.g., 10.0.5.100/32). Only needed if NOT creating new Jenkins server."
  type        = string
  default     = ""
}

# ECS/Katalon Configuration
variable "katalon_image" {
  description = "Katalon Docker image"
  type        = string
  default     = "katalonstudio/katalon:latest"
}

variable "katalon_cpu" {
  description = "CPU units for Katalon task (1024 = 1 vCPU)"
  type        = number
  default     = 2048
}

variable "katalon_memory" {
  description = "Memory for Katalon task in MB"
  type        = number
  default     = 4096
}

variable "katalon_desired_count" {
  description = "Desired number of Katalon tasks (set to 0 for on-demand execution)"
  type        = number
  default     = 0
}

# Jenkins Configuration
variable "create_jenkins_server" {
  description = "Create Jenkins server from AMI"
  type        = bool
  default     = false
}

variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins server (client's Jenkins image)"
  type        = string
  default     = ""
}

variable "jenkins_ami_name_filter" {
  description = "Name filter to find Jenkins AMI if jenkins_ami_id is not provided"
  type        = string
  default     = "jenkins-*"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_key_name" {
  description = "SSH key pair name for Jenkins instance"
  type        = string
  default     = ""
}

variable "jenkins_ssh_allowed_cidrs" {
  description = "List of CIDR blocks allowed to SSH to Jenkins"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "jenkins_web_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access Jenkins web interface"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "jenkins_allocate_elastic_ip" {
  description = "Allocate and associate an Elastic IP with Jenkins instance"
  type        = bool
  default     = true
}

variable "jenkins_root_volume_size" {
  description = "Root volume size in GB for Jenkins"
  type        = number
  default     = 50
}

variable "jenkins_create_data_volume" {
  description = "Create additional EBS volume for Jenkins data"
  type        = bool
  default     = false
}

variable "jenkins_data_volume_size" {
  description = "Data volume size in GB for Jenkins"
  type        = number
  default     = 100
}

variable "jenkins_enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs for Jenkins"
  type        = bool
  default     = true
}

variable "jenkins_enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Jenkins"
  type        = bool
  default     = true
}

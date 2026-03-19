variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Jenkins will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Jenkins instance (use public subnet for internet access)"
  type        = string
}

# AMI Configuration
variable "jenkins_ami_id" {
  description = "AMI ID for Jenkins server (if empty, will search for latest based on name filter)"
  type        = string
  default     = ""
}

variable "jenkins_ami_name_filter" {
  description = "Name filter to find Jenkins AMI if jenkins_ami_id is not provided"
  type        = string
  default     = "jenkins-*"
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name for Jenkins instance"
  type        = string
}

variable "associate_public_ip" {
  description = "Associate a public IP address with the Jenkins instance"
  type        = bool
  default     = true
}

# IAM Configuration
variable "jenkins_instance_profile_name" {
  description = "IAM instance profile name for Jenkins (to access ECS)"
  type        = string
}

# Storage Configuration
variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "create_data_volume" {
  description = "Create additional EBS volume for Jenkins data"
  type        = bool
  default     = false
}

variable "data_volume_type" {
  description = "Data volume type"
  type        = string
  default     = "gp3"
}

variable "data_volume_size" {
  description = "Data volume size in GB"
  type        = number
  default     = 100
}

# Network Security
variable "ssh_allowed_cidrs" {
  description = "List of CIDR blocks allowed to SSH to Jenkins"
  type        = list(string)
  default     = []
}

variable "jenkins_web_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access Jenkins web interface"
  type        = list(string)
  default     = []
}

# Elastic IP
variable "allocate_elastic_ip" {
  description = "Allocate and associate an Elastic IP with Jenkins instance"
  type        = bool
  default     = true
}

# Monitoring
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs for Jenkins"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Jenkins"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarm"
  type        = number
  default     = 80
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

# DNS Configuration
variable "create_dns_record" {
  description = "Create Route53 DNS record for Jenkins"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "jenkins_hostname" {
  description = "Hostname for Jenkins (e.g., jenkins.example.com)"
  type        = string
  default     = ""
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable AWS Backup for Jenkins instance"
  type        = bool
  default     = false
}

variable "backup_plan_id" {
  description = "AWS Backup plan ID"
  type        = string
  default     = ""
}

variable "backup_iam_role_arn" {
  description = "IAM role ARN for AWS Backup"
  type        = string
  default     = ""
}

# User Data
variable "user_data_script" {
  description = "Custom user data script (if empty, uses default template)"
  type        = string
  default     = ""
}

# ECS Integration (for user data template)
variable "ecs_cluster_name" {
  description = "ECS cluster name for Jenkins integration"
  type        = string
  default     = ""
}

variable "task_definition_family" {
  description = "ECS task definition family"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "s3_results_bucket" {
  description = "S3 bucket for test results"
  type        = string
  default     = ""
}

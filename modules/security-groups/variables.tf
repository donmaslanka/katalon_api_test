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

variable "jenkins_server_ip" {
  description = "IP address of Jenkins server in CIDR format (only needed if using existing Jenkins, not when creating new one)"
  type        = string
  default     = ""
}

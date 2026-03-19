output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "katalon_task_definition_arn" {
  description = "Katalon task definition ARN"
  value       = module.ecs.katalon_task_definition_arn
}

output "katalon_task_definition_family" {
  description = "Katalon task definition family"
  value       = module.ecs.katalon_task_definition_family
}

output "ecs_task_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = module.security_groups.ecs_task_security_group_id
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = module.iam.ecs_task_role_arn
}

output "jenkins_integration_info" {
  description = "Information for Jenkins integration"
  value = {
    cluster_name            = module.ecs.cluster_name
    task_definition         = module.ecs.katalon_task_definition_family
    subnet_ids              = module.vpc.private_subnet_ids
    security_group_id       = module.security_groups.ecs_task_security_group_id
    task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  }
}

# Jenkins Server Outputs (when created)
output "jenkins_instance_id" {
  description = "Jenkins instance ID"
  value       = var.create_jenkins_server ? module.jenkins[0].instance_id : null
}

output "jenkins_public_ip" {
  description = "Jenkins public IP address"
  value       = var.create_jenkins_server ? module.jenkins[0].elastic_ip : null
}

output "jenkins_private_ip" {
  description = "Jenkins private IP address"
  value       = var.create_jenkins_server ? module.jenkins[0].private_ip : null
}

output "jenkins_url" {
  description = "Jenkins web interface URL"
  value       = var.create_jenkins_server ? module.jenkins[0].jenkins_url : null
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = var.create_jenkins_server ? module.jenkins[0].ssh_command : null
}

output "jenkins_security_group_id" {
  description = "Jenkins security group ID"
  value       = var.create_jenkins_server ? module.jenkins[0].security_group_id : null
}

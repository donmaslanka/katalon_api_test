output "ecs_task_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "jenkins_security_group_id" {
  description = "Security group ID for Jenkins to ECS communication"
  value       = aws_security_group.jenkins_to_ecs.id
}

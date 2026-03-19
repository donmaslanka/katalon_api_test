output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

output "jenkins_ecs_role_arn" {
  description = "ARN of Jenkins ECS role"
  value       = aws_iam_role.jenkins_ecs_role.arn
}

output "jenkins_instance_profile_name" {
  description = "Name of Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins_profile.name
}

output "jenkins_instance_profile_arn" {
  description = "ARN of Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins_profile.arn
}

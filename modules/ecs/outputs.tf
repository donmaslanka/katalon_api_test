output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "katalon_task_definition_arn" {
  description = "Katalon task definition ARN"
  value       = aws_ecs_task_definition.katalon.arn
}

output "katalon_task_definition_family" {
  description = "Katalon task definition family"
  value       = aws_ecs_task_definition.katalon.family
}

output "katalon_log_group_name" {
  description = "CloudWatch log group name for Katalon tasks"
  value       = aws_cloudwatch_log_group.katalon.name
}

output "s3_results_bucket_name" {
  description = "S3 bucket name for test results"
  value       = aws_s3_bucket.katalon_results.id
}

output "s3_results_bucket_arn" {
  description = "S3 bucket ARN for test results"
  value       = aws_s3_bucket.katalon_results.arn
}

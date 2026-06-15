output "task_role_arn" {
  description = "IAM role ARN for ECS tasks"
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "IAM role name for ECS tasks"
  value       = aws_iam_role.task.name
}

output "db_password_secret_arn" {
  description = "ARN of the generated database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

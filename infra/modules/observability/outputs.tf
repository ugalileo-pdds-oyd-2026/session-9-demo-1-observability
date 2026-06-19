output "log_group_name" {
  description = "CloudWatch log group name for the application. Inject this into the ECS task definition as LOG_GROUP_NAME so watchtower can locate the log group."
  value       = aws_cloudwatch_log_group.app.name
}

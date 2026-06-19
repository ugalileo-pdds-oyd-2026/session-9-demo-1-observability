output "log_group_name" {
  description = "CloudWatch log group name for the application. Inject this into the ECS task definition as LOG_GROUP_NAME so watchtower can locate the log group."
  value       = aws_cloudwatch_log_group.app.name
}
output "alarm_topic_arn" {
  description = "SNS topic ARN used by all CloudWatch alarms"
  value       = aws_sns_topic.alarms.arn
}

output "http_5xx_alarm_name" {
  description = "Name of the HTTP 5xx CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.http_5xx.alarm_name
}

output "latency_alarm_name" {
  description = "Name of the latency CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.latency.alarm_name
}

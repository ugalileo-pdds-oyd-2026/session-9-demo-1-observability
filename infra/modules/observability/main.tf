resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.environment}/${var.app_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-${var.app_name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${var.environment}-${var.app_name}-http-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.http_5xx_threshold
  alarm_description   = "More than ${var.http_5xx_threshold} HTTP 5xx responses in 60 seconds"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "latency" {
  alarm_name          = "${var.environment}-${var.app_name}-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p90"
  threshold           = var.latency_threshold_seconds
  alarm_description   = "p90 target response time exceeded ${var.latency_threshold_seconds}s for 3 consecutive minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

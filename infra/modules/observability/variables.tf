variable "app_name" {
  description = "Application name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the observability resources are created"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log events. Setting this avoids unbounded storage costs (CloudWatch charges per GB stored)."
  type        = number
  default     = 30
}

variable "notification_email" {
  description = "Email address that receives SNS alarm notifications. The subscriber must confirm the subscription via the AWS confirmation email."
  type        = string
}

variable "http_5xx_threshold" {
  description = "Number of HTTP 5xx responses per 60-second period that triggers the alarm"
  type        = number
  default     = 5
}

variable "latency_threshold_seconds" {
  description = "p90 target response time in seconds above which the latency alarm fires"
  type        = number
  default     = 1.0
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix in the format 'app/<name>/<hash>' as returned by aws_lb.arn_suffix. Used as the LoadBalancer dimension in CloudWatch metric alarms."
  type        = string
}

variable "estimated_charges_threshold" {
  description = "USD amount above which the EstimatedCharges CloudWatch alarm fires. Set to a value your account has already exceeded so the alarm is visible during the demo."
  type        = number
  default     = 10
}

variable "monthly_budget_usd" {
  description = "Monthly AWS cost ceiling in USD. An alert fires at 80% of this value. Note: AWS Budgets reads processed billing data with up to 24-hour delay — not suitable for real-time alerting."
  type        = number
  default     = 50
}

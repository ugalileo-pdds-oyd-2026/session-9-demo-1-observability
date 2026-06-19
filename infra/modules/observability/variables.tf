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

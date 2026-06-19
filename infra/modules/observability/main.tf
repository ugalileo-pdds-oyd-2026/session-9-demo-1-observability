resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.environment}/${var.app_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

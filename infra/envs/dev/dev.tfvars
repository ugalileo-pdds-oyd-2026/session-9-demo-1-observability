aws_region      = "us-west-2"
app_name        = "session9-demo1"
environment     = "dev"
vpc_cidr        = "10.0.0.0/16"
container_image = "439426070073.dkr.ecr.us-west-2.amazonaws.com/dev-session9-demo1:latest"
container_port  = 5000
task_cpu        = 256
task_memory     = 512
desired_count   = 1

# Observability
log_retention_days          = 30
notification_email          = "augusto.alvarez@galileo.edu"
http_5xx_threshold          = 5
latency_threshold_seconds   = 1.0
estimated_charges_threshold = 10
monthly_budget_usd          = 50

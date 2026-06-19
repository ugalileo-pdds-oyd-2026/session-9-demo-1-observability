module "networking" {
  source = "./modules/networking"

  app_name    = var.app_name
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "secrets" {
  source = "./modules/secrets"

  app_name    = var.app_name
  environment = var.environment
}

module "observability" {
  source = "./modules/observability"

  app_name                    = var.app_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  log_retention_days          = var.log_retention_days
  notification_email          = var.notification_email
  http_5xx_threshold          = var.http_5xx_threshold
  latency_threshold_seconds   = var.latency_threshold_seconds
  alb_arn_suffix              = module.compute.alb_arn_suffix
}

module "compute" {
  source = "./modules/compute"

  app_name        = var.app_name
  environment     = var.environment
  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnet_ids
  private_subnets = module.networking.private_subnet_ids
  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory
  desired_count   = var.desired_count
  task_role_arn   = module.secrets.task_role_arn
  log_group_name  = module.observability.log_group_name
}

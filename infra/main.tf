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
}

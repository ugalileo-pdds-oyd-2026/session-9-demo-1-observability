variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the networking module"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "container_image" {
  description = "Docker image URI"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "task_cpu" {
  description = "ECS task CPU units"
  type        = number
}

variable "task_memory" {
  description = "ECS task memory in MiB"
  type        = number
}

variable "desired_count" {
  description = "Number of task replicas"
  type        = number
}

variable "task_role_arn" {
  description = "IAM role ARN for the ECS task"
  type        = string
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used in CloudWatch metric dimensions"
  value       = module.compute.alb_arn_suffix
}

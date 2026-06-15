variable "aws_region" {
  description = "Region for the state bucket and lock table"
  type        = string
  default     = "us-west-2"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform remote state"
  type        = string
}


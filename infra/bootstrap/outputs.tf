output "state_bucket_name" {
  description = "Name of the created state bucket — paste into ../versions.tf backend block"
  value       = aws_s3_bucket.state.id
}


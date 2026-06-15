output "state_bucket_name" {
  description = "Name of the created state bucket — paste into ../versions.tf backend block"
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Name of the created lock table — paste into ../versions.tf backend block"
  value       = aws_dynamodb_table.lock.name
}

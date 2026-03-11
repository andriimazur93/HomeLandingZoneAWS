output "terraform_state_s3_bucket_name" {
  description = "The name of the S3 bucket used to store Terraform state for the landing zone."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_dynamodb_table_name" {
  description = "The name of the DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.terraform_state_locks.name
}

output "aws_region" {
  description = "The AWS region where the backend infrastructure is deployed."
  value       = var.aws_region
}

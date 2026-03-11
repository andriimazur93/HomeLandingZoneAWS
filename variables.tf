variable "aws_region" {
  description = "AWS region to deploy resources (e.g., us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email address to receive AWS budget threshold alerts."
  type        = string
}

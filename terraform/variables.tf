variable "aws_region" {
  default = "us-east-1"
}

variable "db_password" {
  description = "RDS Password"
  type        = string
  sensitive   = true
}
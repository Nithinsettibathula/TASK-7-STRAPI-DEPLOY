output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.strapi.repository_url
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.strapi_db.endpoint
}
output "db_endpoint" {
  value       = aws_db_instance.main.address
  description = "RDS connection endpoint (hostname only)"
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "secrets_manager_arn" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "ARN of the secret holding DB credentials — referenced by the ECS task definition"
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}

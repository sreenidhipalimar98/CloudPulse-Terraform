output "repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "Full URL to push/pull images, e.g. <account>.dkr.ecr.<region>.amazonaws.com/cloudpulse-dev-api"
}

output "repository_name" {
  value = aws_ecr_repository.app.name
}

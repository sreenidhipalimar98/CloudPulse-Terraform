output "api_url" {
  value       = "http://${module.ecs.alb_dns_name}"
  description = "Public URL of the CloudPulse API"
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "Push your Docker images here"
}

output "ecs_cluster_name" {
  value = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.ecs.ecs_service_name
}

output "db_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "github_actions_deploy_role_arn" {
  value       = module.iam.github_actions_deploy_role_arn
  description = "Add this as AWS_DEPLOY_ROLE_ARN in your GitHub repo secrets"
}

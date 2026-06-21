output "ecs_execution_role_arn" {
  value       = aws_iam_role.ecs_execution_role.arn
  description = "ARN of the ECS task execution role (pulls image, fetches secrets)"
}

output "ecs_task_role_arn" {
  value       = aws_iam_role.ecs_task_role.arn
  description = "ARN of the ECS task role (used by the running app to call AWS APIs)"
}

output "github_actions_deploy_role_arn" {
  value       = aws_iam_role.github_actions_deploy.arn
  description = "ARN GitHub Actions assumes via OIDC to deploy — put this in your GitHub repo secrets"
}

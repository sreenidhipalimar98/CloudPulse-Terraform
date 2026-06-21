output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Public DNS name of the load balancer — this is your API's URL"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "ecs_security_group_id" {
  value       = var.ecs_security_group_id
  description = "Security group of the ECS tasks (passed through from input)"
}

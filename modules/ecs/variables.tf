variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "ecr_repository_url" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "secrets_manager_arn" {
  type = string
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID for the ALB, created at environment level"
}

variable "ecs_security_group_id" {
  type        = string
  description = "Security group ID for ECS tasks, created at environment level"
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "task_cpu" {
  type    = number
  default = 256 # 0.25 vCPU — small and cheap, fine for a portfolio project
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

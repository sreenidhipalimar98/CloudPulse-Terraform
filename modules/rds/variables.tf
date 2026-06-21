variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "database_subnet_ids" {
  type        = list(string)
  description = "Isolated subnet IDs to place RDS in"
}

variable "ecs_security_group_id" {
  type        = string
  description = "Security group of the ECS tasks — only this SG is allowed to reach the database"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro" # cheapest viable instance — fine for a portfolio project
}

variable "db_name" {
  type    = string
  default = "cloudpulse"
}

variable "db_username" {
  type    = string
  default = "cloudpulse_admin"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

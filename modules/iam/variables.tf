variable "project_name" {
  description = "Project name, used in resource naming and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials, so the task execution role can read it"
  type        = string
}

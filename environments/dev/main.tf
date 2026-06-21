# This file composes all the modules together for the dev environment.
#
# Dependency ordering note: ECS tasks need to reach RDS, and RDS's
# security group needs to know the ECS tasks' security group ID to
# allow it in. To avoid a circular module dependency (ECS module
# needing RDS's secret ARN, RDS module needing ECS's security group),
# the ECS tasks security group is created HERE, once, and passed as
# an input to both the ecs and rds modules. This is a common real
# pattern for breaking circular references between modules.

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
}

# --- Shared security groups (created at environment level to avoid
#     a circular dependency between the ecs and rds modules) ---

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow inbound HTTP from the internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  description = "Allow inbound only from the ALB, on the container port"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "../../modules/rds"

  project_name           = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  database_subnet_ids     = module.vpc.database_subnet_ids
  ecs_security_group_id   = aws_security_group.ecs_tasks.id
}

module "iam" {
  source = "../../modules/iam"

  project_name         = var.project_name
  environment          = var.environment
  secrets_manager_arn  = module.rds.secrets_manager_arn
}

module "ecs" {
  source = "../../modules/ecs"

  project_name            = var.project_name
  environment              = var.environment
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  public_subnet_ids        = module.vpc.public_subnet_ids
  ecr_repository_url       = module.ecr.repository_url
  ecs_execution_role_arn   = module.iam.ecs_execution_role_arn
  ecs_task_role_arn        = module.iam.ecs_task_role_arn
  secrets_manager_arn      = module.rds.secrets_manager_arn
  alb_security_group_id    = aws_security_group.alb.id
  ecs_security_group_id    = aws_security_group.ecs_tasks.id
  github_token_secret_arn  = "arn:aws:secretsmanager:ap-south-1:995547019839:secret:cloudpulse-dev-github-token-ZeWXMQ"
}

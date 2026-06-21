# ECS module — runs the CloudPulse API as a Fargate service behind
# an Application Load Balancer.
#
# Traffic path:  Internet -> ALB (public subnets) -> ECS tasks (private subnets)
#
# Fargate (not EC2 launch type) is used deliberately: no servers to
# patch or manage, you pay per task, and it's the right choice for a
# single small API service like this one. (Worth explaining this
# tradeoff out loud in an interview — shows you can justify a choice,
# not just use a tool by default.)

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # gives you CPU/memory/network metrics in CloudWatch automatically
  }
}

# --- Security groups ---
# Note: the ALB and ECS task security groups are created at the
# environment level (environments/dev/main.tf) and passed in here.
# This avoids a circular dependency: RDS needs to know the ECS
# tasks' security group ID, and ECS needs RDS's secret ARN — they
# can't both live inside modules that depend on each other.

# --- Load balancer ---

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- CloudWatch log group for container logs ---

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 14
}

# --- Task definition ---
# Defines the container: image, CPU/memory, port mapping, and how
# secrets are injected. Note the "secrets" block (not "environment")
# for the DB connection string — ECS resolves this from Secrets
# Manager at task start, so the value never appears in the task
# definition itself, in the console, or in Terraform state.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${var.environment}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn             = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "cloudpulse-api"
      image     = "${var.ecr_repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      secrets = [
        {
          name      = "DATABASE_CREDENTIALS"
          valueFrom = var.secrets_manager_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])
}

data "aws_region" "current" {}

# --- Service ---
# desired_count tasks, spread across private subnets, registered
# behind the ALB target group. Rolling deployment by default —
# ECS starts new tasks and waits for them to pass health checks
# before draining old ones.
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_security_group_id]
    # no public IP — tasks live in private subnets, reachable only via the ALB
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "cloudpulse-api"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_lb_listener.http]
}

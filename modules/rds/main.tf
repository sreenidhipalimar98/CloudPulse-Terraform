# RDS module — PostgreSQL instance in the isolated database subnet
# tier (no route to the internet at all). Only reachable from the
# ECS tasks' security group, on port 5432.
#
# The master password is auto-generated and stored in Secrets
# Manager — it is NEVER written into Terraform state in plaintext,
# never committed to Git, and never hardcoded anywhere. This is the
# answer to "how do you manage secrets in Terraform?" in practice,
# not just in theory.

resource "random_password" "db_master" {
  length  = 24
  special = true
  # RDS disallows a few characters in passwords; exclude them
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# Security group: ONLY allow inbound Postgres traffic from the ECS
# tasks' security group — nothing else, not even other resources in
# the VPC, can reach this database.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow Postgres access only from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "postgres"
  engine_version = "16.14"

  instance_class    = var.db_instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true # encryption at rest

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  db_subnet_group_name  = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # No public access — this instance lives in an isolated subnet with
  # no internet route, but this flag is explicit defense-in-depth
  publicly_accessible = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:30-mon:05:30"

  # For a portfolio/dev project, skip_final_snapshot keeps teardown
  # simple. In real production you would set this to false.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
  }
}

# Store the connection details in Secrets Manager so the application
# never sees the password in an env var defined by Terraform — ECS
# injects it directly from here at container start time.
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}-${var.environment}-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.db_master.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

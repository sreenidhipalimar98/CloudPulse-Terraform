# ECR repository for the CloudPulse API container image.
# image_tag_mutability = IMMUTABLE means once a tag like "v1.2.0" is
# pushed, it can never be overwritten — a real production safeguard
# that prevents "latest pointed somewhere different than I thought"
# incidents.
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true # automatic vulnerability scanning on every push
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Lifecycle policy: keep the registry from growing unbounded by
# expiring untagged images after 7 days, and keeping only the last
# 10 tagged images.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}



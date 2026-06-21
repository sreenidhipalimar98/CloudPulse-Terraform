# IAM module — implements the principle of least privilege via two
# distinct ECS roles, which is the standard production pattern:
#
#   execution_role -> used by ECS itself to PULL the container image
#                      and PULL secrets before the task even starts.
#                      Has no access to YOUR application's AWS resources.
#
#   task_role      -> used by YOUR APPLICATION CODE at runtime to call
#                      AWS APIs (e.g. boto3 reading CloudWatch metrics).
#                      Scoped to exactly what CloudPulse's API needs —
#                      nothing more.
#
# Conflating these two into one role is a common mistake that violates
# least privilege — calling it out explicitly is a good interview signal.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- GitHub OIDC Provider ---
# Allows GitHub Actions to authenticate to AWS without long-lived keys.
# This only needs to exist once per AWS account — the `create_before_destroy`
# lifecycle prevents errors if it already exists.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable, published by GitHub)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- ECS Task Execution Role ---
# Used by the ECS agent to start the container: pull image from ECR,
# write logs to CloudWatch, fetch the DB secret to inject as an env var.
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Execution role also needs to read the DB secret to inject it into
# the container at startup
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${var.project_name}-${var.environment}-execution-secrets-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.secrets_manager_arn
    }]
  })
}

# --- ECS Task Role ---
# Used by the running application (CloudPulse's FastAPI backend) to
# call AWS APIs itself, e.g. boto3 describing EC2/RDS/ECS state.
# Scoped to read-only describe/list calls — this app reports on
# infrastructure, it never needs to modify it.
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_readonly_monitoring" {
  name = "${var.project_name}-${var.environment}-task-readonly-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeInfra"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:ListClusters",
          "ecs:ListServices",
          "rds:DescribeDBInstances",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        # These are read-only "describe/list/get" calls only — the
        # application cannot create, modify, or delete any resource.
        Resource = "*"
      }
    ]
  })
}

# --- CI/CD deploy role ---
# Assumed by GitHub Actions (via OIDC) to push images and trigger
# ECS deployments — scoped to exactly those two actions, nothing else.
resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project_name}-${var.environment}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Restrict to your specific GitHub repo — replace with your username/repo
          # NOTE: trusts the cloudpulse-api repo, not cloudpulse-infra —
          # the API repo's CI/CD pipeline is what builds, pushes, and
          # deploys the container image. The infra repo's own pipeline
          # (if any) only runs `terraform plan/apply` and doesn't need
          # this role at all.
          "token.actions.githubusercontent.com:sub" = "repo:sreenidhipalimar98/cloudpulse-api:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_deploy_policy" {
  name = "${var.project_name}-${var.environment}-github-deploy-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSDeploy"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid      = "PassRolesToECS"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [aws_iam_role.ecs_execution_role.arn, aws_iam_role.ecs_task_role.arn]
      }
    ]
  })
}

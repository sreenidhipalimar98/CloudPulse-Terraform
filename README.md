# CloudPulse-Terraform

AWS infrastructure as code for the CloudPulse cloud monitoring platform, built with Terraform.

## What This Deploys

- **VPC** — 3-tier network (public, private, database subnets) across 2 availability zones in `ap-south-1`
- **ECR** — Container registry for the CloudPulse API Docker image
- **ECS (Fargate)** — Runs the API behind an Application Load Balancer, no servers to manage
- **RDS (PostgreSQL)** — Database in an isolated subnet, password auto-generated and stored in Secrets Manager
- **IAM** — Least-privilege roles for ECS execution, app runtime, and GitHub Actions CI/CD via OIDC

## Project Structure

```
terraform/
├── bootstrap/               # Run ONCE first — creates S3 + DynamoDB for remote state
├── environments/
│   └── dev/                 # Dev environment — composes all modules
│       ├── main.tf
│       ├── backend.tf
│       ├── providers.tf
│       ├── variables.tf
│       └── outputs.tf
└── modules/
    ├── vpc/                 # Networking
    ├── ecr/                 # Container registry
    ├── ecs/                 # Fargate service + ALB
    ├── iam/                 # Roles and policies
    └── rds/                 # PostgreSQL database
```

## Deployment Steps

### Step 1 — Bootstrap (run once only)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Note the `state_bucket_name` output value.

### Step 2 — Configure remote state

Open `terraform/environments/dev/backend.tf` and replace `REPLACE_WITH_YOUR_ACCOUNT_ID` with your AWS account ID.

### Step 3 — Deploy dev environment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 4 — Update GitHub Actions role

In `terraform/modules/iam/main.tf`, replace `YOUR_GITHUB_USERNAME/cloudpulse` with your actual GitHub repo path before applying.

## AWS Profile

This project uses the `cloudpulse` AWS CLI profile. Set it before running any Terraform commands:

```bash
# PowerShell
$env:AWS_PROFILE = "cloudpulse"

# Bash
export AWS_PROFILE=cloudpulse
```

## Key Outputs After Apply

| Output | Description |
|--------|-------------|
| `api_url` | Public URL of the CloudPulse API (ALB DNS) |
| `ecr_repository_url` | Push your Docker images here |
| `github_actions_deploy_role_arn` | Add to GitHub repo secrets as `AWS_DEPLOY_ROLE_ARN` |

## Region

All resources deploy to `ap-south-1` (Mumbai) by default.

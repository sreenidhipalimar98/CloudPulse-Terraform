# cloudpulse-infra

**Terraform infrastructure for [CloudPulse](https://github.com/YOUR_GITHUB_USERNAME/cloudpulse-api) — an AWS infrastructure health and deployment monitoring platform.**

This repository contains *only* infrastructure-as-code. The application that runs on top of this infrastructure lives in a separate repository: [`cloudpulse-api`](https://github.com/YOUR_GITHUB_USERNAME/cloudpulse-api).

## Why a separate repo

Infrastructure and application code have different lifecycles, different review needs, and different blast radii when something goes wrong. Splitting them is standard practice on real engineering teams:

- A change to an API route shouldn't require touching infrastructure code, and vice versa.
- Infrastructure changes (provisioning, IAM, networking) often need stricter review and slower rollout than application code.
- This repo's pipeline only ever runs `terraform plan` / `terraform apply`. It never builds or pushes a container image — that happens in `cloudpulse-api`, which has its own narrower IAM role for exactly that purpose.

## What this provisions

- A three-tier VPC (public / private / database subnets)
- An ECS Fargate cluster + service behind an Application Load Balancer
- An RDS PostgreSQL instance, encrypted, isolated, with auto-generated credentials in Secrets Manager
- An ECR repository for the application's container images (vulnerability scanning on push)
- IAM roles built around least privilege — including a dedicated OIDC role that the `cloudpulse-api` repo's CI/CD pipeline assumes to deploy, with no long-lived AWS keys involved

## Repository structure

```
cloudpulse-infra/
├── bootstrap/                  # One-time setup: S3 state bucket + DynamoDB lock table
│   └── main.tf
├── modules/                    # Reusable, composable infrastructure modules
│   ├── vpc/                    # Three-tier VPC
│   ├── ecr/                    # Container registry
│   ├── rds/                    # PostgreSQL, isolated subnet, encrypted
│   ├── iam/                    # Least-privilege roles
│   └── ecs/                    # Fargate cluster, ALB, service
├── environments/
│   └── dev/                    # Composes all modules for the dev environment
└── .github/workflows/          # terraform plan/apply on PR and merge (CI only — no deploy)
```

## Getting started

### 1. Bootstrap remote state (one-time, run manually)
```bash
cd bootstrap
terraform init
terraform apply
```
Note the `state_bucket_name` output.

### 2. Configure the dev environment
Edit `environments/dev/backend.tf` and replace the placeholder bucket name with the one from step 1.

### 3. Provision
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 4. Note the outputs
After apply, `terraform output` gives you:
- `ecr_repository_url` — needed in `cloudpulse-api`'s CI/CD pipeline config
- `github_actions_deploy_role_arn` — add this as a secret (`AWS_DEPLOY_ROLE_ARN`) in the `cloudpulse-api` repo
- `ecs_cluster_name` / `ecs_service_name` — needed by the deploy step in `cloudpulse-api`'s pipeline
- `api_url` — the live URL once the API is deployed

These outputs are the contract between this repo and `cloudpulse-api` — the application repo's pipeline consumes them rather than duplicating any infrastructure definitions.

## Key design decisions

- **Least-privilege IAM, three separate roles.** The ECS execution role, ECS task role, and GitHub Actions deploy role are all distinct, each scoped to only what it needs.
- **No long-lived AWS credentials anywhere.** CI/CD authenticates via OIDC federation.
- **Database has no internet route at all.** Not just a security group rule — the database subnet's route table has no NAT or internet gateway route, full stop.
- **Remote state with locking**, set up once via `bootstrap/`, shared by all environments.

## Tech stack

Terraform >= 1.7.0 · AWS provider ~> 5.0 · S3 + DynamoDB remote state

## Author

**Sreenidhi Palimar** — DevOps Engineer, AWS Certified Solutions Architect – Associate
[LinkedIn](https://www.linkedin.com/in/sreenidhi-palimar/) · [cloudpulse-api](https://github.com/YOUR_GITHUB_USERNAME/cloudpulse-api)

## License

MIT — see [LICENSE](LICENSE)

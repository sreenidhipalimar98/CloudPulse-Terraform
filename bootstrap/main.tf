# Bootstrap: creates the S3 bucket + DynamoDB table used to store
# Terraform remote state for the rest of this project.
#
# Run this ONCE, manually, before anything else:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# This itself uses LOCAL state (intentionally) — you can't store the
# state for your state backend inside the backend it creates.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for state resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names"
  type        = string
  default     = "cloudpulse"
}

# S3 bucket to hold the actual .tfstate files
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  # Prevent accidental deletion of this bucket via terraform destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest — state files can contain sensitive data
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — defense in depth even though the bucket
# is never meant to be public
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking — prevents two people (or two
# CI runs) from running terraform apply at the same time and
# corrupting state
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_caller_identity" "current" {}

output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "S3 bucket name to reference in backend.tf of other environments"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table name to reference in backend.tf of other environments"
}

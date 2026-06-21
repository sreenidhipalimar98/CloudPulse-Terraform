# Remote state backend — points at the S3 bucket + DynamoDB table
# created by terraform/bootstrap. Run `terraform init` after filling
# in the bucket name from the bootstrap output.

terraform {
  backend "s3" {
    bucket         = "cloudpulse-terraform-state-995547019839"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "cloudpulse-terraform-locks"
    encrypt        = true
  }
}

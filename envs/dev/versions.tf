terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Remote state in S3 (native locking, no DynamoDB needed on TF >= 1.10).
  # NOTE: the bucket must already exist (run terraform/bootstrap first), then
  # fill in the bucket name below and run `terraform init`.
  backend "s3" {
    bucket       = "gistr-terraform-state-992382467806"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

# ---------------------------------------------------------------------------
# Bootstrap: Terraform remote state backend (S3)
# ---------------------------------------------------------------------------
# Run this ONCE, before any environment. It creates the S3 bucket that stores
# all Terraform state files. This config uses LOCAL state (chicken-and-egg:
# the bucket that holds remote state cannot store its own creation state).
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "Gistr"
      ManagedBy = "Terraform"
      Owner     = var.owner
      Component = "tf-state-backend"
    }
  }
}

variable "aws_region" {
  description = "AWS region. All Gistr resources live in Mumbai."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "Teleglobal"
}

# Account ID is used to make the bucket name globally unique.
data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "gistr-terraform-state-${data.aws_caller_identity.current.account_id}"
}

# S3 bucket that stores Terraform state for all environments.
resource "aws_s3_bucket" "tf_state" {
  bucket = local.state_bucket_name

  # Safety: prevent accidental destruction of the state bucket.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning: every state change is retained, so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest (state can contain sensitive values).
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block all public access — state is always private.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state. Use this in each env's backend config."
  value       = aws_s3_bucket.tf_state.id
}

output "aws_region" {
  value = var.aws_region
}

locals {
  region = "us-east-2"
}

provider "aws" {
  region = local.region
}

# Create S3 bucket for storing Terraform state
resource "aws_s3_bucket" "terraform_global" {
  bucket = "openmrs-terraform-global"
  # Enable versioning so we can see the full revision history of our
  # state files
  versioning {
    enabled = true
  }
  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Create DynamoDB table for storing Terraform state lock
resource "aws_dynamodb_table" "terraform_global_locks" {
  name         = "openmrs-terraform-global-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
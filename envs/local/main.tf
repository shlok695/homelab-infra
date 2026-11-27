terraform {
  required_version = ">= 1.10" # use_lockfile needs 1.10+
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # check `terraform init` output; pin to its major
    }
  }
  backend "s3" {
    bucket                      = "tf-state"
    key                         = "local/terraform.tfstate"
    region                      = "us-east-1"
    use_lockfile                = true                                 # replaces dynamodb_table
    endpoints                   = { s3 = "http://100.87.225.55:4566" } # dynamodb no longer needed
    use_path_style              = true
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}

variable "endpoint" { default = "http://100.87.225.55:4566" }

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
  endpoints {
    s3             = var.endpoint
    sqs            = var.endpoint
    dynamodb       = var.endpoint
    secretsmanager = var.endpoint
    events         = var.endpoint
    scheduler      = var.endpoint
    lambda         = var.endpoint
    ses            = var.endpoint
    sfn            = var.endpoint
    iam            = var.endpoint
    sts            = var.endpoint
  }
}

resource "aws_s3_bucket" "hello" { bucket = "hello-homelab" }

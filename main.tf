terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.3"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_credentials.access_key
  secret_key = var.aws_credentials.secret_key
}

data "aws_availability_zones" "available" {
  state = "available"
}

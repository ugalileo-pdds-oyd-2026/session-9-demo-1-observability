terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "session9-demo1-tfstate"
    key            = "session9/demo1/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "session9-demo1-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

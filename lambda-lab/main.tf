terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.52.0"
    }
    docker = { source = "kreuzwerker/docker" }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "this" {}
data "aws_ecr_authorization_token" "token" {}

provider "aws" {
  region = var.aws_region
}

provider "docker" {
  registry_auth {
    address  = "${data.aws_caller_identity.this.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

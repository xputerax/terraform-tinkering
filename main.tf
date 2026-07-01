terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.52.0"
    }
  }
}

provider "aws" {
    region = "ap-southeast-5"
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    owners = ["099720109477"] # Canonical
}
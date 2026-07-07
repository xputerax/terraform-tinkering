data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["860882034098"] # Amazon

  filter {
    name   = "image-id"
    values = ["ami-01db15d4157bc6eda"] # Amazon Linux 2023 kernel-6.18 AMI (x86)
  }
}

data "aws_caller_identity" "current" {

}
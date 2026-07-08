data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

# update: please don't use this, use the API fetched from SSM Parameter Store - that one is ECS-optimized
# using this, we need to configure a bunch of stuff manually to make it work with ECS
# using this also caused me some issue with ECS Service Connect
# data "aws_ami" "amazon-linux" {
#   most_recent = true
#   owners      = ["860882034098"] # Amazon

#   filter {
#     name   = "image-id"
#     values = ["ami-01db15d4157bc6eda"] # Amazon Linux 2023 kernel-6.18 AMI (x86)
#   }
# }

data "aws_caller_identity" "current" {

}

# NEW — ECS-optimized AL2023 AMI (advertises ecs.service-connect)
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}
resource "aws_vpc" "this" {
  cidr_block = "10.10.10.0/24"
  tags = {
    "Name" = "ec2-autoscaling-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "ec2-autoscaling-vpc-igw"
  }
}

resource "aws_subnet" "ec2-autoscaling-vpc-5a-public-subnet" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "ec2-autoscaling-vpc-5a-public-subnet"
  }
  availability_zone = "ap-southeast-5a"
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 2, 0)
}

resource "aws_subnet" "ec2-autoscaling-vpc-5b-public-subnet" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "ec2-autoscaling-vpc-5b-public-subnet"
  }
  availability_zone = "ap-southeast-5b"
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 2, 1)
}

resource "aws_subnet" "ec2-autoscaling-vpc-5a-private-subnet" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "ec2-autoscaling-vpc-5a-private-subnet"
  }
  availability_zone = "ap-southeast-5a"
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 2, 2)
}

resource "aws_subnet" "ec2-autoscaling-vpc-5b-private-subnet" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "ec2-autoscaling-vpc-5b-private-subnet"
  }
  availability_zone = "ap-southeast-5b"
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 2, 3)
}

resource "aws_default_route_table" "default-rt" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    "Name" = "ec2-autoscaling-vpc-default-containment-rt"
  }
}

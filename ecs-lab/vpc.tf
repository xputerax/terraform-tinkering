locals {
  vpc_cidr = "10.10.10.0/24"
}

resource "aws_vpc" "this" {
  cidr_block = local.vpc_cidr
  tags = {
    Name = "ecs-lab-vpc"
  }
}

resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  route                  = []
  tags = {
    Name = "ecs-lab-vpc-containment-rt"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "ecs-lab-vpc-igw"
  }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "ap-southeast-5a"
  cidr_block        = cidrsubnet(local.vpc_cidr, 2, 0)
  tags = {
    Name = "ecs-lab-vpc-public-subnet-1"
  }
}

resource "aws_subnet" "public-subnet-2" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "ap-southeast-5b"
  cidr_block        = cidrsubnet(local.vpc_cidr, 2, 1)
  tags = {
    Name = "ecs-lab-vpc-public-subnet-1"
  }
}

resource "aws_route_table" "public-subnet-rt" {
  vpc_id = aws_vpc.this.id
  route {
    gateway_id = aws_internet_gateway.this.id
    cidr_block = "0.0.0.0/0" # Allow internet access
  }
  tags = {
    Name = "ecs-lab-vpc-public-subnet-rt"
  }
}

resource "aws_route_table_association" "public-subnet-rt-assoc" {
  route_table_id = aws_route_table.public-subnet-rt.id
  for_each = {
    az_apse5a = aws_subnet.public-subnet-1.id,
    az_apse5b = aws_subnet.public-subnet-2.id,
  }
  subnet_id = each.value
}

resource "aws_subnet" "private-subnet-1" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "ap-southeast-5a"
  cidr_block        = cidrsubnet(local.vpc_cidr, 2, 2)
  tags = {
    Name = "ecs-lab-vpc-private-subnet-1"
  }
}

resource "aws_route_table" "private-subnet-1-rt" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private-subnet-1-natgw.id
  }
  tags = {
    Name = "ecs-lab-vpc-private-subnet-1-rt"
  }
}

resource "aws_route_table_association" "private-subnet-1-rt-assoc" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-subnet-1-rt.id
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id            = aws_vpc.this.id
  availability_zone = "ap-southeast-5b"
  cidr_block        = cidrsubnet(local.vpc_cidr, 2, 3)
  tags = {
    Name = "ecs-lab-vpc-private-subnet-2"
  }
}

resource "aws_route_table" "private-subnet-2-rt" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private-subnet-2-natgw.id
  }
  tags = {
    Name = "ecs-lab-vpc-private-subnet-2-rt"
  }
}

resource "aws_route_table_association" "private-subnet-2-rt-assoc" {
  subnet_id      = aws_subnet.private-subnet-2.id
  route_table_id = aws_route_table.private-subnet-2-rt.id
}

# Nat Gateway defaults to type "zonal", i.e. we need to deploy 1 NATGW per AZ
# So we set subnet_id
resource "aws_nat_gateway" "private-subnet-1-natgw" {
  allocation_id = aws_eip.private-subnet-1-natgw-eip.allocation_id
  subnet_id     = aws_subnet.public-subnet-1.id
  tags = {
    Name = "ecs-lab-vpc-public-subnet-1-natgw"
  }
}

resource "aws_nat_gateway" "private-subnet-2-natgw" {
  allocation_id = aws_eip.private-subnet-2-natgw-eip.allocation_id
  subnet_id     = aws_subnet.public-subnet-2.id
  tags = {
    Name = "ecs-lab-vpc-public-subnet-2-natgw"
  }
}

resource "aws_eip" "private-subnet-1-natgw-eip" {
}

resource "aws_eip" "private-subnet-2-natgw-eip" {
}

resource "aws_ec2_instance_connect_endpoint" "private-subnet-1-eice" {
  subnet_id          = aws_subnet.private-subnet-1.id
  preserve_client_ip = false
  security_group_ids = [aws_security_group.eice-sg.id]
  tags = {
    "Name" = "ecs-lab-private-subnet-1-eice",
  }
}

# For some reason it no longer lets me create 2 EICE :(
# resource "aws_ec2_instance_connect_endpoint" "private-subnet-2-eice" {
#   subnet_id          = aws_subnet.private-subnet-2.id
#   preserve_client_ip = false
#   security_group_ids = [aws_security_group.eice-sg.id]
#   tags = {
#     "Name" = "ecs-lab-private-subnet-2-eice",
#   }
# }

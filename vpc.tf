resource "aws_vpc" "ap-southeast-5-terraform-vpc" {
    cidr_block = "10.0.1.0/24"
    enable_dns_hostnames = true
    tags = {
      "Name" = "ap-southeast-5-terraform-vpc"
    }
}

resource "aws_internet_gateway" "ap-southeast-5-terraform-vpc-igw" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    tags = {
      "Name" = "ap-southeast-5-terraform-vpc-igw"
    }
}

resource "aws_subnet" "ap-southeast-5-terraform-vpc-5a-public-subnet" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    cidr_block = "10.0.1.0/26"
    availability_zone = "ap-southeast-5a"
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5a-public-subnet"
    }
}

resource "aws_subnet" "ap-southeast-5-terraform-vpc-5b-public-subnet" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    cidr_block = "10.0.1.64/26"
    availability_zone = "ap-southeast-5b"
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5b-public-subnet"
    }
}

resource "aws_subnet" "ap-southeast-5-terraform-vpc-5a-private-subnet" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    cidr_block = "10.0.1.128/26"
    availability_zone = "ap-southeast-5a"
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5a-private-subnet"
    }
}

resource "aws_subnet" "ap-southeast-5-terraform-vpc-5b-private-subnet" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    cidr_block = "10.0.1.192/26"
    availability_zone = "ap-southeast-5b"
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5b-private-subnet"
    }
}

# private subnets: local-only, intentionally no egress (no NAT yet).
resource "aws_route_table" "ap-southeast-5-terraform-vpc-5a-private-subnet-rt-default" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5a-private-subnet-rt-default"
    }
}

resource "aws_route_table_association" "ap-southeast-5-terraform-vpc-5a-private-subnet-rt-default-assoc" {
    subnet_id = aws_subnet.ap-southeast-5-terraform-vpc-5a-private-subnet.id
    route_table_id = aws_route_table.ap-southeast-5-terraform-vpc-5a-private-subnet-rt-default.id
}

# private subnets: local-only, intentionally no egress (no NAT yet).
resource "aws_route_table" "ap-southeast-5-terraform-vpc-5b-private-subnet-rt-default" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5b-private-subnet-rt-default"
    }
}

resource "aws_route_table_association" "ap-southeast-5-terraform-vpc-5b-private-subnet-rt-default-assoc" {
    subnet_id = aws_subnet.ap-southeast-5-terraform-vpc-5b-private-subnet.id
    route_table_id = aws_route_table.ap-southeast-5-terraform-vpc-5b-private-subnet-rt-default.id
}

# only create 1 public route table for this VPC - shared across 5a & 5b
resource "aws_route_table" "ap-southeast-5-terraform-vpc-5-public-subnet-rt-default" {
    vpc_id = aws_vpc.ap-southeast-5-terraform-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.ap-southeast-5-terraform-vpc-igw.id
    }
    tags = {
        "Name" = "ap-southeast-5-terraform-vpc-5-public-subnet-rt-default"
    }
}

resource "aws_route_table_association" "ap-southeast-5-terraform-vpc-public-subnet-rt-default-assoc" {
    for_each = {
        ap-southeast-5a_public = aws_subnet.ap-southeast-5-terraform-vpc-5a-public-subnet.id,
        ap-southeast-5b_public = aws_subnet.ap-southeast-5-terraform-vpc-5b-public-subnet.id
    }
    route_table_id = aws_route_table.ap-southeast-5-terraform-vpc-5-public-subnet-rt-default.id
    subnet_id = each.value
}

# there's a default route table created for the VPC
# to be safe, we remove all non-local routes
resource "aws_default_route_table" "default-rt" {
    default_route_table_id = aws_vpc.ap-southeast-5-terraform-vpc.default_route_table_id
    route = []
    tags = {
        "Name" = "default-containment-rt"
    }
}

resource "aws_ec2_instance_connect_endpoint" "ap-southeast-5a-eice" {
    subnet_id = aws_subnet.ap-southeast-5-terraform-vpc-5a-private-subnet.id
    preserve_client_ip = false
    tags = {
        "Name" = "ap-southeast-5a-eice"
    }
}

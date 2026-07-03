module "ap-southeast-5a-fck-nat" {
  source = "RaJiska/fck-nat/aws"

  name                = "ap-southeast-5a-fcknat"
  vpc_id              = aws_subnet.ap-southeast-5-terraform-vpc-5a-public-subnet.vpc_id
  subnet_id           = aws_subnet.ap-southeast-5-terraform-vpc-5a-public-subnet.id
  update_route_tables = true
  # auto_rollout will perform ASG instance refresh i guess?
  # because redeploying this module updates the launch template, etc.
  # if we don't refresh, the old fck-nat instances will remain stale (old subnet/vpc, etc)
  # and terraform cannot detect the drift
  auto_rollout = true
  route_tables_ids = {
    "ap-southeast-5a-private-subnet-rt-default" = aws_route_table.ap-southeast-5-terraform-vpc-5a-private-subnet-rt-default.id,
  }
}

module "ap-southeast-5b-fck-nat" {
  source = "RaJiska/fck-nat/aws"

  name                = "ap-southeast-5b-fcknat"
  vpc_id              = aws_subnet.ap-southeast-5-terraform-vpc-5b-public-subnet.vpc_id
  subnet_id           = aws_subnet.ap-southeast-5-terraform-vpc-5b-public-subnet.id
  update_route_tables = true
  auto_rollout        = true
  route_tables_ids = {
    "ap-southeast-5b-private-subnet-rt-default" = aws_route_table.ap-southeast-5-terraform-vpc-5b-private-subnet-rt-default.id,
  }
}

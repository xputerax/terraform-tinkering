data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["860882034098"] # Amazon

  filter {
    name   = "image-id"
    values = ["ami-01db15d4157bc6eda"] # Amazon Linux 2023 kernel-6.18 AMI (x86)
  }

  # filter {
  #   name   = "name"
  #   values = ["al2023-ami-*-x86_64"]
  # }

  # filter {
  #   name   = "virtualization-type"
  #   values = ["hvm"]
  # }
}

resource "aws_launch_template" "this" {
  name          = "ec2-autoscaling-launchtemplate"
  instance_type = "t3.small"
  network_interfaces {
    # give the instance a public IP
    associate_public_ip_address = true
    # subnet_id                   = aws_subnet.ec2-autoscaling-vpc-5a-public-subnet.id
    security_groups = [aws_security_group.ec2-sg.id]
    # subnet_id = aws_subnet.ec2-autoscaling-vpc-private-subnet.id
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "Name" = "ec2-autoscaling-node"
    }
  }
  image_id = data.aws_ami.amazon-linux.image_id
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    systemctl enable --now httpd
    echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
  EOF
  )
}

resource "aws_autoscaling_group" "this" {
  name             = "ec2-asg"
  max_size         = 3
  min_size         = 1
  desired_capacity = 3
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  # load_balancers = [aws_lb.this.id]
  target_group_arns = [aws_lb_target_group.this.arn]
  # don't use availability_zones (legacy/classic AWS)
  vpc_zone_identifier = [
    aws_subnet.ec2-autoscaling-vpc-5a-public-subnet.id,
    aws_subnet.ec2-autoscaling-vpc-5b-public-subnet.id
  ]
}

locals {
  ingress_ports = [80]
}

resource "aws_security_group" "lb-ingress-sg" {
  vpc_id = aws_vpc.this.id
  tags = {
    "Name" = "lb-ingress-sg"
  }
}

# Allow traffic from internet -> LB
resource "aws_security_group_rule" "lb-ingress-sg-inboundrules" {
  security_group_id = aws_security_group.lb-ingress-sg.id
  for_each          = toset([for p in local.ingress_ports : tostring(p)])

  type        = "ingress"
  protocol    = "tcp"
  from_port   = each.value
  to_port     = each.value
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow LB to connect to EC2 Port 80
resource "aws_security_group_rule" "lb-ingress-sg-outboundrules" {
  security_group_id        = aws_security_group.lb-ingress-sg.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = aws_security_group.ec2-sg.id
}

resource "aws_lb" "this" {
  name               = "ec2-autoscaling-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb-ingress-sg.id]
  subnets            = [aws_subnet.ec2-autoscaling-vpc-5a-public-subnet.id, aws_subnet.ec2-autoscaling-vpc-5b-public-subnet.id]
}

resource "aws_lb_target_group" "this" {
  name        = "ec2-autoscaling-lb-targetgroup"
  vpc_id      = aws_vpc.this.id
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_security_group" "ec2-sg" {
  vpc_id = aws_vpc.this.id
  name   = "ec2-sg"
  tags = {
    "Name" = "ec2-sg"
  }
}

# allow traffic from LB -> EC2
resource "aws_security_group_rule" "ec2-sg-lb-inboundrules" {
  security_group_id = aws_security_group.ec2-sg.id

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = aws_security_group.lb-ingress-sg.id
}

resource "aws_security_group_rule" "ec2-sg-egress" {
  security_group_id = aws_security_group.ec2-sg.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
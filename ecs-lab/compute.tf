locals {
  node_instance_type   = "t3.medium"
  asg_min_size         = 1
  asg_max_size         = 3
  asg_desired_capacity = 1
  echo_server_task_count = 8 # BEWARE: EC2 ENI Limit (we are using awsvpc networking)
}

resource "aws_launch_template" "ecs-node-lt" {
  name          = "ecs-lab-node-lt"
  instance_type = local.node_instance_type
  vpc_security_group_ids = [
    aws_security_group.ecs-node-sg.id,
    aws_security_group.eice-sg.id,
  ]
  image_id               = data.aws_ssm_parameter.ecs_optimized_ami.value
  update_default_version = true
  tag_specifications {
    resource_type = "instance"
    tags = {
      "Name" = "ecs-node"
    }
  }
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    systemctl enable --now httpd
    echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
    echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
  EOF
  )
  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs-node-instance-profile.arn
  }
}

resource "aws_iam_instance_profile" "ecs-node-instance-profile" {
  name = "ecs-node-instance-profile"
  role = aws_iam_role.ecs-node-role.name
}

resource "aws_iam_role" "ecs-node-role" {
  name               = "ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-node-trust.json
}

resource "aws_iam_role_policy_attachment" "ecs-node-role-AmazonEC2ContainerServiceforEC2Role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.ecs-node-role.name
}

resource "aws_iam_role_policy_attachment" "ecs-node-role-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ecs-node-role.name
}

data "aws_iam_policy_document" "ecs-execution-role-trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs-execution-role" {
  name               = "ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-execution-role-trust.json
}

resource "aws_iam_role_policy_attachment" "ecs-task-role-AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.ecs-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs-node-trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_autoscaling_group" "ecs-asg" {
  name             = "ecs-lab-node-asg"
  min_size         = local.asg_min_size
  max_size         = local.asg_max_size
  desired_capacity = local.asg_desired_capacity
  launch_template {
    id      = aws_launch_template.ecs-node-lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = toset([
    aws_subnet.private-subnet-1.id,
    aws_subnet.private-subnet-2.id,
  ])
  target_group_arns = [aws_lb_target_group.this.arn]

  # required by Terraform if ECS is using ASG as capacity provider
  tag {
    key                 = "AmazonECSManaged"
    propagate_at_launch = true
    value               = true
  }
}

resource "aws_lb_target_group" "this" {
  name        = "ecs-lab-node-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"
}

resource "aws_lb" "this" {
  name               = "ecs-lb"
  load_balancer_type = "application"
  subnet_mapping {
    subnet_id = aws_subnet.public-subnet-1.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.public-subnet-2.id
  }
  security_groups = [aws_security_group.ecs-lab-lb-ingress-sg.id, aws_security_group.ecs-lab-lb-egress-to-node-sg.id]
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  protocol          = "HTTP"
  port              = 80
  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.this.arn
      }
    }
  }
}

# forward ^/echo -> ECS service (echo-server)
resource "aws_lb_listener_rule" "ecs-service-echo-server-service-listener" {
  listener_arn = aws_lb_listener.this.arn
  condition {
    path_pattern {
      regex_values = ["^/echo"]
    }
  }
  action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.ecs-service-echo-server-tg.arn
      }
    }
  }
  tags = {
    Name = "ecs-service-echo-server"
  }
}

# Allow Internet to talk to LB
resource "aws_security_group" "ecs-lab-lb-ingress-sg" {
  name   = "ecs-lab-lb-ingress-sg"
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group_rule" "ecs-lab-lb-ingress-sg-rules" {
  security_group_id = aws_security_group.ecs-lab-lb-ingress-sg.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"] # allow everything from internet
}

# Allow LB to initiate connection to ECS EC2 Nodes
resource "aws_security_group" "ecs-lab-lb-egress-to-node-sg" {
  name   = "ecs-lab-lb-egress-to-node-sg"
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group_rule" "ecs-lab-lb-egress-to-node-sg-rules" {
  security_group_id        = aws_security_group.ecs-lab-lb-egress-to-node-sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  type                     = "egress"
  source_security_group_id = aws_security_group.ecs-node-sg.id # TODO: is this right
}

# Allow Inbound To EC2 from LB
resource "aws_security_group" "ecs-node-sg" {
  name   = "ecs-node-sg"
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group_rule" "ecs-node-sg-allow-from-lb-rule" {
  security_group_id        = aws_security_group.ecs-node-sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = aws_security_group.ecs-lab-lb-egress-to-node-sg.id
}

# Uncomment this to allow ECS node to talk to ECS task directly (i.e. `curl <task ENI IP>`)
# resource "aws_security_group_rule" "ecs-node-sg-allow-from-itself" {
#   security_group_id        = aws_security_group.ecs-node-sg.id
#   from_port                = 80
#   to_port                  = 80
#   protocol                 = "tcp"
#   type                     = "ingress"
#   source_security_group_id = aws_security_group.ecs-node-sg.id
# }

resource "aws_security_group_rule" "ecs-node-sg-allow-outbound-everywhere" {
  security_group_id = aws_security_group.ecs-node-sg.id
  from_port         = 0
  to_port           = 0
  protocol          = -1
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_instance" "bastion" {
  vpc_security_group_ids = [
    aws_security_group.ecs-lab-lb-egress-to-node-sg.id,
    aws_security_group.eice-sg.id,
  ]
  instance_type = "t3.small"
  ami           = data.aws_ami.ubuntu.image_id
  subnet_id     = aws_subnet.private-subnet-1.id
  tags = {
    Name = "ecs-lab-bastion"
  }
  iam_instance_profile = aws_iam_instance_profile.ecs-node-instance-profile.name
}

resource "aws_security_group" "eice-sg" {
  vpc_id = aws_vpc.this.id
  name   = "ecs-lab-eice-sg"
}

resource "aws_security_group_rule" "eice-sg-rules-ssh-ingress" {
  security_group_id        = aws_security_group.eice-sg.id
  source_security_group_id = aws_security_group.eice-sg.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "TCP"
  type                     = "ingress"
}

resource "aws_security_group_rule" "eice-sg-rules-ssh-egress" {
  security_group_id        = aws_security_group.eice-sg.id
  source_security_group_id = aws_security_group.eice-sg.id
  from_port                = 22
  to_port                  = 22
  protocol                 = "TCP"
  type                     = "egress"
}

resource "aws_security_group_rule" "eice-sg-rules-egress-allow-all" {
  security_group_id = aws_security_group.eice-sg.id
  from_port         = 0
  to_port           = 0
  protocol          = -1
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_ecs_cluster" "this" {
  name = "ecs-lab-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "ecs-lab-cluster-capacityproviders" {
  cluster_name = aws_ecs_cluster.this.name
  capacity_providers = toset([
    aws_ecs_capacity_provider.ecs-asg-provider.name,
  ])
}

resource "aws_ecs_capacity_provider" "ecs-asg-provider" {
  name = "asg-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs-asg.arn
  }
}

resource "aws_lb_target_group" "ecs-service-echo-server-tg" {
  name                 = "ecs-lab-service-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_vpc.this.id
  target_type          = "ip"
  deregistration_delay = 30 # seconds (default 300). echo-server is stateless; lowers deploy drain time.
}

resource "aws_ecs_task_definition" "echo-server" {
  family                = "echo-server"
  container_definitions = file("echo-server.container-definition.json")
  memory                = 128
  cpu                   = 512
  network_mode          = "awsvpc"
  execution_role_arn    = aws_iam_role.ecs-execution-role.arn # for the ECS agent (here we need to register to target group)
  # task_role_arn = "" # for the code (i.e. call S3, etc) - not needed here
}

resource "aws_ecs_service" "echo-server" {
  name            = "echo-server-service"
  cluster         = aws_ecs_cluster.this.arn
  desired_count   = local.echo_server_task_count
  task_definition = aws_ecs_task_definition.echo-server.arn

  # register this service with the load balancer target group
  load_balancer {
    container_name   = "echo-server"
    container_port   = "80"
    target_group_arn = aws_lb_target_group.ecs-service-echo-server-tg.arn
  }

  # register this service with CloudMap
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.ecs-cluster-dns.arn
    service {
      discovery_name = "echo-server"
      port_name      = "web"
      client_alias {
        port = 80
      }
    }
  }

  network_configuration {
    assign_public_ip = false
    security_groups = [
      aws_security_group.ecs-node-sg.id, # required - otherwise ALB cannot talk to it, even though the container (EC2) already has this SG
    ]
    subnets = [
      aws_subnet.private-subnet-1.id,
      aws_subnet.private-subnet-2.id,
    ]
  }

  # Drain old tasks before launching new ones. The default (minimum_healthy_percent=100)
  # forces launch-new-first, which deadlocks when the cluster has no spare CPU to run the
  # replacement. 50 lets ECS drain down toward ~half before standing up to the next TD version
  # Use 0 for maximum rollout speed at the cost of temporary capacity loss.
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 150
}

# alternative to setting awslogs options `awslogs-create-group = true`
resource "aws_cloudwatch_log_group" "echo-server" {
  name = "/ecs/echo-server"
}

resource "aws_service_discovery_private_dns_namespace" "ecs-cluster-dns" {
  vpc  = aws_vpc.this.id
  name = "ecs-cluster-dns"
}
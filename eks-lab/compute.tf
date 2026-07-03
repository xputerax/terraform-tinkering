resource "aws_iam_role" "cluster-role" {
  name = "test-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster-role-policy-attachment" {
  role       = aws_iam_role.cluster-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "cluster-node-role" {
  name                  = "test-cluster-node-role"
  force_detach_policies = true
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster-node-role-policy-attachment" {
  role = aws_iam_role.cluster-node-role.name
  for_each = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  }
  policy_arn = each.value
}

locals {
  # add a name here = that IAM user becomes a cluster admin
  admins = [
    "arn:aws:iam::549832005768:user/aimand",
    # "arn:aws:iam::549832005768:user/aimandaniel",
  ]
}

resource "aws_eks_cluster" "ap-southeast-5-terraform-vpc-test-cluster-eks" {
  name = "test-cluster"
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  vpc_config {
    # security_group_ids = [
    #     aws_security_group.cluster-sg.id
    # ]
    subnet_ids = [
      aws_subnet.ap-southeast-5-terraform-vpc-5a-private-subnet.id,
      aws_subnet.ap-southeast-5-terraform-vpc-5b-private-subnet.id,
    ]
  }
  role_arn = aws_iam_role.cluster-role.arn
}

resource "aws_eks_node_group" "ap-southeast-5-terraform-vpc-test-cluster-eks-node-group" {
  node_group_name = "test-cluster-node-group-1"
  scaling_config {
    min_size     = 1
    desired_size = 1
    max_size     = 1
  }
  capacity_type = "ON_DEMAND"
  launch_template {
    name    = aws_launch_template.cluster-node-ec2-launchtemplate.name
    version = "$Default"
  }

  node_role_arn = aws_iam_role.cluster-node-role.arn
  cluster_name  = aws_eks_cluster.ap-southeast-5-terraform-vpc-test-cluster-eks.name
  subnet_ids = [
    aws_subnet.ap-southeast-5-terraform-vpc-5a-private-subnet.id,
    aws_subnet.ap-southeast-5-terraform-vpc-5b-private-subnet.id,
  ]
}

resource "aws_eks_access_entry" "cluster-admin-accessentry" {
  for_each      = toset(local.admins)
  cluster_name  = aws_eks_cluster.ap-southeast-5-terraform-vpc-test-cluster-eks.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "cluster-admin-accesspolicyassociation" {
  for_each      = toset(local.admins)
  cluster_name  = aws_eks_cluster.ap-southeast-5-terraform-vpc-test-cluster-eks.name
  principal_arn = aws_eks_access_entry.cluster-admin-accessentry[each.value].principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}

resource "aws_launch_template" "cluster-node-ec2-launchtemplate" {
  instance_type = "t3.medium"
  # count = 1
  vpc_security_group_ids = [
    aws_eks_cluster.ap-southeast-5-terraform-vpc-test-cluster-eks.vpc_config[0].cluster_security_group_id,
  ]
}
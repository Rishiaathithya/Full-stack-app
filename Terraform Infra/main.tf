terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region     = "ap-south-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# ========================== Creating the VPC ============================= #

resource "aws_vpc" "VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "tvpc"
  }
}

# ========================== Creating the Subnets ============================= #

resource "aws_subnet" "Pubsub" {
  count = 2
  vpc_id     = aws_vpc.VPC.id
  cidr_block = cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index)
  availability_zone = element(["ap-south-1a", "ap-south-1b"], count.index)

  tags = {
    Name = "pubsub-${count.index}"
  }
}


# Internet Gateway

resource "aws_internet_gateway" "tigw" {
  vpc_id = aws_vpc.VPC.id

  tags = {
    Name = "tigw"
  }
}

# Route Table Creation and associtation

resource "aws_route_table" "Pubsub_route_table" {
  vpc_id = aws_vpc.VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tigw.id
  }
  tags = {
    Name = "Pubsub-route-table"
  }
}

resource "aws_route_table_association" "Pubsub_association" {
  count          = 2
  subnet_id      = aws_subnet.Pubsub[count.index].id
  route_table_id = aws_route_table.Pubsub_route_table.id
}

#  ======================= Creation of the Security Group ========================= #

resource "aws_security_group" "Pubsub_cluster_sg" {
  vpc_id = aws_vpc.VPC.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Pubsub-cluster-sg"
  }
}

resource "aws_security_group" "Pubsub_node_sg" {
  vpc_id = aws_vpc.VPC.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Pubsub-node-sg"
  }
}

# =============== Creation of the EKS Cluster =================== #

resource "aws_eks_cluster" "Pubsub_cluster" {
  name     = "Pubsub-cluster"
  role_arn = aws_iam_role.Pubsub_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.Pubsub[*].id
    security_group_ids = [aws_security_group.Pubsub_cluster_sg.id]
  }

  tags = {
    Name = "Pubsub-cluster"
  }
}


resource "aws_eks_node_group" "Pubsub_node_group" {
  cluster_name    = aws_eks_cluster.Pubsub_cluster.name
  node_group_name = "Pubsub-node-group"
  node_role_arn   = aws_iam_role.Pubsub_node_group_role.arn
  subnet_ids      = aws_subnet.Pubsub[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.Pubsub_node_sg.id]
  }

  tags = {
    Name = "Pubsub-node-group"
  }
}


# ========================= IAM Roles ======================= #

resource "aws_iam_role" "Pubsub_cluster_role" {
  name = "Pubsub-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "Pubsub_cluster_role_policy" {
  role       = aws_iam_role.Pubsub_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "Pubsub_node_group_role" {
  name = "Pubsub-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "Pubsub_node_group_role_policy" {
  role       = aws_iam_role.Pubsub_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "Pubsub_node_group_cni_policy" {
  role       = aws_iam_role.Pubsub_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "Pubsub_node_group_registry_policy" {
  role       = aws_iam_role.Pubsub_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


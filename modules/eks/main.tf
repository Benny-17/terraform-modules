# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-"
  vpc_id      = var.vpc_id

  # Allow inbound from worker nodes
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_nodes.id]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-cluster-sg"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name            = var.cluster_name
  version         = var.kubernetes_version
  role_arn        = aws_iam_role.cluster.arn
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]

  tags = {
    Environment = var.environment
  }
}

# IAM Role for EKS Worker Nodes
resource "aws_iam_role" "worker_nodes" {
  name = "${var.cluster_name}-worker-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach required policies
resource "aws_iam_role_policy_attachment" "worker_node" {
  for_each   = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])
  policy_arn = each.value
  role       = aws_iam_role.worker_nodes.name
}

# Instance Profile for worker nodes
resource "aws_iam_instance_profile" "worker_nodes" {
  name = "${var.cluster_name}-worker-node-profile"
  role = aws_iam_role.worker_nodes.name
}

# Security Group for Worker Nodes
resource "aws_security_group" "worker_nodes" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = var.vpc_id

  # Allow inbound from cluster
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # Allow inbound from ALB (for pod traffic)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-worker-sg"
  }
}

# Launch Template for worker nodes (required for node group)
resource "aws_launch_template" "worker_nodes" {
  name_prefix = "${var.cluster_name}-worker-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-eks-worker-node"
    }
  }
}

# EKS Node Group (Auto Scaling Group)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.worker_nodes.arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  instance_types = [var.instance_type]

  launch_template {
    id      = aws_launch_template.worker_nodes.id
    version = aws_launch_template.worker_nodes.latest_version_number
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node
  ]
}

# Install VPC CNI Addon (for pod networking)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = "v1.14.1-eksbuild.1"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.vpc_cni.arn

  depends_on = [aws_eks_node_group.main]
}

# IAM role for VPC CNI addon
resource "aws_iam_role" "vpc_cni" {
  name = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

data "aws_caller_identity" "current" {}
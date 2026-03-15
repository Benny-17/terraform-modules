# ============================================================================
# IAM Role for EKS Cluster
# ============================================================================

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

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ============================================================================
# Security Group for EKS Cluster (NO inline ingress - breaks cycle)
# ============================================================================

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster control plane"

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

# ============================================================================
# EKS Cluster
# ============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

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
    Name        = "${var.project_name}-eks-cluster"
  }
}

# ============================================================================
# IAM Role for EKS Worker Nodes
# ============================================================================

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

  tags = {
    Name = "${var.project_name}-eks-worker-role"
  }
}

# Attach required policies to worker node role
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

# ============================================================================
# Security Group for Worker Nodes (NO inline ingress from cluster - breaks cycle)
# ============================================================================

resource "aws_security_group" "worker_nodes" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = var.vpc_id
  description = "Security group for EKS worker nodes"

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

# ============================================================================
# Security Group Rules (BREAK THE CYCLE - separate from inline ingress)
# ============================================================================

# Allow cluster control plane to communicate with worker nodes (egress from cluster)
resource "aws_security_group_rule" "cluster_to_worker_egress" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_nodes.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow cluster to worker nodes on 443"
}

# Allow worker nodes to communicate with cluster control plane (ingress to cluster)
resource "aws_security_group_rule" "worker_to_cluster_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker_nodes.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow worker nodes to cluster on 443"
}

# Allow worker nodes to accept kubelet connections from cluster (high port range)
resource "aws_security_group_rule" "worker_from_cluster_ephemeral" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.worker_nodes.id
  description              = "Allow cluster to worker nodes on ephemeral ports"
}

# ============================================================================
# Launch Template for Worker Nodes
# ============================================================================

resource "aws_launch_template" "worker_nodes" {
  name_prefix = "${var.cluster_name}-worker-"
  description = "Launch template for EKS worker nodes"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-eks-worker-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# EKS Node Group
# ============================================================================

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
    version = aws_launch_template.worker_nodes.latest_version
  }

  tags = {
    Environment = var.environment
    Name        = "${var.project_name}-eks-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_security_group_rule.cluster_to_worker_egress,
    aws_security_group_rule.worker_to_cluster_ingress,
    aws_security_group_rule.worker_from_cluster_ephemeral
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# VPC CNI Addon (for pod networking)
# ============================================================================

# resource "aws_eks_addon" "vpc_cni" {
#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = "vpc-cni"
#   addon_version = "v1.18.2-eksbuild.1"
#   resolve_conflicts_on_create = "OVERWRITE"
#   service_account_role_arn    = aws_iam_role.vpc_cni.arn

#   depends_on = [aws_eks_node_group.main]
 
#   tags = {
#     Name = "${var.project_name}-vpc-cni-addon"
#   }
# }

# ============================================================================
# IAM Role for VPC CNI Addon
# ============================================================================

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

  tags = {
    Name = "${var.project_name}-vpc-cni-role"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# ============================================================================
# Data Source: Current AWS Account ID
# ============================================================================

data "aws_caller_identity" "current" {}
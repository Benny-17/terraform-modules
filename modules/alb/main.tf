# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id

  # Allow inbound HTTP from internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTPS from internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

# Allow ALB to send traffic to EKS worker nodes
resource "aws_security_group_rule" "alb_to_workers" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.eks_worker_security_group_id
  description              = "Allow ALB to EKS worker nodes (NodePort range)"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name_prefix        = substr(replace(var.project_name, "-", ""), 0, 6)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group for EKS
# Routes traffic to Kubernetes Service (NodePort type)
resource "aws_lb_target_group" "eks" {
  name_prefix = substr(replace(var.project_name, "-", ""), 0, 6)
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-eks-tg"
    Environment = var.environment
  }
}

# Listener: Route HTTP requests to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks.arn
  }
}

# Data source: Get EKS worker node IDs
data "aws_instances" "eks_workers" {
  filter {
    name   = "tag:eks:nodegroup-name"
    values = ["${var.eks_cluster_name}-node-group"]
  }
}

# Register EKS worker nodes with target group
resource "aws_lb_target_group_attachment" "eks_workers" {
  for_each         = toset(data.aws_instances.eks_workers.ids)
  target_group_arn = aws_lb_target_group.eks.arn
  target_id        = each.value
  port             = 30000  # NodePort range start
}
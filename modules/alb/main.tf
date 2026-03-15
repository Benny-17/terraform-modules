# ============================================================================
# Security Group for ALB (allows traffic from internet)
# ============================================================================

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # Allow HTTP from internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  # Allow HTTPS from internet
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
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

# ============================================================================
# Allow ALB to send traffic to EKS worker nodes (NodePort range)
# ============================================================================

resource "aws_security_group_rule" "alb_to_workers" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.eks_worker_security_group_id
  description              = "Allow ALB to EKS worker nodes (NodePort range)"
}

# ============================================================================
# Application Load Balancer
# ============================================================================

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

# ============================================================================
# Target Group (points to EKS worker nodes)
# ============================================================================

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

# ============================================================================
# ALB Listener (HTTP on port 80)
# ============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks.arn
  }
}



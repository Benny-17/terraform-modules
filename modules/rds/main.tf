# ============================================================================
# DB Subnet Group (required for RDS in VPC)
# ============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# ============================================================================
# Security Group for RDS (only allows EKS workers)
# ============================================================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS database"

  # IMPORTANT: Only allow PostgreSQL from EKS worker nodes
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_worker_security_group_id]
    description     = "Allow PostgreSQL from EKS worker nodes only"
  }

  # Allow all outbound (for updates, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}

# ============================================================================
# RDS PostgreSQL Instance (FREE TIER OPTIMIZED)
# ============================================================================

resource "aws_db_instance" "main" {
  identifier            = "${var.project_name}-db-${var.environment}"
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class  # db.t3.micro (free tier)
  allocated_storage     = var.allocated_storage  # 20 GB (free tier)
  db_name               = var.db_name
  username              = var.db_username
  password              = var.db_password
  db_subnet_group_name  = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # CRITICAL: NO public access
  publicly_accessible = false

  # ============================================================================
  # FREE TIER: Minimal backup (7 days for dev, 7 for prod to save money)
  # ============================================================================
  backup_retention_period = 7  # FREE TIER: Keep it at 7 days
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  
  # FREE TIER: Skip final snapshot to avoid storage charges
  skip_final_snapshot = true
  
  # ============================================================================
  # FREE TIER: NO encryption (adds cost)
  # ============================================================================
  storage_encrypted = false  # FREE TIER: Disable to save money

  # ============================================================================
  # FREE TIER: Single-AZ only (multi-AZ charges)
  # ============================================================================
  multi_az = false  # FREE TIER: Always false

  # ============================================================================
  # FREE TIER: NO performance insights
  # ============================================================================
  performance_insights_enabled = false

  # FREE TIER: Use gp2 instead of gp3 (cheaper)
  storage_type = "gp2"

  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
    TierType    = "Free"
  }

  depends_on = [aws_security_group.rds]
}
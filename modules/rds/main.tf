# DB Subnet Group (required for RDS in VPC)
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Security Group for RDS
# IMPORTANT: Only allows traffic from EKS worker nodes
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = var.vpc_id

  # Inbound: Allow PostgreSQL from EKS worker nodes only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_worker_security_group_id]
    description     = "Allow PostgreSQL from EKS worker nodes"
  }

  # Outbound: Allow all (for updates, etc.)
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

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier            = "${var.project_name}-db-${var.environment}"
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  db_name               = var.db_name
  username              = var.db_username
  password              = var.db_password
  db_subnet_group_name  = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # IMPORTANT: Disable public accessibility
  publicly_accessible = false

  # Backup settings
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Enable encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Multi-AZ for HA
  multi_az = var.multi_az

  # Don't delete data on destroy (important for prod)
  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
  }
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-rds-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}
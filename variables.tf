variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "test"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

locals {
  config = {
    dev = {
      availability_zones    = 1
      instance_type         = "t3.medium"
      eks_desired_size      = 1
      eks_min_size          = 1
      eks_max_size          = 2
      rds_instance_class    = "db.t3.micro"
      rds_allocated_storage = 20
    }
    prod = {
      availability_zones    = 2
      instance_type         = "t3.large"
      eks_desired_size      = 2
      eks_min_size          = 2
      eks_max_size          = 4
      rds_instance_class    = "db.t3.small"
      rds_allocated_storage = 100
    }
  }
}
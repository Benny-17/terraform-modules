variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}
# variable "environment" {
#   description = "Environment name (dev/prod)"
#   type        = string
#   default = "dev"
# }

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

locals {
  config = {
    dev = {
      availability_zones = 1
      instance_type      = "t3.medium"
    }
    prod = {
      availability_zones = 2
      instance_type      = "t3.large"
    }
  }
}
# --------------------
## eks module-main.tf
# ----------------------

# locals {
#   config = {
#     dev = {
#       availability_zones   = 1
#       instance_type        = "t3.medium"
#       eks_desired_size     = 1
#     }
#     prod = {
#       availability_zones   = 2
#       instance_type        = "t3.large"
#       eks_desired_size     = 2
#     }
#   }
# }


# -------------------------
## rds variables
# -----------------------

# variable "rds_username" {
#   description = "RDS master username"
#   type        = string
#   sensitive   = true
#   default     = "admin"  # Store in tfvars file, not code!
# }

# variable "rds_password" {
#   description = "RDS master password"
#   type        = string
#   sensitive   = true
#   # DO NOT set default - use tfvars or environment variables
# }
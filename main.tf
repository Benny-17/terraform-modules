terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --------------------
## vpc module-main.tf
# ----------------------
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = terraform.workspace
  # environment = var.environment
  vpc_cidr             = var.vpc_cidr
  # availability_zones   = local.config[terraform.workspace].availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}


# --------------------
# # eks module-main.tf
# ----------------------
module "eks" {
  source = "./modules/eks"

  cluster_name       = "${var.project_name}-eks-${terraform.workspace}"
  environment        = terraform.workspace
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kubernetes_version = "1.34"
  project_name       = var.project_name
  
  # Workspace-specific sizing
  desired_size  = local.config[terraform.workspace].eks_desired_size
  instance_type = local.config[terraform.workspace].instance_type
  min_size = local.config[terraform.workspace].eks_min_size
  max_size = local.config[terraform.workspace].eks_max_size   
  depends_on = [module.vpc]
}

# --------------------
## rds module-main.tf
# ----------------------
module "rds" {
  source = "./modules/rds"

  db_name                      = var.db_name
  db_username                  = var.rds_username
  db_password                  = var.rds_password
  environment                  = terraform.workspace
  vpc_id                       = module.vpc.vpc_id
  private_subnet_ids           = module.vpc.private_subnet_ids
  eks_worker_security_group_id = module.eks.worker_security_group_id
  project_name                 = var.project_name

  # FREE TIER: Always use smallest instance + 20GB storage
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  multi_az          = false  # FREE TIER: single-AZ only

  depends_on = [module.eks]
}

# -------------------------
## alb
# ------------------------

module "alb" {
  source = "./modules/alb"

  project_name                 = var.project_name
  environment                  = terraform.workspace
  vpc_id                       = module.vpc.vpc_id
  public_subnet_ids            = module.vpc.public_subnet_ids
  eks_worker_security_group_id = module.eks.worker_security_group_id
  eks_cluster_name             = module.eks.cluster_name

  depends_on = [module.eks]
}
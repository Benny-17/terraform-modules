variable "db_name" {
  description = "Database name"
  type        = string
  default     = "testdb"
}

variable "db_username" {
  description = "Database admin username"
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "eks_worker_security_group_id" {
  description = "EKS worker security group ID"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "17.6"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}
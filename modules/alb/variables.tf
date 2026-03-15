variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "eks_worker_security_group_id" {
  description = "EKS worker security group ID"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}
# ------------
## vpc 
# -----------------
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# ------------
## alb 
# -----------------

output "alb_dns_name" {
  description = "ALB DNS name - use this to access your application"
  value       = module.alb.alb_dns_name
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.alb.alb_security_group_id
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = module.alb.target_group_arn
}
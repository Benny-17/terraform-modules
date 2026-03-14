output "alb_dns_name" {
  description = "DNS name of ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of ALB"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.eks.arn
}
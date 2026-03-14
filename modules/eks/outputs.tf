output "cluster_id" {
  value = aws_eks_cluster.main.id
}

output "cluster_arn" {
  value = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "worker_security_group_id" {
  value = aws_security_group.worker_nodes.id
}
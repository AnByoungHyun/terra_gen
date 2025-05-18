output "eks_cluster_id" {
  value = aws_eks_cluster.this.id
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "sg_id" {
  value = aws_security_group.eks.id
}

output "node_group_name" {
  value = aws_eks_node_group.default.node_group_name
}

output "node_role_arn" {
  value = var.node_role_arn
} 
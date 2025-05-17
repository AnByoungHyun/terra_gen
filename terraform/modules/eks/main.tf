resource "aws_security_group" "eks" {
  name        = "eks-cluster-sg"
  description = "EKSClusterSG"
  vpc_id      = var.vpc_id
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_role_arn
  version  = "1.30"
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.eks.id]
  }
}

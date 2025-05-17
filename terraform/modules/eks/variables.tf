variable "vpc_id" { description = "VPC ID" }
variable "cluster_name" { description = "EKS 클러스터 이름" }
variable "eks_role_arn" { description = "EKS 클러스터에 할당할 IAM Role ARN" }
variable "subnet_ids" { description = "EKS 클러스터에 연결할 서브넷 ID 목록" } 
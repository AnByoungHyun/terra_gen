variable "region" { default = "ap-northeast-1" }
variable "vpc_cidr" { default = "10.20.0.0/16" }
variable "private_subnet_cidrs" { default = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"] }
variable "public_subnet_cidr" { default = "10.20.10.0/24" }
variable "azs" { default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"] }
variable "cluster_name" { default = "my-eks-cluster" }
variable "eks_role_arn" { description = "EKS 클러스터에 할당할 IAM Role ARN" } 
variable "vpc_id" { description = "VPC ID" }
variable "cluster_name" { description = "EKS 클러스터 이름" }
variable "eks_role_arn" { description = "EKS 클러스터에 할당할 IAM Role ARN" }
variable "subnet_ids" { description = "EKS 클러스터에 연결할 서브넷 ID 목록" }
variable "node_group_name" { description = "EKS Node Group 이름" }
variable "node_role_arn" { description = "EKS Node Group에 할당할 IAM Role ARN" }
variable "node_instance_type" { description = "EKS 워커 노드 인스턴스 타입" default = "t3.medium" }
variable "node_desired_size" { description = "EKS Node Group의 기본 노드 수" default = 2 }
variable "node_max_size" { description = "EKS Node Group의 최대 노드 수" default = 3 }
variable "node_min_size" { description = "EKS Node Group의 최소 노드 수" default = 1 } 
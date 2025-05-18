provider "aws" {
  region = var.region
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

module "subnet" {
  source   = "./modules/subnet"
  vpc_id   = module.vpc.vpc_id
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidr   = var.public_subnet_cidr
  azs                  = var.azs
  public_route_table_id = module.vpc.public_route_table_id
}

module "natgw" {
  source         = "./modules/natgw"
  vpc_id         = module.vpc.vpc_id
  public_subnet_id = module.subnet.public_subnet_id
  private_subnet_ids = module.subnet.private_subnet_ids
}

module "eks" {
  source         = "./modules/eks"
  cluster_name   = var.cluster_name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.subnet.private_subnet_ids
  eks_role_arn   = var.eks_role_arn
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size
  node_min_size      = var.node_min_size
}

# --- VPC Peering 및 라우트 추가 ---

resource "aws_vpc_peering_connection" "eks_to_bastion" {
  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = var.bastion_vpc_id
  auto_accept   = true
  tags = {
    Name = "eks-to-bastion-peering"
  }
}

resource "aws_route" "to_bastion_vpc" {
  route_table_id            = var.bastion_route_table_id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_bastion.id
}

resource "aws_route" "to_eks_vpc" {
  route_table_id            = module.vpc.public_route_table_id
  destination_cidr_block    = var.bastion_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_bastion.id
}

resource "aws_vpc_peering_connection_options" "eks_to_bastion" {
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_bastion.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.subnet.private_subnet_ids }
output "public_subnet_id" { value = module.subnet.public_subnet_id }
output "natgw_id" { value = module.natgw.natgw_id }
output "eks_cluster_id" { value = module.eks.eks_cluster_id }
output "eks_cluster_endpoint" { value = module.eks.eks_cluster_endpoint } 
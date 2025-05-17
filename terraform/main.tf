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
}

output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.subnet.private_subnet_ids }
output "public_subnet_id" { value = module.subnet.public_subnet_id }
output "natgw_id" { value = module.natgw.natgw_id }
output "eks_cluster_id" { value = module.eks.eks_cluster_id }
output "eks_cluster_endpoint" { value = module.eks.eks_cluster_endpoint } 
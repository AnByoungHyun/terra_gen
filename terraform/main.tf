module "vpc" {
  source = "./modules/vpc"
  region = "ap-northeast-1"
  vpc_cidr = "10.20.0.0/16"
}

module "subnet" {
  source = "./modules/subnet"
  vpc_id = module.vpc.vpc_id
  region = "ap-northeast-1"
  private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  public_subnet_cidr = "10.20.10.0/24"
  azs = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

module "natgw" {
  source = "./modules/natgw"
  public_subnet_id = module.subnet.public_subnet_id
  region = "ap-northeast-1"
}

module "eks" {
  source = "./modules/eks"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.subnet.private_subnet_ids
  sg_id = module.vpc.eks_sg_id
  cluster_name = "my-eks-cluster"
  cluster_version = "1.30"
  eks_role_arn = "arn:aws:iam::626635419731:role/eksClusterRole"
  region = "ap-northeast-1"
}

output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.subnet.private_subnet_ids }
output "public_subnet_id" { value = module.subnet.public_subnet_id }
output "natgw_id" { value = module.natgw.natgw_id }
output "eks_cluster_id" { value = module.eks.eks_cluster_id }
output "eks_cluster_endpoint" { value = module.eks.eks_cluster_endpoint } 
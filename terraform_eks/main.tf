provider "aws" {
  region = var.region
  profile = "hyun-ssm"
}

variable "region" {
  default = "ap-northeast-1"
}

module "bestion" {
  source            = "./modules/bestion"
  vpc_cidr          = "10.30.0.0/16"
  public_subnet_cidr = "10.30.1.0/24"
  az                = "ap-northeast-1a"
  instance_type     = "t3.micro"
  name              = "bastion"
}

output "bastion_public_ip" {
  value = module.bestion.bastion_public_ip
}

output "bastion_instance_id" {
  value = module.bestion.bastion_instance_id
}

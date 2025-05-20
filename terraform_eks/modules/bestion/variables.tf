variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR 블록"
  type        = string
  default     = "10.30.1.0/24"
}

variable "az" {
  description = "가용 영역"
  type        = string
  default     = "ap-northeast-1a"
}

variable "instance_type" {
  description = "Bastion Host EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "name" {
  description = "Bastion Host 및 리소스 이름 접두어"
  type        = string
  default     = "bastion"
}

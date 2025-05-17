variable "public_subnet_id" { description = "퍼블릭 서브넷 ID" }
variable "vpc_id" { description = "VPC ID for NAT Gateway" }
variable "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  type        = list(string)
} 
variable "vpc_id" { description = "VPC ID" }
variable "private_subnet_cidrs" { description = "프라이빗 서브넷 CIDR 목록" }
variable "public_subnet_cidr" { description = "퍼블릭 서브넷 CIDR" }
variable "azs" { description = "가용 영역 목록" } 
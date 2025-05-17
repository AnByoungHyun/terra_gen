output "natgw_id" {
  value = aws_nat_gateway.this.id
}

output "eip_id" {
  value = aws_eip.this.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
} 
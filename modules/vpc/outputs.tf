output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "s3_prefix_list_id" {
  value = var.enable_vpc_endpoints ? aws_vpc_endpoint.s3[0].prefix_list_id : ""
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

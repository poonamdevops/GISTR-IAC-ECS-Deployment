output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

# ALB needs public subnets across 2 AZs.
output "public_subnet_ids" {
  value = [aws_subnet.public_primary.id, aws_subnet.public_secondary.id]
}

output "public_subnet_primary_id" {
  value = aws_subnet.public_primary.id
}

output "private_app_subnet_id" {
  value = aws_subnet.private_app.id
}

output "private_data_subnet_id" {
  value = aws_subnet.private_data.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}

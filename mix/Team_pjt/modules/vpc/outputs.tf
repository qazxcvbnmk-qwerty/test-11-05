output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = values(aws_subnet.public)[*].id
}

output "private_subnets" {
  value = values(aws_subnet.private)[*].id
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "nat_gw_id" {
  value = aws_nat_gateway.this.id
}

output "s3_endpoint_id" {
  description = "The ID of the S3 VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}


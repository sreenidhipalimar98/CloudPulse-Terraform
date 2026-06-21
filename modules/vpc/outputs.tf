output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

output "vpc_cidr" {
  value       = aws_vpc.main.cidr_block
  description = "CIDR block of the VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs of the private app subnets (where ECS tasks run)"
}

output "database_subnet_ids" {
  value       = aws_subnet.database[*].id
  description = "IDs of the isolated database subnets"
}

output "nat_gateway_ip" {
  value       = aws_eip.nat.public_ip
  description = "Public IP of the NAT gateway (useful for allowlisting outbound traffic)"
}

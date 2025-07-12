output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of IDs of private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of IDs of private database subnets"
  value       = aws_subnet.private_db[*].id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.availability_zones
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "List of IDs of private app route tables"
  value       = aws_route_table.private_app[*].id
}

output "private_db_route_table_ids" {
  description = "List of IDs of private db route tables"
  value       = aws_route_table.private_db[*].id
} 
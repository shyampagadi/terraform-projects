output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "Name of the database"
  value       = aws_db_instance.main.name
}

output "db_subnet_group_id" {
  description = "ID of the DB subnet group"
  value       = aws_db_subnet_group.main.id
}

output "db_parameter_group_id" {
  description = "ID of the DB parameter group"
  value       = aws_db_parameter_group.main.id
}

output "db_option_group_id" {
  description = "ID of the DB option group"
  value       = aws_db_option_group.main.id
}

output "db_secret_arn" {
  description = "ARN of the secrets manager secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_instance_resource_id" {
  description = "Resource ID of the RDS instance"
  value       = aws_db_instance.main.resource_id
} 
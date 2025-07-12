output "alb_security_group_id" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID of application security group"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID of database security group"
  value       = aws_security_group.db.id
}

output "bastion_security_group_id" {
  description = "ID of bastion security group"
  value       = var.create_bastion_sg ? aws_security_group.bastion[0].id : null
} 
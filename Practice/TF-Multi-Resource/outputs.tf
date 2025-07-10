output "subnet_id_0" {
  value = [aws_subnet.main[0].id]
}

output "subnet_id_1" {
  value = [aws_subnet.main[1].id]
}
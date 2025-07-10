output "aws_instance_ip_address" {
  value = aws_instance.firstec2.public_ip
}
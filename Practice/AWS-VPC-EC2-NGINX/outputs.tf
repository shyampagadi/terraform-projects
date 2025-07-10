output "IP-Address" {
  value = aws_instance.nginx-server.public_ip

}

output "url" {
  value = "https://${aws_instance.nginx-server.public_ip}/"
}
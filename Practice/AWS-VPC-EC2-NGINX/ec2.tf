resource "aws_instance" "nginx-server" {
  ami             = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.nginx-public-subnet.id
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum install -y nginx
              systemctl enable nginx
              systemctl start nginx
            EOF

  tags = {
    "Name"        = "nginx-server"
    "Environment" = "dev"
    "Project"     = "nginx-server"
    "Terraform"   = "true"
  }
}

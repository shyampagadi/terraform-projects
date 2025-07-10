terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# VPC
resource "aws_vpc" "nginx_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "nginx-vpc"
  }
}

# Subnet (public)
resource "aws_subnet" "nginx_subnet" {
  vpc_id                  = aws_vpc.nginx_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "nginx-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "nginx_igw" {
  vpc_id = aws_vpc.nginx_vpc.id
  tags = {
    Name = "nginx-igw"
  }
}

# Route Table
resource "aws_route_table" "nginx_rt" {
  vpc_id = aws_vpc.nginx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nginx_igw.id
  }

  tags = {
    Name = "nginx-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "nginx_assoc" {
  subnet_id      = aws_subnet.nginx_subnet.id
  route_table_id = aws_route_table.nginx_rt.id
}

# Security Group
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.nginx_vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting this to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-sg"
  }
}

# EC2 Instance
resource "aws_instance" "nginx_server" {
  ami                    = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (us-east-1)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.nginx_subnet.id
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl enable nginx
              systemctl start nginx
            EOF

  tags = {
    Name = "nginx-server"
  }
}

# Outputs
output "instance_public_ip" {
  value = aws_instance.nginx_server.public_ip
}

output "nginx_url" {
  value = "http://${aws_instance.nginx_server.public_ip}/"
}

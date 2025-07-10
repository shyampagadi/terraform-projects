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

data "aws_subnet" "data_aws_subnet" {
  filter{
  name = "tag:Name"
  values = ["AI-REC-PUBLIC-SUBNET"]
  }
}

output "subnet" {
  value = data.aws_subnet.data_aws_subnet.id
}

data "aws_security_group" "sg" {
  filter{
  name = "tag:Name"
  values = ["AI-REC-SG"]
  }
}

output "sg" {
  value = data.aws_security_group.sg.id
}

resource "aws_instance" "firstec2" {
  ami           =  "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id = data.aws_subnet.data_aws_subnet.id
  security_groups = [ data.aws_security_group.sg.id ]

  tags = {
    Name = "firstec2 - DEV"
  }
}

# resource "aws_vpc" "vpc" {
#   cidr_block = "10.0.0.0/16"

#   tags = {
#     Name = "AI-REC-VPC"
#   }
# }

# resource "aws_subnet" "public-subnet" {
#   vpc_id     = aws_vpc.vpc.id
#   cidr_block = "10.0.1.0/24"
#   depends_on = [aws_vpc.vpc]
#   tags = {
#     Name = "AI-REC-PUBLIC-SUBNET"
#   }
# }

# resource "aws_security_group" "ai-rec-sg" {
#   vpc_id      = aws_vpc.vpc.id
#   name        = "AI-REC-SG"
#   description = "Security group for AI-REC"
#   depends_on  = [aws_subnet.public-subnet]
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow HTTP"

#   }
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "Allow HTTPS"

#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     cidr_blocks = ["0.0.0.0/0"]
#     protocol    = "-1"
#     description = "Allow all outbound traffic"

#   }
#   tags = {
#     "Name" = "AI-REC-SG"
#   }

# }
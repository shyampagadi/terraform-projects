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

resource "aws_vpc" "myterra-aws_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name"       = "myterra-aws_vpc"
    "env"        = "dev"
    "created_by" = "terraform"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.myterra-aws_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    "Name"       = "public_subnet"
    "env"        = "dev"
    "created_by" = "terraform"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.myterra-aws_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    "Name"       = "private_subnet"
    "env"        = "dev"
    "created_by" = "terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myterra-aws_vpc.id
  tags = {
    "Name"       = "igw"
    "env"        = "dev"
    "created_by" = "terraform"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.myterra-aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }



  tags = {
    "Name"       = "public_route_table"
    "env"        = "dev"
    "created_by" = "terraform"
  }
}

resource "aws_route_table_association" "my_public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id

}

# resource "aws_route" "my_igw_route" {
#   route_table_id         = aws_route_table.public_route_table.id
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id             = aws_internet_gateway.igw.id
# }

resource "aws_instance" "nginx-server" {
  ami           = "ami-020cba7c55df1f615"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    "Name"       = "nginx-server"
    "env"        = "dev"
    "created_by" = "terraform"
  }

}
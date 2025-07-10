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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}



resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  count = 2

  cidr_block = "10.0.${count.index}.0/24"


  tags = {
    Name = var.subnet_name[count.index]
  }
}   
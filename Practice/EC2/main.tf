terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}

provider "aws" {
  region = var.region
  profile = "default"
}

resource "aws_instance" "firstec2" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id = var.subnet_id

  tags = {
    Name = "firstec2 - DEV"
  }
}
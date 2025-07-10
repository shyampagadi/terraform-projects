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

resource "aws_instance" "test-instance" {
  ami           = "ami-020cba7c55df1f615"
  instance_type = var.instance_type

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_size           = var.root_block_device.v_size
    volume_type           = var.root_block_device.v_type
  }
  tags = merge(var.additional_tags, {
    Name = "test-instance"
  })

}
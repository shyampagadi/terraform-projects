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

resource "random_id" "random_name" {
    byte_length = 8  
}

resource "aws_s3_bucket" "mys3bucket" {
    bucket = "terraformmybucket-${random_id.random_name.hex}"
    
}

resource "aws_s3_object" "bucket-data" {
    bucket = aws_s3_bucket.mys3bucket.bucket
    key = "data.txt"
    source = "./myfile.txt"  
}

output "aws_s3_bucket_name" {
  value = aws_s3_bucket.mys3bucket.bucket
}
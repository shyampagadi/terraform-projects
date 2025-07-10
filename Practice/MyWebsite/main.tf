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

resource "random_id" "rand_num" {
  byte_length = 8
}

resource "aws_s3_bucket" "mywebsite-bucket" {
  bucket = "mywebsite-bucket-${random_id.rand_num.hex}"

}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.mywebsite-bucket.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
 }

resource "aws_s3_object" "index_css" {
  bucket       = aws_s3_bucket.mywebsite-bucket.id
  key          = "index.css"
  source       = "index.css"
  content_type = "text/css"
 }

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.mywebsite-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "mywebsite_policy" {
  bucket = aws_s3_bucket.mywebsite-bucket.id
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Sid       = "PublicReadGetObject",
          Effect    = "Allow",
          Principal = "*",
          Action    = "s3:GetObject",
          Resource  = "arn:aws:s3:::${aws_s3_bucket.mywebsite-bucket.id}/*"

        }
      ]
    }
  )
}

resource "aws_s3_bucket_website_configuration" "mywebsite_conf" {
  bucket = aws_s3_bucket.mywebsite-bucket.id

  index_document {
    suffix = "index.html"
  }

}

output "aws_s3_bucket" {
  value = aws_s3_bucket.mywebsite-bucket.bucket
}

output "mywebsite_endpoint" {
  value = aws_s3_bucket_website_configuration.mywebsite_conf.website_endpoint
} 
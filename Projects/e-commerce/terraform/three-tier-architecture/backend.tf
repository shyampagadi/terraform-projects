terraform {
  backend "s3" {
    bucket         = "e-commerce-terraform-state"
    key            = "three-tier/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
} 
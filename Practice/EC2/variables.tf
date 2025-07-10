variable "region" {
  description = "Aws Region"
  default = "us-east-1"
  type = string
}

variable "ami" {
    default = "ami-020cba7c55df1f615"
    type = string
    description = "AMI of EC2"  
}

variable "instance_type" {
    default = "t2.micro"
    type = string
    description = "Instance type of EC2"
}
  
variable "subnet_id" {
    default = "subnet-0a0e867a2fb6dab18"
    type = string
    description = "Subnet ID of EC2"
}
  

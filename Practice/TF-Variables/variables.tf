variable "instance_type" {
  description = "What type of instance type you want to create"
  type        = string
  validation {
    condition     = var.instance_type == "t2.micro" || var.instance_type == "t3.micro"
    error_message = "You can only create t2.micro or t3.micro instancetype"
  }
}

# variable "volume_size" {
#   type        = number
#   description = "Volume size of the instance"
#   default     = 15
# }

# variable "volume_type" {
#   type        = string
#   description = "Volume type of the instance"
#   default     = "gp3"
# }

variable "root_block_device" {
  type = object({
    v_size = number
    v_type = string
  })
  default = {
    v_size = 15
    v_type = "gp3"
  }
}

variable "additional_tags" {
  type = map(string)
  default = {
    "Owner" = "Sai"
    "Env"   = "Dev"
  }
}
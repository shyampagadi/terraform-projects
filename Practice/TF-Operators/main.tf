terraform {}

variable "num" {
  type = list(number)
  default = [ 1,2,3,4,5 ]
}

variable "person" {
  type = list(object({
    fname = string
    lname = string
  }))
  default = [
    { fname = "John", lname = "Doe" },
    { fname = "Jane", lname = "Doe" }
  ]     
}

variable "map_list" {
  type = map(number)
  default = {
    "one" = 1
    "two" = 2
    "three" = 3
    "four" = 4
    "five" = 5
  }
}

locals {
  print_list = [for i in var.num: i ]
  print_list_object = [for i in var.person: i.fname ]
  print_map = {for k,v in var.map_list: k => v }
}

output "print_list" {
  value = local.print_list
}

output "print_list_object" {
  value = local.print_list_object
}

output "map_list" {
  value = local.print_map
}
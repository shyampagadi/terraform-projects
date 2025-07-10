instance_type = "t2.micro"
root_block_device = {
  v_size = 10
  v_type = "gp2"
}

additional_tags = {
  "ENV" = "QA"
  "PROJECT" = "AI"
}
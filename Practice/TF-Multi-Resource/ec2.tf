locals {
  project = "project01"
}

resource "aws_instance" "main" {
  ami = "ami-020cba7c55df1f615"
  instance_type = "t3.micro"
  count = 4
  subnet_id = element(aws_subnet.main[*].id, count.index % length(aws_subnet.main))

  tags = {
    Name = "${local.project} - instance - ${count.index}"
  }
}


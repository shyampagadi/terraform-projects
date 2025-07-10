resource "aws_security_group" "nginx-sg" {
  vpc_id      = aws_vpc.nginx-vpc.id
  name        = "nginx-sg"
  description = "Security group for nginx web server"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "nginx-sg"

  }
}
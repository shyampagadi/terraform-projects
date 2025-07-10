resource "aws_vpc" "nginx-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "nginx-vpc"
  }
}

resource "aws_subnet" "nginx-public-subnet" {
  vpc_id            = aws_vpc.nginx-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "nginx-public-subnet"
  }
}

resource "aws_subnet" "nginx-private_subnet" {
  vpc_id            = aws_vpc.nginx-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "nginx-private-subnet"
  }

}

resource "aws_internet_gateway" "nginx-igw" {
  vpc_id = aws_vpc.nginx-vpc.id
  tags = {
    Name = "nginx-igw"
  }
}

resource "aws_route_table" "nginx-public-rt" {
  vpc_id = aws_vpc.nginx-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nginx-igw.id
  }
  tags = {
    Name = "nginx-public-rt"
  }
}

resource "aws_route_table_association" "public-rt-association" {
  subnet_id      = aws_subnet.nginx-public-subnet.id
  route_table_id = aws_route_table.nginx-public-rt.id
} 
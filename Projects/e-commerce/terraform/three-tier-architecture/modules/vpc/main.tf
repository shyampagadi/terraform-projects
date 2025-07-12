locals {
  availability_zones = ["${var.region}a", "${var.region}b", "${var.region}c"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-vpc"
    }
  )
}

# Public subnets
resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-public-${local.availability_zones[count.index]}"
      Tier = "Public"
    }
  )
}

# Application (Private) subnets
resource "aws_subnet" "private_app" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(local.availability_zones))
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-private-app-${local.availability_zones[count.index]}"
      Tier = "Private"
    }
  )
}

# Database (Isolated) subnets
resource "aws_subnet" "private_db" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2 * length(local.availability_zones))
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-private-db-${local.availability_zones[count.index]}"
      Tier = "Database"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-igw"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(local.availability_zones)

  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-eip-${local.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = length(local.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-nat-${local.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-rt-public"
    }
  )
}

# Private App Route Tables (one per AZ)
resource "aws_route_table" "private_app" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-rt-private-app-${local.availability_zones[count.index]}"
    }
  )
}

# Private DB Route Tables (one per AZ)
resource "aws_route_table" "private_db" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-rt-private-db-${local.availability_zones[count.index]}"
    }
  )
}

# Public Subnet Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private App Subnet Route Table Associations
resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Private DB Subnet Route Table Associations
resource "aws_route_table_association" "private_db" {
  count = length(aws_subnet.private_db)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

# VPC Flow Logs
resource "aws_flow_log" "vpc_flow_log" {
  iam_role_arn    = var.flow_log_role_arn
  log_destination = var.flow_log_destination
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-vpc-flow-log"
    }
  )
} 
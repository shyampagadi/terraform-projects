# AWS 3-Tier Architecture Deployment Guide - Part 2
# VPC and Networking Infrastructure

## VPC Design

A well-designed Virtual Private Cloud (VPC) is the foundation of a secure and scalable AWS architecture. We'll create a VPC with public and private subnets across multiple Availability Zones.

### VPC Components

- **VPC CIDR Block**: 10.0.0.0/16 (65,536 IP addresses)
- **Availability Zones**: 3 AZs for high availability
- **Subnets**:
  - Public subnets (for ALB, NAT Gateways): 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  - Private subnets for Web tier: 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  - Private subnets for App tier: 10.0.20.0/24, 10.0.21.0/24, 10.0.22.0/24
  - Private subnets for Data tier: 10.0.30.0/24, 10.0.31.0/24, 10.0.32.0/24
- **Internet Gateway**: For public internet access
- **NAT Gateways**: For private subnets to access the internet
- **Route Tables**: Separate route tables for public and private subnets

## Terraform Configuration for VPC

Let's create the Terraform configuration for our VPC:

### Directory Structure

```
terraform/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ...
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
└── backend.tf
```

### VPC Module

```hcl
# terraform/modules/vpc/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "web_subnet_cidrs" {
  description = "CIDR blocks for web tier subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks for app tier subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data tier subnets"
  type        = list(string)
  default     = ["10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24"]
}
```

```hcl
# terraform/modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "public"
  }
}

# Web Tier Subnets
resource "aws_subnet" "web" {
  count                   = length(var.web_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.web_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-web-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "web"
  }
}

# App Tier Subnets
resource "aws_subnet" "app" {
  count                   = length(var.app_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-app-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "app"
  }
}

# Data Tier Subnets
resource "aws_subnet" "data" {
  count                   = length(var.data_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.data_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.environment}-data-subnet-${count.index + 1}"
    Environment = var.environment
    Tier        = "data"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.environment}-nat-gateway-${count.index + 1}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name        = "${var.environment}-private-route-table-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "web" {
  count          = length(var.web_subnet_cidrs)
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "app" {
  count          = length(var.app_subnet_cidrs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "data" {
  count          = length(var.data_subnet_cidrs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

```hcl
# terraform/modules/vpc/outputs.tf
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "web_subnet_ids" {
  description = "List of web tier subnet IDs"
  value       = aws_subnet.web[*].id
}

output "app_subnet_ids" {
  description = "List of app tier subnet IDs"
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "List of data tier subnet IDs"
  value       = aws_subnet.data[*].id
}
```

## Security Groups

Security groups act as virtual firewalls for your instances to control inbound and outbound traffic. We'll create separate security groups for each tier:

```hcl
# terraform/modules/vpc/main.tf (continued)

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# Web Tier Security Group
resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Security group for web tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow HTTP from ALB"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow HTTPS from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-web-sg"
    Environment = var.environment
  }
}

# App Tier Security Group
resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Security group for application tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
    description     = "Allow traffic from web tier"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-app-sg"
    Environment = var.environment
  }
}

# Data Tier Security Group
resource "aws_security_group" "data" {
  name        = "${var.environment}-data-sg"
  description = "Security group for data tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Allow PostgreSQL from app tier"
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Allow Redis from app tier"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-data-sg"
    Environment = var.environment
  }
}
```

## Network ACLs (NACLs)

Network ACLs provide an additional layer of security at the subnet level:

```hcl
# terraform/modules/vpc/main.tf (continued)

# Public Subnet NACL
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow all inbound HTTP traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow all inbound HTTPS traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${var.environment}-public-nacl"
    Environment = var.environment
  }
}

# Private Subnet NACLs follow similar patterns but with more restrictive rules
```

## Environment Configuration

Now let's create the environment-specific configuration:

```hcl
# terraform/environments/prod/main.tf
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../modules/vpc"
  
  environment        = "prod"
  vpc_cidr           = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  web_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  app_subnet_cidrs    = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
  data_subnet_cidrs   = ["10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24"]
}

# Output the VPC and subnet IDs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "web_subnet_ids" {
  value = module.vpc.web_subnet_ids
}

output "app_subnet_ids" {
  value = module.vpc.app_subnet_ids
}

output "data_subnet_ids" {
  value = module.vpc.data_subnet_ids
}
```

## Terraform Backend Configuration

For state management, we'll use an S3 backend with DynamoDB for state locking:

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "ecommerce-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

## Deployment Steps

1. Create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket ecommerce-terraform-state \
  --region us-east-1

# Enable versioning on the S3 bucket
aws s3api put-bucket-versioning \
  --bucket ecommerce-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

2. Initialize and apply the Terraform configuration:

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

## Networking Best Practices

1. **Use Multiple Availability Zones**: Deploy resources across at least three AZs for high availability.

2. **Implement Defense in Depth**: Use security groups, NACLs, and WAF for layered security.

3. **Restrict Access**: Follow the principle of least privilege for all network components.

4. **Enable VPC Flow Logs**: Monitor network traffic for security analysis and troubleshooting.

5. **Use Private Subnets**: Place sensitive resources in private subnets without direct internet access.

6. **Implement Transit Gateway**: For complex networks with multiple VPCs, use Transit Gateway for centralized connectivity.

In the next part, we will cover the setup of the Web Tier with Auto Scaling, Application Load Balancer, and CloudFront. 
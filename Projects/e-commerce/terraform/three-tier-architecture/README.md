# Three-Tier Architecture Infrastructure

This directory contains Terraform configurations for deploying a three-tier architecture on AWS with the following components:

- VPC with public and private subnets across multiple Availability Zones
- Application Load Balancer (ALB) in public subnets
- Auto Scaling Group for application servers in private subnets
- RDS database in isolated private subnets
- Security groups with least privilege access
- Multi-environment support (DEV, UAT, PROD)

## Directory Structure

- `modules/`: Reusable Terraform modules
  - `vpc/`: VPC, subnets, route tables, NAT gateways
  - `alb/`: Application Load Balancer configuration
  - `autoscaling/`: EC2 Auto Scaling Group
  - `rds/`: Database tier configuration
  - `security/`: Security groups and IAM roles
- `environments/`: Environment-specific configurations
  - `dev/`: Development environment
  - `uat/`: User Acceptance Testing environment
  - `prod/`: Production environment

## Best Practices Implemented

- Modular architecture for reusability
- State management with remote backend (S3 with DynamoDB locking)
- IAM roles with least privilege
- Security groups with restrictive access
- Multi-AZ deployment for high availability
- Infrastructure tagging for resource management
- Secrets management (no hardcoded credentials)
- Consistent naming conventions 
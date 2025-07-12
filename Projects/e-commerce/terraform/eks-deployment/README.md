# EKS Deployment Infrastructure

This directory contains Terraform configurations for deploying an e-commerce application on Amazon EKS (Elastic Kubernetes Service) with the following components:

- VPC with public and private subnets across multiple Availability Zones
- EKS cluster with managed node groups
- Application Load Balancer (ALB) controller for ingress
- Auto Scaling for Kubernetes workloads
- RDS database for persistent storage
- Multi-environment support (DEV, UAT, PROD)

## Directory Structure

- `modules/`: Reusable Terraform modules
  - `vpc/`: VPC and networking components
  - `eks/`: EKS cluster configuration
  - `nodes/`: EKS node groups configuration
  - `addons/`: EKS add-ons (ALB Ingress Controller, Cluster Autoscaler)
  - `rds/`: Database tier configuration
  - `security/`: Security groups and IAM roles
- `environments/`: Environment-specific configurations
  - `dev/`: Development environment
  - `uat/`: User Acceptance Testing environment
  - `prod/`: Production environment
- `kubernetes/`: Kubernetes manifests for application deployment
  - `frontend/`: Frontend tier manifests
  - `backend/`: Backend tier manifests
  - `database/`: Database connection configurations

## Best Practices Implemented

- Modular architecture for reusability
- State management with remote backend (S3 with DynamoDB locking)
- IAM roles with least privilege
- EKS security best practices
- Multi-AZ deployment for high availability
- Infrastructure tagging for resource management
- Secrets management with AWS Secrets Manager and Kubernetes Secrets
- Consistent naming conventions 
# E-Commerce Infrastructure

This repository contains Terraform scripts for deploying the infrastructure for an e-commerce application in AWS. Two deployment options are provided:

1. **Three-Tier Architecture**: Traditional architecture with ALB, Auto Scaling Group, and RDS
2. **EKS Deployment**: Kubernetes-based deployment on Amazon EKS

## Directory Structure

```
terraform/
├── three-tier-architecture/    # Traditional three-tier architecture
│   ├── modules/                # Reusable modules
│   │   ├── vpc/                # VPC and network configuration
│   │   ├── alb/                # Application Load Balancer
│   │   ├── autoscaling/        # EC2 Auto Scaling Group
│   │   ├── rds/                # RDS database
│   │   └── security/           # Security groups and IAM roles
│   ├── environments/           # Environment-specific configurations
│   │   ├── dev/                # Development environment
│   │   ├── uat/                # User Acceptance Testing environment
│   │   └── prod/               # Production environment
│   └── scripts/                # Deployment scripts
│       └── user_data.sh.tpl    # EC2 instance initialization template
├── eks-deployment/             # Kubernetes-based deployment
│   ├── modules/                # Reusable modules
│   │   ├── vpc/                # VPC and network configuration
│   │   ├── eks/                # EKS cluster
│   │   ├── nodes/              # EKS node groups
│   │   ├── addons/             # EKS add-ons (ALB Controller, etc.)
│   │   ├── rds/                # RDS database
│   │   └── security/           # Security groups and IAM roles
│   ├── environments/           # Environment-specific configurations
│   │   ├── dev/                # Development environment
│   │   ├── uat/                # User Acceptance Testing environment
│   │   └── prod/               # Production environment
│   └── kubernetes/             # Kubernetes manifests
│       ├── frontend/           # Frontend tier manifests
│       ├── backend/            # Backend tier manifests
│       └── database/           # Database connection configurations
└── README.md                   # This file
```

## Prerequisites

- Terraform v1.0.0+
- AWS CLI configured with appropriate permissions
- S3 bucket for Terraform state (already created)
- DynamoDB table for state locking (already created)

## Three-Tier Architecture

The three-tier architecture provides a traditional deployment model with:

- VPC with public and private subnets across multiple AZs
- Application Load Balancer in public subnets
- Auto Scaling Group for application servers in private subnets
- RDS database in isolated private subnets

### Deployment

```bash
cd terraform/three-tier-architecture/environments/dev
terraform init
terraform plan
terraform apply
```

## EKS Deployment

The EKS deployment provides a Kubernetes-based infrastructure with:

- VPC with public and private subnets across multiple AZs
- EKS cluster with managed node groups
- Application Load Balancer (ALB) controller for ingress
- Auto Scaling for Kubernetes workloads

### Deployment

```bash
cd terraform/eks-deployment/environments/dev
terraform init
terraform plan
terraform apply
```

After applying the Terraform scripts, you'll need to configure kubectl to connect to your EKS cluster:

```bash
aws eks update-kubeconfig --name dev-ecommerce --region us-east-1
```

Then deploy the Kubernetes manifests:

```bash
# Replace placeholder variables in the manifests
envsubst < kubernetes/frontend/deployment.yaml | kubectl apply -f -
kubectl apply -f kubernetes/frontend/service.yaml
envsubst < kubernetes/frontend/ingress.yaml | kubectl apply -f -
```

## Best Practices Implemented

- **Modular Design**: Reusable modules for each component
- **Environment Separation**: Separate configurations for dev, UAT, and production
- **Security**: Least privilege IAM roles, secure networking, encryption at rest and in transit
- **High Availability**: Multi-AZ deployments, auto-scaling groups
- **Monitoring and Logging**: CloudWatch integrations, alarms for critical resources
- **Infrastructure as Code**: Entire infrastructure defined as code with Terraform
- **Secret Management**: Secure storage of credentials using AWS Secrets Manager
- **Cost Optimization**: Right-sizing of resources, auto-scaling based on demand

## Notes

- The S3 backend configuration assumes you have an S3 bucket named `e-commerce-terraform-state` and a DynamoDB table called `terraform-state-lock` already created.
- For production deployments, review and adjust security parameters, instance sizes, and high availability settings.
- For Kubernetes manifests, replace the placeholder variables with actual values before applying. 
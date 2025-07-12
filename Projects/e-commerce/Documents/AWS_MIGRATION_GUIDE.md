# AWS Migration & Deployment Guide for ShopSmart E-commerce Application

This document outlines the complete process to migrate your on-premises e-commerce application to AWS infrastructure.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Preparation with Terraform](#infrastructure-preparation-with-terraform)
4. [Database Migration to Aurora PostgreSQL](#database-migration-to-aurora-postgresql)
5. [Application Containerization](#application-containerization)
6. [EKS Cluster Deployment](#eks-cluster-deployment)
7. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
8. [DNS Configuration and SSL](#dns-configuration-and-ssl)
9. [Monitoring and Alerting](#monitoring-and-alerting)
10. [Backup and Disaster Recovery](#backup-and-disaster-recovery)
11. [Cost Optimization](#cost-optimization)
12. [Security Best Practices](#security-best-practices)

---

## Architecture Overview

The AWS architecture will consist of:

- **Compute**: Amazon EKS (Elastic Kubernetes Service) for container orchestration
- **Database**: Aurora PostgreSQL Serverless for optimal cost/performance
- **Storage**: S3 buckets for static assets and backups
- **Networking**: VPC with public/private subnets across multiple AZs
- **Security**: AWS WAF, Security Groups, KMS encryption
- **CI/CD**: AWS CodePipeline with GitHub integration
- **DNS & CDN**: Route 53 and CloudFront
- **Monitoring**: CloudWatch, Prometheus, and Grafana

![AWS Architecture Diagram](https://i.imgur.com/placeholder.png)

---

## Prerequisites

Before beginning migration, ensure you have:

1. **AWS Account Setup**:
   - Create an AWS account if you don't have one
   - Set up IAM users with appropriate permissions
   - Enable MFA for root and administrative users

2. **Local Development Tools**:
   - AWS CLI installed and configured (`aws configure`)
   - Terraform CLI (version 1.0+)
   - Docker (version 20.10+)
   - kubectl (version 1.24+)
   - eksctl (latest version)
   - PostgreSQL client tools

3. **Access and Credentials**:
   - Generate and safely store AWS access keys
   - Document all current database credentials
   - Gather SSL certificates if any

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

---

## Infrastructure Preparation with Terraform

### 1. Set up Terraform Project Structure

Create the following directory structure:

```
terraform/
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── aurora/
│   ├── s3/
│   └── cloudfront/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
└── variables.tf
```

### 2. Create VPC and Network Resources

```hcl
# terraform/modules/vpc/main.tf
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"
  
  name = "ecommerce-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true
  
  tags = {
    Environment = var.environment
    Project     = "ecommerce"
    Terraform   = "true"
  }
}
```

### 3. Create Aurora PostgreSQL Serverless Configuration

```hcl
# terraform/modules/aurora/main.tf
resource "aws_rds_cluster" "aurora_postgres" {
  cluster_identifier      = "ecommerce-${var.environment}"
  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  database_name           = "ecommerce"
  master_username         = var.db_username
  master_password         = var.db_password
  backup_retention_period = 7
  preferred_backup_window = "07:00-09:00"
  
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 4
    min_capacity             = 1
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  
  vpc_security_group_ids = [aws_security_group.aurora_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.aurora_subnet_group.name
  
  tags = {
    Environment = var.environment
    Project     = "ecommerce"
  }
}
```

### 4. Set up EKS Cluster Configuration

```hcl
# terraform/modules/eks/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"
  
  cluster_name    = "ecommerce-${var.environment}"
  cluster_version = "1.24"
  
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids
  
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  
  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 5
      desired_size = 2
      
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
  
  tags = {
    Environment = var.environment
    Project     = "ecommerce"
  }
}
```

### 5. Create Main Terraform Configuration

```hcl
# terraform/environments/production/main.tf
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../modules/vpc"
  environment = "production"
}

module "aurora" {
  source = "../../modules/aurora"
  environment = "production"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  db_username = var.db_username
  db_password = var.db_password
}

module "eks" {
  source = "../../modules/eks"
  environment = "production"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
}
```

### 6. Apply Terraform Configuration

```bash
cd terraform/environments/production
terraform init
terraform plan
terraform apply
```

---

## Database Migration to Aurora PostgreSQL

### 1. Export On-Premises Database

```bash
# Create a database dump
pg_dump -h localhost -U postgres -d ecommerce -F c -b -v -f ecommerce_backup.dump

# Upload the dump to S3
aws s3 cp ecommerce_backup.dump s3://your-migration-bucket/
```

### 2. Create Aurora PostgreSQL Database Schema

```bash
# Get the Aurora cluster endpoint
AURORA_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier ecommerce-production \
  --query "DBClusters[0].Endpoint" \
  --output text)

# Create the same schema in Aurora
psql -h $AURORA_ENDPOINT -U postgres -d postgres -c "CREATE DATABASE ecommerce;"
```

### 3. Import Data to Aurora

```bash
# Download the dump from S3
aws s3 cp s3://your-migration-bucket/ecommerce_backup.dump .

# Restore the dump to Aurora
pg_restore -h $AURORA_ENDPOINT -U postgres -d ecommerce -v ecommerce_backup.dump
```

### 4. Verify Data Migration

```bash
# Connect to Aurora and verify data
psql -h $AURORA_ENDPOINT -U postgres -d ecommerce

# Run verification queries
SELECT count(*) FROM products;
SELECT count(*) FROM users;
```

### 5. Update Application Connection String

Update the `.env` file in your application to use the Aurora endpoint:

```
DB_HOST=ecommerce-production.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com
DB_NAME=ecommerce
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_PORT=5432
```

---

## Application Containerization

### 1. Create Dockerfiles for Backend and Frontend

**Backend Dockerfile**:

```dockerfile
# ./Projects/e-commerce/backend/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "main.py"]
```

**Frontend Dockerfile**:

```dockerfile
# ./Projects/e-commerce/frontend/Dockerfile
FROM node:16-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Nginx configuration**:

```
# ./Projects/e-commerce/frontend/nginx.conf
server {
    listen 80;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://backend:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. Create Docker Compose for Local Testing

```yaml
# ./Projects/e-commerce/docker-compose.yml
version: '3'

services:
  postgres:
    image: postgres:13
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=admin
      - POSTGRES_DB=ecommerce
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
      
  backend:
    build: ./backend
    depends_on:
      - postgres
    environment:
      - DB_HOST=postgres
      - DB_NAME=ecommerce
      - DB_USER=postgres
      - DB_PASSWORD=admin
      - DB_PORT=5432
    ports:
      - "8000:8000"
      
  frontend:
    build: ./frontend
    ports:
      - "80:80"
    depends_on:
      - backend

volumes:
  postgres_data:
```

### 3. Build and Test Docker Images

```bash
# Build and test locally
cd Projects/e-commerce
docker-compose up --build

# Ensure the application works correctly
curl http://localhost:8000/health
curl http://localhost/
```

### 4. Set Up AWS ECR Repositories

```bash
# Create ECR repositories for backend and frontend
aws ecr create-repository --repository-name ecommerce/backend
aws ecr create-repository --repository-name ecommerce/frontend

# Get the ECR repository URLs
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
BACKEND_REPO=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ecommerce/backend
FRONTEND_REPO=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/ecommerce/frontend
```

### 5. Push Docker Images to ECR

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag and push backend image
docker tag ecommerce-backend:latest $BACKEND_REPO:latest
docker push $BACKEND_REPO:latest

# Tag and push frontend image
docker tag ecommerce-frontend:latest $FRONTEND_REPO:latest
docker push $FRONTEND_REPO:latest
```

---

## EKS Cluster Deployment

### 1. Configure kubectl for EKS

```bash
# Update kubeconfig to connect to your EKS cluster
aws eks update-kubeconfig --name ecommerce-production --region us-east-1

# Verify connection
kubectl get nodes
```

### 2. Create Kubernetes Namespace

```bash
kubectl create namespace ecommerce
```

### 3. Create Kubernetes Secrets for Database

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=postgres \
  --from-literal=password=your_secure_password \
  --namespace ecommerce
```

### 4. Create ConfigMaps for Application Configuration

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: ecommerce
data:
  DB_HOST: "ecommerce-production.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
  DB_NAME: "ecommerce"
  DB_PORT: "5432"
  API_HOST: "0.0.0.0"
  API_PORT: "8000"
  DEBUG: "False"
```

```bash
kubectl apply -f configmap.yaml
```

### 5. Deploy Backend Service

```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/ecommerce/backend:latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: backend-config
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "200m"
            memory: "256Mi"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

```yaml
# backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: ecommerce
spec:
  selector:
    app: backend
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP
```

### 6. Deploy Frontend Service

```yaml
# frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/ecommerce/frontend:latest
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "300m"
            memory: "256Mi"
          requests:
            cpu: "100m"
            memory: "128Mi"
```

```yaml
# frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: ecommerce
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 7. Create Ingress Controller and Rules

```bash
# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ecommerce-production \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: ecommerce
  annotations:
    kubernetes.io/ingress.class: "alb"
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

### 8. Apply Kubernetes Configurations

```bash
# Apply all configs
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml
kubectl apply -f ingress.yaml

# Verify the deployments
kubectl get pods -n ecommerce
kubectl get services -n ecommerce
kubectl get ingress -n ecommerce
```

---

## CI/CD Pipeline Setup

### 1. Create a CodeBuild Project for Backend

```yaml
# buildspec-backend.yml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/ecommerce/backend
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - cd backend
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - aws eks update-kubeconfig --name ecommerce-production --region $AWS_DEFAULT_REGION
      - kubectl set image deployment/backend backend=$REPOSITORY_URI:$IMAGE_TAG -n ecommerce
      - kubectl rollout status deployment/backend -n ecommerce
```

### 2. Create a CodeBuild Project for Frontend

```yaml
# buildspec-frontend.yml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/ecommerce/frontend
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - cd frontend
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - aws eks update-kubeconfig --name ecommerce-production --region $AWS_DEFAULT_REGION
      - kubectl set image deployment/frontend frontend=$REPOSITORY_URI:$IMAGE_TAG -n ecommerce
      - kubectl rollout status deployment/frontend -n ecommerce
```

### 3. Set Up AWS CodePipeline

1. Create a pipeline in the AWS Console:
   - Connect to your GitHub repository
   - Configure source stage for GitHub repo
   - Add a build stage for Backend using the buildspec-backend.yml
   - Add a build stage for Frontend using the buildspec-frontend.yml

2. Set up webhook to automatically trigger the pipeline on code push

### 4. IAM Roles Setup

Ensure the CodeBuild service role has these permissions:
- ECR full access
- EKS cluster access
- S3 read/write access

---

## DNS Configuration and SSL

### 1. Register Domain or Use Existing Domain in Route 53

```bash
# Create a hosted zone if needed
aws route53 create-hosted-zone --name yourdomain.com --caller-reference $(date +%s)
```

### 2. Request SSL Certificate in ACM

```bash
# Request public certificate
aws acm request-certificate \
  --domain-name yourdomain.com \
  --validation-method DNS \
  --subject-alternative-names www.yourdomain.com
```

### 3. Configure DNS Records

After creating the ALB from the Ingress controller, get its DNS name:

```bash
ALB_DNS=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route 53 alias record
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "yourdomain.com",
          "Type": "A",
          "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K",
            "DNSName": "'$ALB_DNS'",
            "EvaluateTargetHealth": true
          }
        }
      },
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "www.yourdomain.com",
          "Type": "A",
          "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K",
            "DNSName": "'$ALB_DNS'",
            "EvaluateTargetHealth": true
          }
        }
      }
    ]
  }'
```

### 4. Update Ingress to Use Certificate

```yaml
# Update ingress.yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/certificate-id
```

---

## Monitoring and Alerting

### 1. Set Up CloudWatch Container Insights

```bash
# Install CloudWatch agent
ClusterName=ecommerce-production
RegionName=us-east-1
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-serviceaccount.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-configmap.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml
```

### 2. Deploy Prometheus and Grafana

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace

# Install Grafana
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set service.type=LoadBalancer
```

### 3. Configure CloudWatch Alarms

```bash
# Create CPU utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name ecommerce-backend-high-cpu \
  --alarm-description "High CPU utilization for backend service" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=ecommerce-production Name=ServiceName,Value=backend \
  --evaluation-periods 3 \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:ecommerce-alerts
```

---

## Backup and Disaster Recovery

### 1. Configure Aurora Automated Backups

```terraform
# Update Aurora module in terraform
resource "aws_rds_cluster" "aurora_postgres" {
  # ... other configurations
  backup_retention_period = 14  # Keep backups for 14 days
  preferred_backup_window = "07:00-09:00"
  copy_tags_to_snapshot = true
  deletion_protection = true
}
```

### 2. Set Up Aurora Snapshots

```bash
# Create a manual snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier ecommerce-production \
  --db-cluster-snapshot-identifier ecommerce-migration-snapshot

# List available snapshots
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier ecommerce-production
```

### 3. Configure S3 Lifecycle Policy for Backups

```terraform
# terraform/modules/s3/main.tf
resource "aws_s3_bucket" "backup_bucket" {
  bucket = "ecommerce-backups-${var.environment}"
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    id = "backup-retention"
    status = "Enabled"

    transition {
      days = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}
```

---

## Cost Optimization

### 1. Configure Aurora Serverless Auto Scaling

```terraform
resource "aws_rds_cluster" "aurora_postgres" {
  # ... other configurations
  
  scaling_configuration {
    auto_pause               = true
    max_capacity             = 4
    min_capacity             = 1
    seconds_until_auto_pause = 300
  }
}
```

### 2. Set Up EKS Cluster Autoscaler

```bash
# Install Cluster Autoscaler
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=ecommerce-production \
  --set awsRegion=us-east-1 \
  --set rbac.create=true
```

### 3. Configure Horizontal Pod Autoscaler for Services

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: ecommerce
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

```bash
kubectl apply -f hpa.yaml
```

---

## Security Best Practices

### 1. Implement Network Security Groups

```terraform
# Security group for Aurora
resource "aws_security_group" "aurora_sg" {
  name        = "aurora-sg-${var.environment}"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_security_group_id]
    description     = "Allow PostgreSQL from EKS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 2. Set Up AWS WAF for API Protection

```terraform
resource "aws_wafv2_web_acl" "ecommerce_waf" {
  name        = "ecommerce-waf-${var.environment}"
  description = "WAF for ecommerce API"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ecommerce-waf-metric"
    sampled_requests_enabled   = true
  }
}
```

### 3. Implement KMS Encryption for Sensitive Data

```terraform
resource "aws_kms_key" "ecommerce_key" {
  description = "KMS key for ecommerce application"
  deletion_window_in_days = 30
  enable_key_rotation = true
}

resource "aws_kms_alias" "ecommerce_key_alias" {
  name          = "alias/ecommerce-${var.environment}"
  target_key_id = aws_kms_key.ecommerce_key.key_id
}
```

---

## Conclusion

Following this migration guide will help you successfully move your on-premises e-commerce application to AWS using modern, scalable, and secure infrastructure. The architecture leverages containerization with EKS, serverless database with Aurora PostgreSQL, and infrastructure as code with Terraform.

Key benefits of this migration:

1. **Scalability**: Automatic scaling of compute and database resources
2. **Cost optimization**: Pay only for what you use with serverless and autoscaling
3. **High availability**: Multi-AZ deployment with redundancy
4. **Security**: Best practices implemented across all layers
5. **Maintainability**: CI/CD pipeline for automated deployments
6. **Observability**: Comprehensive monitoring and alerting

After completing the migration, regularly review your architecture and costs to identify further optimization opportunities. 
# AWS 3-Tier Architecture Deployment Guide - Part 7
# CI/CD Pipeline and Deployment Strategies

## CI/CD Overview

A Continuous Integration and Continuous Deployment (CI/CD) pipeline automates the process of building, testing, and deploying your application. This part covers:

1.  **AWS CodePipeline** - Orchestrates the CI/CD workflow
2.  **AWS CodeCommit** - Source code repository
3.  **AWS CodeBuild** - Builds and tests the application
4.  **AWS CodeDeploy** - Deploys the application to EC2 instances
5.  **Deployment Strategies** - Blue/Green, Canary, and Rolling deployments

## Terraform Configuration

Let's create the Terraform modules for our CI/CD components:

### 1. CodeCommit Repository Module

```hcl
# terraform/modules/codecommit/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "repository_name" {
  description = "Name of the CodeCommit repository"
  type        = string
}
```

```hcl
# terraform/modules/codecommit/main.tf
resource "aws_codecommit_repository" "repo" {
  repository_name = "${var.environment}-${var.repository_name}"
  
  tags = {
    Name        = "${var.environment}-${var.repository_name}"
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/codecommit/outputs.tf
output "repository_clone_url_http" {
  description = "HTTP clone URL of the repository"
  value       = aws_codecommit_repository.repo.clone_url_http
}

output "repository_arn" {
  description = "ARN of the repository"
  value       = aws_codecommit_repository.repo.arn
}
```

### 2. CodeBuild Project Module

```hcl
# terraform/modules/codebuild/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "repository_url" {
  description = "URL of the source repository"
  type        = string
}

variable "buildspec_file" {
  description = "Path to the buildspec file"
  type        = string
  default     = "buildspec.yml"
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}
```

```hcl
# terraform/modules/codebuild/main.tf
resource "aws_codebuild_project" "project" {
  name          = "${var.environment}-${var.project_name}"
  description   = "Build project for ${var.project_name}"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild_role.arn

  source {
    type            = "CODECOMMIT"
    location        = var.repository_url
    buildspec       = var.buildspec_file
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }
    
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.environment}-${var.project_name}"
      stream_name = "build"
    }
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "${var.environment}-${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-${var.project_name}-codebuild-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "codebuild_policy" {
  name   = "${var.environment}-${var.project_name}-codebuild-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = var.ecr_repository_url
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

```hcl
# terraform/modules/codebuild/outputs.tf
output "project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.project.name
}
```

### 3. CodeDeploy Application and Deployment Group Module

```hcl
# terraform/modules/codedeploy/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Name of the CodeDeploy application"
  type        = string
}

variable "deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "load_balancer_name" {
  description = "Name of the Load Balancer"
  type        = string
}
```

```hcl
# terraform/modules/codedeploy/main.tf
resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = "${var.environment}-${var.app_name}"

  tags = {
    Name        = "${var.environment}-${var.app_name}"
    Environment = var.environment
  }
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.environment}-${var.deployment_group_name}"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  autoscaling_groups = [var.autoscaling_group_name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  load_balancer_info {
    elb_info {
      name = var.load_balancer_name
    }
  }

  tags = {
    Name        = "${var.environment}-${var.deployment_group_name}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "codedeploy_role" {
  name = "${var.environment}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-codedeploy-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}
```

```hcl
# terraform/modules/codedeploy/outputs.tf
output "app_name" {
  description = "Name of the CodeDeploy application"
  value       = aws_codedeploy_app.app.name
}

output "deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.deployment_group.deployment_group_name
}
```

### 4. CodePipeline Module

```hcl
# terraform/modules/codepipeline/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "pipeline_name" {
  description = "Name of the CodePipeline"
  type        = string
}

variable "repository_name" {
  description = "Name of the source repository"
  type        = string
}

variable "build_project_name" {
  description = "Name of the build project"
  type        = string
}

variable "deploy_app_name" {
  description = "Name of the deploy application"
  type        = string
}

variable "deploy_group_name" {
  description = "Name of the deploy group"
  type        = string
}
```

```hcl
# terraform/modules/codepipeline/main.tf
resource "aws_codepipeline" "pipeline" {
  name     = "${var.environment}-${var.pipeline_name}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = var.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = var.build_project_name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName     = var.deploy_app_name
        DeploymentGroupName = var.deploy_group_name
      }
    }
  }

  tags = {
    Name        = "${var.environment}-${var.pipeline_name}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.environment}-codepipeline-artifacts-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "${var.environment}-codepipeline-artifacts"
    Environment = var.environment
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.environment}-${var.pipeline_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-${var.pipeline_name}-codepipeline-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  name   = "${var.environment}-${var.pipeline_name}-codepipeline-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.codepipeline_artifacts.arn}",
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}
```

```hcl
# terraform/modules/codepipeline/outputs.tf
output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.pipeline.arn
}
```

### 5. Buildspec and AppSpec Files

**buildspec.yml for Backend**

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - IMAGE_TAG=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $ECR_REPOSITORY_URL:latest .
      - docker tag $ECR_REPOSITORY_URL:latest $ECR_REPOSITORY_URL:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $ECR_REPOSITORY_URL:latest
      - docker push $ECR_REPOSITORY_URL:$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"backend","imageUri":"%s"}]' $ECR_REPOSITORY_URL:$IMAGE_TAG > imagedefinitions.json
artifacts:
  files: imagedefinitions.json
```

**appspec.yml for CodeDeploy**

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "backend"
          ContainerPort: 8000
```

## Deployment Strategies

### 1. Blue/Green Deployment

With a blue/green deployment, you create a new set of instances (green) alongside the existing ones (blue). Traffic is then switched from the blue to the green environment.

**Advantages**:
- Zero downtime deployments
- Instant rollback by switching traffic back to the blue environment
- Reduces risk by allowing testing on the green environment before production traffic

**Disadvantages**:
- Higher cost due to duplicate infrastructure
- More complex to manage

### 2. Canary Deployment

With a canary deployment, you release the new version to a small subset of users first. If no issues are detected, you gradually roll out the change to the rest of the infrastructure.

**Advantages**:
- Lower risk than a full deployment
- Allows for real-world testing with a small user base
- Faster rollback for the canary group

**Disadvantages**:
- More complex to implement
- Requires advanced monitoring to detect issues

### 3. Rolling Deployment

With a rolling deployment, you slowly replace old instances with new ones, one by one or in batches.

**Advantages**:
- Simple to implement
- Lower cost than blue/green
- Gradual rollout reduces risk

**Disadvantages**:
- Can have a mix of old and new versions running simultaneously
- Rollback can be slow

## CI/CD Best Practices

1.  **Automate Everything**: Automate the entire CI/CD process from code commit to deployment.
2.  **Infrastructure as Code**: Use Terraform to manage your CI/CD infrastructure.
3.  **Secure Your Pipeline**: Implement security checks in your pipeline (static analysis, dependency scanning).
4.  **Use a Monorepo**: Consider a monorepo for easier dependency management.
5.  **Fast Feedback Loop**: Optimize your pipeline for fast feedback to developers.
6.  **Immutable Artifacts**: Ensure your build artifacts are immutable.
7.  **Monitor Your Pipeline**: Monitor the health and performance of your CI/CD pipeline.
8.  **Implement a Rollback Strategy**: Have a clear rollback strategy in case of deployment failures.
9.  **Keep it Simple**: Start with a simple pipeline and add complexity as needed.
10. **Regularly Review and Improve**: Continuously review and improve your CI/CD process.

This concludes the 7-part guide on deploying a 3-tier architecture on AWS. By following these steps, you can build a secure, scalable, and resilient e-commerce application. 
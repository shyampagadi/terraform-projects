region                   = "us-east-1"
vpc_cidr                 = "10.0.0.0/16"
cluster_name             = "ecommerce"
kubernetes_version       = "1.27"
endpoint_private_access  = true
endpoint_public_access   = true
public_access_cidrs      = ["0.0.0.0/0"]
enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
log_retention_days       = 90
cpu_threshold            = 80
create_alb_controller    = true
create_cluster_autoscaler = true

node_groups = {
  app = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 2
    min_size       = 2
    max_size       = 4
    disk_size      = 20
    labels = {
      "role" = "app"
    }
  }
  monitoring = {
    instance_types = ["t3.small"]
    capacity_type  = "SPOT"
    desired_size   = 1
    min_size       = 1
    max_size       = 2
    disk_size      = 20
    labels = {
      "role" = "monitoring"
    }
    taints = [
      {
        key    = "dedicated"
        value  = "monitoring"
        effect = "NO_SCHEDULE"
      }
    ]
  }
}

eks_addons = {
  vpc-cni = {
    resolve_conflicts = "OVERWRITE"
  }
  kube-proxy = {
    resolve_conflicts = "OVERWRITE"
  }
  coredns = {
    resolve_conflicts = "OVERWRITE"
  }
  aws-ebs-csi-driver = {
    resolve_conflicts = "OVERWRITE"
  }
} 
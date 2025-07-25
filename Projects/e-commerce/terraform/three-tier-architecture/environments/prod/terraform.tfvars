region                   = "us-east-1"
vpc_cidr                 = "10.10.0.0/16"
app_port                 = 8080
health_check_path        = "/health"
db_port                  = 5432
create_bastion           = true
allowed_ssh_cidr_blocks  = ["10.0.0.0/8"] # Restrict to specific company IPs in production
instance_type            = "t3.large"
asg_desired_capacity     = 3
asg_min_size             = 3
asg_max_size             = 10
db_name                  = "ecommerce"
db_username              = "admin"
db_engine                = "postgres"
db_engine_version        = "14.5"
db_major_engine_version  = "14"
db_parameter_group_family = "postgres14"
db_instance_class        = "db.t3.large"
db_allocated_storage     = 100 
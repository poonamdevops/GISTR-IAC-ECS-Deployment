# Dev environment values. Edit here without touching the module code.
aws_region  = "ap-south-1"
environment = "dev"
name_prefix = "gistr-dev"

owner       = "Teleglobal"
cost_center = "gistr-migration"

# Network (Dev VPC 10.1.0.0/16, single AZ + tiny 2nd public subnet for ALB)
vpc_cidr                     = "10.1.0.0/16"
public_subnet_cidr           = "10.1.0.0/24"
public_subnet_secondary_cidr = "10.1.1.0/24"
private_app_subnet_cidr      = "10.1.10.0/24"
private_data_subnet_cidr     = "10.1.20.0/24"

# Ports/health paths are set per-app in variables.tf (verified from Azure:
# frontend 3000, backend 5000, ai 8000). Default app served at the ALB root:
default_app = "frontend"

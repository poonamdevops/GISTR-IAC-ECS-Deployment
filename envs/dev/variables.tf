variable "aws_region" {
  description = "AWS region. Gistr runs in Mumbai only."
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "gistr-dev"
}

variable "owner" {
  description = "Owner tag (no owner tag existed in Azure; default to partner)."
  type        = string
  default     = "Teleglobal"
}

variable "cost_center" {
  description = "Cost center tag (placeholder until client provides a code)."
  type        = string
  default     = "gistr-migration"
}

# ---- Network CIDRs (Dev VPC 10.1.0.0/16) ----------------------------------
variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.1.0.0/24"
}

variable "public_subnet_secondary_cidr" {
  type    = string
  default = "10.1.1.0/24"
}

variable "private_app_subnet_cidr" {
  type    = string
  default = "10.1.10.0/24"
}

variable "private_data_subnet_cidr" {
  type    = string
  default = "10.1.20.0/24"
}

# ---- Per-app definitions (Dev = 1 instance/app, m6i.large per BOQ) ---------
# Ports and health paths verified from the Azure App Service config:
#   frontend (Next.js)  -> WEBSITES_PORT 3000, health /
#   backend  (Next.js)  -> WEBSITES_PORT 5000, health /
#   ai       (Uvicorn)  -> no WEBSITES_PORT set; Uvicorn default 8000, health /health
variable "apps" {
  description = "Dev applications: instance type (BOQ), port, health path, Azure source metadata, ALB hostname."
  type = map(object({
    instance_type     = string
    port              = number
    hostname          = string
    health_check_path = string
    source_azure_app  = string
    source_azure_sku  = string
    source_azure_plan = string
  }))
  default = {
    frontend = {
      instance_type     = "m6i.large"
      port              = 3000
      hostname          = "dev.digital-garden.nudgepixels.com"
      health_check_path = "/"
      source_azure_app  = "dev-digital-garden-client"
      source_azure_sku  = "B2"
      source_azure_plan = "frontend-development-service-plan"
    }
    backend = {
      instance_type     = "m6i.large"
      port              = 5000
      hostname          = "dev.api.digital-garden.nudgepixels.com"
      health_check_path = "/"
      source_azure_app  = "dev-digital-garden-backend"
      source_azure_sku  = "B2"
      source_azure_plan = "backend-development-service-plan"
    }
    ai = {
      instance_type     = "m6i.large"
      port              = 8080 # confirmed from image: uvicorn --port 8080
      hostname          = "dev.api.llm.gistr.so"
      health_check_path = "/health"
      source_azure_app  = "devgistrllm"
      source_azure_sku  = "B3"
      source_azure_plan = "ai-development-service-plan"
    }
  }
}

variable "default_app" {
  description = "App the ALB serves by default (via ALB DNS name)."
  type        = string
  default     = "frontend"
}

# ---- ECS-on-EC2 settings --------------------------------------------------
variable "ecs_instance_type" {
  description = "EC2 container instance type for the ECS cluster (BOQ: m6i.large)."
  type        = string
  default     = "m6i.large"
}

variable "task_cpu" {
  description = "CPU units per ECS task (1024 = 1 vCPU). Sized to share the m6i.large."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory (MB) per ECS task. Sized to share the m6i.large (8 GB)."
  type        = number
  default     = 1024
}

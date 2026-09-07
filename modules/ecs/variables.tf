variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

# ---- EC2 capacity ---------------------------------------------------------
variable "instance_type" {
  description = "EC2 container instance type (BOQ: m6i.large)."
  type        = string
  default     = "m6i.large"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS EC2 instances and tasks (via NAT)."
  type        = list(string)
}

variable "root_volume_size_gb" {
  description = "Root EBS size for container instances."
  type        = number
  default     = 30
}

variable "asg_min_size" {
  description = "Min EC2 container instances."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Max EC2 container instances."
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired EC2 container instances (Dev: 1 shared box hosts the tasks)."
  type        = number
  default     = 1
}

variable "service_desired_count" {
  description = "Desired running tasks per service."
  type        = number
  default     = 1
}

# ---- Security groups ------------------------------------------------------
variable "ecs_instances_sg_id" {
  description = "SG for the EC2 container instances."
  type        = string
}

variable "ecs_tasks_sg_id" {
  description = "SG for the ECS tasks (awsvpc ENIs)."
  type        = string
}

# ---- App definitions ------------------------------------------------------
variable "apps" {
  description = <<-EOT
    Map of app name => task config:
    {
      frontend = {
        image_url = "...", image_tag = "latest", port = 3000,
        cpu = 512, memory = 1024,
        secret_keys = ["MONGODB_URI","BACKEND_URL", ...]   # keys inside the app's Secrets Manager JSON
      }
    }
    secret_keys is optional; each listed key is injected as a real env var
    sourced from Secrets Manager (secret JSON key -> container env var).
  EOT
  type = map(object({
    image_url   = string
    image_tag   = string
    port        = number
    cpu         = number
    memory      = number
    secret_keys = optional(list(string), [])
  }))
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (shell into running tasks) for debugging."
  type        = bool
  default     = true
}

variable "target_group_arns" {
  description = "Map of app name -> ALB target group ARN."
  type        = map(string)
}

variable "secret_arns" {
  description = "All app secret ARNs (for task exec/task role)."
  type        = list(string)
  default     = []
}

variable "secret_arns_by_app" {
  description = "Map of app name -> secret ARN."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN (EBS, logs, secrets decrypt)."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

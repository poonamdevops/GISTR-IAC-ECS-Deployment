variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (2 AZs) for the ALB."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB security group ID."
  type        = string
}

variable "apps" {
  description = <<-EOT
    Map of app name => routing config. Example:
    { frontend = { port = 3000, hostname = "dev.example.com", health_check_path = "/" } }
    hostname may be empty (no host rule created; reachable via default/other).
  EOT
  type = map(object({
    port              = number
    hostname          = optional(string, "")
    health_check_path = optional(string, "/")
  }))
}

variable "default_app" {
  description = "App name that the ALB default action forwards to."
  type        = string
}

variable "enable_https" {
  description = "When true: request an ACM cert, add HTTPS:443 listener, and redirect HTTP->HTTPS."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

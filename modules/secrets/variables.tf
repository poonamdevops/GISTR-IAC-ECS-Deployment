variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod), used in the secret path."
  type        = string
}

variable "app_names" {
  description = "App names to create a secret for (e.g. frontend, backend, ai)."
  type        = list(string)
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security groups in."
  type        = string
}

variable "app_ports" {
  description = "Distinct ports the apps listen on (ALB -> EC2). e.g. [3000,5000,8000]."
  type        = list(number)
  default     = [3000]
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

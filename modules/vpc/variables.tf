variable "name_prefix" {
  description = "Prefix for resource names, e.g. gistr-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR for the primary public subnet (ALB + NAT)."
  type        = string
}

variable "public_subnet_secondary_cidr" {
  description = "CIDR for the secondary public subnet (ALB 2nd AZ requirement)."
  type        = string
}

variable "private_app_subnet_cidr" {
  description = "CIDR for the private application subnet (EC2)."
  type        = string
}

variable "private_data_subnet_cidr" {
  description = "CIDR for the isolated private data subnet (future DB/cache)."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "repository_names" {
  description = "List of ECR repository names to create."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN for ECR encryption."
  type        = string
}

variable "keep_last_images" {
  description = "Number of most-recent images to retain per repo."
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Allow deleting repos that still contain images (Dev convenience)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

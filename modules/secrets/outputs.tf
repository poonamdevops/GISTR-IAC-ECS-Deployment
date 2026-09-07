output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "kms_key_id" {
  value = aws_kms_key.this.key_id
}

output "secret_arns" {
  description = "List of all app secret ARNs."
  value       = [for s in aws_secretsmanager_secret.app : s.arn]
}

output "secret_arns_by_app" {
  description = "Map of app name -> secret ARN."
  value       = { for k, s in aws_secretsmanager_secret.app : k => s.arn }
}

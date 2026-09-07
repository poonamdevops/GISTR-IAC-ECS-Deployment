output "repository_urls" {
  description = "Map of repo name -> repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "List of repository ARNs."
  value       = [for r in aws_ecr_repository.this : r.arn]
}

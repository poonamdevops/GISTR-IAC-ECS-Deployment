output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Test the apps at this DNS name (HTTP) until domains/HTTPS are added."
  value       = module.alb.alb_dns_name
}

output "ecr_repository_urls" {
  description = "Push images here (see ACR->ECR migration)."
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_names" {
  value = module.ecs.service_names
}

output "ecs_asg_name" {
  value = module.ecs.asg_name
}

output "kms_key_arn" {
  value = module.secrets.kms_key_arn
}

output "secret_arns_by_app" {
  value = module.secrets.secret_arns_by_app
}

# CNAMEs to add in Cloudflare (DNS-only) to validate the ACM cert.
output "acm_validation_records" {
  description = "Add these in Cloudflare to validate HTTPS. Empty until enable_https=true."
  value       = module.alb.acm_validation_records
}

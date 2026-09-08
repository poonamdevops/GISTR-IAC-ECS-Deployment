output "alb_dns_name" {
  description = "Public DNS name of the ALB - use this to test the apps."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_arns" {
  value = { for k, tg in aws_lb_target_group.app : k => tg.arn }
}

# The CNAME records to add in Cloudflare to validate the ACM certificate.
# name/value/type per domain. (Empty until enable_https = true.)
output "acm_validation_records" {
  description = "Add these CNAMEs in Cloudflare (DNS-only) to validate the ACM cert."
  value = var.enable_https ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

output "acm_certificate_arn" {
  value = var.enable_https ? aws_acm_certificate.this[0].arn : ""
}

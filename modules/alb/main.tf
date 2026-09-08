# ---------------------------------------------------------------------------
# Module: alb  (Application Load Balancer)
# ---------------------------------------------------------------------------
# Internet-facing ALB with one target group per app. For Dev we start with an
# HTTP:80 listener (HTTPS/ACM added later with domains). Routing is host-based;
# a default action serves the first app so the ALB DNS name is testable now.
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

# One target group per app (each app has its own port + health path).
# target_type = "ip" because ECS tasks use awsvpc networking (each task = ENI).
# ECS registers/deregisters task IPs automatically - no static attachment.
#
# create_before_destroy + name_prefix lets a replacement target group be
# created and wired into the listener BEFORE the old one is deleted, avoiding
# the "ResourceInUse: in use by a listener or a rule" error on type changes.
resource "aws_lb_target_group" "app" {
  for_each = var.apps

  name_prefix = substr("${each.key}-", 0, 6)
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = try(each.value.health_check_path, "/")
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-tg", Application = each.key })
}

# ---------------------------------------------------------------------------
# ACM certificate (one cert, all app hostnames as SANs). DNS validation.
# Only created when enable_https = true.
# ---------------------------------------------------------------------------
locals {
  hostnames = [for k, v in var.apps : v.hostname if try(v.hostname, "") != ""]
}

resource "aws_acm_certificate" "this" {
  count = var.enable_https ? 1 : 0

  domain_name               = local.hostnames[0]
  subject_alternative_names = slice(local.hostnames, 1, length(local.hostnames))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-cert" })
}

# The DNS validation records you must add in Cloudflare are exposed as an
# output (acm_validation_records) so they can be created manually.

# ---------------------------------------------------------------------------
# ACM certificate validation - waits until the DNS validation CNAMEs are added
# (in Squarespace/Cloudflare) and the cert is ISSUED. The HTTPS listener
# depends on this, so it is only created once the cert is actually valid.
# ---------------------------------------------------------------------------
resource "aws_acm_certificate_validation" "this" {
  count           = var.enable_https ? 1 : 0
  certificate_arn = aws_acm_certificate.this[0].arn
  # No validation_record_fqdns given: we add the records manually, then this
  # simply waits for the cert status to become ISSUED.

  timeouts {
    create = "45m"
  }
}

# ---------------------------------------------------------------------------
# HTTP:80 listener
#   - HTTPS disabled: forward to the default app (test via ALB DNS)
#   - HTTPS enabled : redirect everything to 443
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    # Only set when forwarding (HTTPS off).
    target_group_arn = var.enable_https ? null : aws_lb_target_group.app[var.default_app].arn

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# Host-based routing on HTTP (only when HTTPS is OFF - for pre-DNS testing).
resource "aws_lb_listener_rule" "host_http" {
  for_each = var.enable_https ? {} : { for k, v in var.apps : k => v if try(v.hostname, "") != "" }

  listener_arn = aws_lb_listener.http.arn
  priority     = index(keys(var.apps), each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }

  condition {
    host_header {
      values = [each.value.hostname]
    }
  }
}

# ---------------------------------------------------------------------------
# HTTPS:443 listener + host-based routing (only when enable_https = true).
# Depends on cert validation so it's created only after the cert is ISSUED.
# ---------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.this[0].certificate_arn

  # Default: serve the default app.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[var.default_app].arn
  }
}

resource "aws_lb_listener_rule" "host_https" {
  for_each = var.enable_https ? { for k, v in var.apps : k => v if try(v.hostname, "") != "" } : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = index(keys(var.apps), each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }

  condition {
    host_header {
      values = [each.value.hostname]
    }
  }
}

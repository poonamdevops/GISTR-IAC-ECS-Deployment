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

# HTTP:80 listener. Default action -> the designated default app.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[var.default_app].arn
  }
}

# Host-based routing rules (one per app that has a hostname configured).
resource "aws_lb_listener_rule" "host" {
  for_each = { for k, v in var.apps : k => v if try(v.hostname, "") != "" }

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

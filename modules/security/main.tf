# ---------------------------------------------------------------------------
# Module: security  (security groups)
# ---------------------------------------------------------------------------
# - ALB SG : allows inbound HTTP/HTTPS from the internet.
# - App SG : allows inbound app traffic ONLY from the ALB SG (least privilege).
#            No SSH from the internet (access is via SSM Session Manager).
# ---------------------------------------------------------------------------

# ---- ALB security group ---------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB: allow HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---- ECS tasks security group (awsvpc ENIs) -------------------------------
# Each ECS task gets its own ENI in the private subnet. The ALB must reach the
# task on the app port; tasks need outbound for ECR/secrets/DB/Redis.
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-ecs-tasks-sg"
  description = "ECS tasks: allow app port from ALB only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-ecs-tasks-sg" })
}

# Only the ALB may reach the task ports (3000/5000/8000).
resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  for_each = toset([for p in var.app_ports : tostring(p)])

  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "App port ${each.value} from ALB only"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "tasks_all" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---- ECS container-instance security group (EC2 hosts) --------------------
# The EC2 hosts don't receive ALB traffic directly (tasks do, via their ENIs),
# but they need outbound for the ECS agent, ECR pulls and SSM.
resource "aws_security_group" "ecs_instances" {
  name        = "${var.name_prefix}-ecs-instances-sg"
  description = "ECS EC2 container instances"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-ecs-instances-sg" })
}

resource "aws_vpc_security_group_egress_rule" "instances_all" {
  security_group_id = aws_security_group.ecs_instances.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

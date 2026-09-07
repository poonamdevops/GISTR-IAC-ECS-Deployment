# ---------------------------------------------------------------------------
# Task definitions + services (one per app)
# ---------------------------------------------------------------------------
# Uses awsvpc network mode so each task gets its own ENI in the private
# subnet and registers with the ALB target group by IP (best practice).
# Secrets are injected from Secrets Manager via the task execution role.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  for_each = var.apps

  name              = "/gistr/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-logs", Application = each.key })
}

resource "aws_ecs_task_definition" "app" {
  for_each = var.apps

  family             = "${var.name_prefix}-${each.key}"
  network_mode       = "awsvpc"
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  # EC2 launch type - size the task to fit the m6i.large (2 vCPU / 8 GB).
  cpu    = each.value.cpu
  memory = each.value.memory

  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${each.value.image_url}:${each.value.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]
      # Non-sensitive env vars. Exclude any name that is ALSO a secret key -
      # ECS rejects a task def where the same name appears in both
      # `environment` and `secrets` (e.g. backend has APP_NAME as a secret).
      environment = [
        for kv in [
          { name = "APP_NAME", value = each.key },
          { name = "AWS_REGION", value = var.aws_region },
        ] : kv if !contains(each.value.secret_keys, kv.name)
      ]
      # Sensitive env vars injected natively from Secrets Manager.
      # Each key in secret_keys maps to a JSON key inside the app's secret,
      # referenced as <secret_arn>:<key>:: so ECS injects it as a real env var.
      secrets = [
        for k in each.value.secret_keys : {
          name      = k
          valueFrom = "${var.secret_arns_by_app[each.key]}:${k}::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/gistr/${var.environment}/${each.key}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.key}-task"
    Application = each.key
  })
}

resource "aws_ecs_service" "app" {
  for_each = var.apps

  name                   = "${var.name_prefix}-${each.key}"
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.app[each.key].arn
  desired_count          = var.service_desired_count
  enable_execute_command = var.enable_execute_command

  # Place tasks on the EC2 capacity provider.
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
    base              = 0
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_tasks_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = each.key
    container_port   = each.value.port
  }

  # Let ECS ignore desired_count drift if scaled outside TF.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]

  tags = merge(var.tags, { Application = each.key })
}

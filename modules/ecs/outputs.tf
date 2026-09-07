output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.this.name
}

output "service_names" {
  value = { for k, s in aws_ecs_service.app : k => s.name }
}

output "task_definition_arns" {
  value = { for k, t in aws_ecs_task_definition.app : k => t.arn }
}

output "asg_name" {
  value = aws_autoscaling_group.ecs.name
}

output "log_group_names" {
  value = { for k, g in aws_cloudwatch_log_group.app : k => g.name }
}

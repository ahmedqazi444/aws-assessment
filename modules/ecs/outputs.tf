# modules/ecs/outputs.tf

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs_cluster.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.name
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.sns_publisher.arn
}

output "execution_role_arn" {
  description = "ECS execution role ARN"
  value       = module.ecs_execution_role.iam_role_arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = module.ecs_task_role.iam_role_arn
}

# -----------------------------------------------------------------------------
# ECSサービスモジュール 出力定義
# -----------------------------------------------------------------------------

output "service_id" {
  description = "ECSサービスID"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "ECSサービス名"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "タスク定義ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_family" {
  description = "タスク定義ファミリー名"
  value       = aws_ecs_task_definition.main.family
}

output "task_execution_role_arn" {
  description = "タスク実行ロールARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "タスクロールARN"
  value       = aws_iam_role.ecs_task.arn
}

output "service_arn" {
  description = "ECSサービスARN"
  value       = aws_ecs_service.main.id
}


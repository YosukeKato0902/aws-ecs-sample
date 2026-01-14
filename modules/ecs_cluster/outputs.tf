# -----------------------------------------------------------------------------
# ECSクラスターモジュール 出力定義
# -----------------------------------------------------------------------------

output "cluster_id" {
  description = "ECSクラスターID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ECSクラスターARN"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "ECSクラスター名"
  value       = aws_ecs_cluster.main.name
}

output "log_group_name" {
  description = "CloudWatch Logsロググループ名"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "CloudWatch LogsロググループARN"
  value       = aws_cloudwatch_log_group.ecs.arn
}

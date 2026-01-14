# -----------------------------------------------------------------------------
# CloudWatchモジュール 出力定義
# -----------------------------------------------------------------------------

output "sns_topic_arn" {
  description = "アラート用SNSトピックARN"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "ダッシュボード名"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "ダッシュボードARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

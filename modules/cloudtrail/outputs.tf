# -----------------------------------------------------------------------------
# CloudTrail モジュール 出力定義
# -----------------------------------------------------------------------------

output "trail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.main.arn
}

output "trail_id" {
  description = "CloudTrail ID"
  value       = aws_cloudtrail.main.id
}

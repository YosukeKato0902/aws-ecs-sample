# -----------------------------------------------------------------------------
# Security Hub モジュール 出力定義
# -----------------------------------------------------------------------------

output "security_hub_id" {
  description = "Security Hub アカウントID"
  value       = aws_securityhub_account.main.id
}

# -----------------------------------------------------------------------------
# ACMモジュール 出力定義
# -----------------------------------------------------------------------------

output "certificate_arn" {
  description = "ACM証明書ARN"
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain_name" {
  description = "証明書のドメイン名"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_status" {
  description = "証明書のステータス"
  value       = aws_acm_certificate.main.status
}

output "domain_validation_options" {
  description = "DNS検証オプション"
  value       = aws_acm_certificate.main.domain_validation_options
}

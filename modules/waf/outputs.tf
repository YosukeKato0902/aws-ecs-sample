# -----------------------------------------------------------------------------
# WAFモジュール 出力定義
# -----------------------------------------------------------------------------

output "web_acl_id" {
  description = "WAF WebACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "WAF WebACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "WAF WebACL名"
  value       = aws_wafv2_web_acl.main.name
}

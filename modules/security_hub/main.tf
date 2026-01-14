# -----------------------------------------------------------------------------
# Security Hub モジュール
# このモジュールは、AWS Security Hubを有効化し、各種セキュリティ基準
#（AWS Foundational Security Best PracticesやCIS等）への準拠確認を自動化する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Security Hub 有効化
# -----------------------------------------------------------------------------
resource "aws_securityhub_account" "main" {}

# -----------------------------------------------------------------------------
# AWS Foundational Security Best Practices 標準のサブスクリプション
# AWSが推奨する基本的なセキュリティベストプラクティスに基づいたチェックを実行する
# -----------------------------------------------------------------------------
resource "aws_securityhub_standards_subscription" "aws_foundational" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.id}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# -----------------------------------------------------------------------------
# CIS AWS Foundations Benchmark 標準のサブスクリプション (オプション)
# 業界標準のCISベンチマークに基づいたセキュリティ構成の監査を実行する
# -----------------------------------------------------------------------------
resource "aws_securityhub_standards_subscription" "cis" {
  count         = var.enable_cis_standard ? 1 : 0
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.id}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

# -----------------------------------------------------------------------------
# データソース: リージョン情報の取得
# -----------------------------------------------------------------------------
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# セキュリティ・監査層 (dev)
# セキュリティ基準準拠確認（Security Hub）、脅威検知（GuardDuty）、
# 構成管理（Config）、操作ログ（CloudTrail）の設定。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Security Hub モジュール
# ベストプラクティスに基づいたセキュリティチェック
# -----------------------------------------------------------------------------
module "security_hub" {
  source = "../../modules/security_hub"

  enable_cis_standard = false # 開発環境: コスト削減のためCISベンチマークを無効化
}

# -----------------------------------------------------------------------------
# GuardDuty モジュール
# アカウントやリソースに対する脅威の継続的監視
# -----------------------------------------------------------------------------
module "guardduty" {
  source = "../../modules/guardduty"

  project_name = local.project_name
  environment  = local.environment
}

# -----------------------------------------------------------------------------
# Config モジュール
# リソースの構成履歴記録とガバナンス管理
# -----------------------------------------------------------------------------
module "config" {
  source = "../../modules/config"

  project_name       = local.project_name
  environment        = local.environment
  config_bucket_name = module.s3_audit_logs.bucket_id
  config_bucket_arn  = module.s3_audit_logs.bucket_arn
}

# -----------------------------------------------------------------------------
# CloudTrail / CloudWatch Logs 連携設定
# API操作ログの証跡作成とログストリーム出力
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.project_name}-${local.environment}"
  retention_in_days = 7 # 開発環境: コスト削減のため保持期間を短縮
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name             = local.project_name
  environment              = local.environment
  trail_bucket_name        = module.s3_audit_logs.bucket_id
  enable_s3_logging        = false # 開発環境: コスト削減のためデータイベント記録を無効化
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.cloudtrail.arn
  enable_cloudwatch_logs   = true
}

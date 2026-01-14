# -----------------------------------------------------------------------------
# セキュリティ関連リソース (stg)
# -----------------------------------------------------------------------------

module "security_hub" {
  source = "../../modules/security_hub"

  enable_cis_standard = true # ステージング: 検証のため有効化
}

module "guardduty" {
  source = "../../modules/guardduty"

  project_name = local.project_name
  environment  = local.environment
}

module "config" {
  source = "../../modules/config"

  project_name       = local.project_name
  environment        = local.environment
  config_bucket_name = module.s3_audit_logs.bucket_id
  config_bucket_arn  = module.s3_audit_logs.bucket_arn
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.project_name}-${local.environment}"
  retention_in_days = 90 # ステージング: 90日保存
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name             = local.project_name
  environment              = local.environment
  trail_bucket_name        = module.s3_audit_logs.bucket_id
  enable_s3_logging        = false # ステージング: データイベント記録無効（コスト削減）
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.cloudtrail.arn
  enable_cloudwatch_logs   = true
}

# -----------------------------------------------------------------------------
# セキュリティ関連リソース (prd)
# Security Hub, GuardDuty, Config, CloudTrail
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Security Hub
# -----------------------------------------------------------------------------
module "security_hub" {
  source = "../../modules/security_hub"

  enable_cis_standard = true # 本番: CISベンチマーク有効化
}

# -----------------------------------------------------------------------------
# GuardDuty
# -----------------------------------------------------------------------------
module "guardduty" {
  source = "../../modules/guardduty"

  project_name = local.project_name
  environment  = local.environment
}

# -----------------------------------------------------------------------------
# AWS Config
# -----------------------------------------------------------------------------
module "config" {
  source = "../../modules/config"

  project_name       = local.project_name
  environment        = local.environment
  config_bucket_name = module.s3_audit_logs.bucket_id
  config_bucket_arn  = module.s3_audit_logs.bucket_arn
}

# -----------------------------------------------------------------------------
# CloudTrail
# -----------------------------------------------------------------------------

# CloudTrail用ロググループ
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.project_name}-${local.environment}"
  retention_in_days = 365 # 1年保存
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name             = local.project_name
  environment              = local.environment
  trail_bucket_name        = module.s3_audit_logs.bucket_id
  enable_s3_logging        = true
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.cloudtrail.arn
  enable_cloudwatch_logs   = true
}

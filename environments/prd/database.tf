# -----------------------------------------------------------------------------
# データストア層 (prd)
# RDS, S3
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# S3モジュール (アプリ用)
# -----------------------------------------------------------------------------

module "s3_app" {
  source = "../../modules/s3"

  project_name           = local.project_name
  environment            = local.environment
  bucket_name            = "app-storage"
  enable_versioning      = true
  enable_lifecycle_rules = true # 本番: ライフサイクルルール有効
}

# -----------------------------------------------------------------------------
# S3モジュール (CI/CDアーティファクト用)
# -----------------------------------------------------------------------------

module "s3_artifacts" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "cicd-artifacts"
  enable_versioning = true
}

# -----------------------------------------------------------------------------
# S3モジュール (ALBアクセスログ用) - 本番用
# -----------------------------------------------------------------------------

module "s3_alb_logs" {
  source = "../../modules/s3"

  project_name           = local.project_name
  environment            = local.environment
  bucket_name            = "alb-access-logs"
  enable_versioning      = false
  enable_lifecycle_rules = true # 90日後に削除
  enable_alb_logs        = true # ALBログ用バケットポリシー有効化
}

# -----------------------------------------------------------------------------
# S3モジュール (監査ログ用: CloudTrail/Config) - 本番用
# -----------------------------------------------------------------------------

module "s3_audit_logs" {
  source = "../../modules/s3"

  project_name           = local.project_name
  environment            = local.environment
  bucket_name            = "audit-logs"
  enable_versioning      = true
  enable_lifecycle_rules = true # 長期保存
  allow_cloudtrail       = true # CloudTrailからの書き込み許可
  allow_config           = true # Configからの書き込み許可
}

# -----------------------------------------------------------------------------
# RDSモジュール (App1用) - 本番設定
# -----------------------------------------------------------------------------

module "rds_app1" {
  source = "../../modules/rds"

  project_name          = local.project_name
  environment           = local.environment
  db_name               = "app1db"
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_group.rds_security_group_id
  instance_class        = "db.t4g.medium" # 本番: Graviton2推奨
  allocated_storage     = 50
  max_allocated_storage = 200

  multi_az                     = true # 本番: マルチAZ有効
  backup_retention_period      = 14   # 本番: バックアップ保持期間延長
  recovery_window_in_days      = 30   # 本番: Secrets Manager 30日間復旧可能
  performance_insights_enabled = true # 本番: Performance Insights有効
}

# -----------------------------------------------------------------------------
# RDSモジュール (App2用) - 本番設定
# -----------------------------------------------------------------------------

module "rds_app2" {
  source = "../../modules/rds"

  project_name          = local.project_name
  environment           = local.environment
  db_name               = "app2db"
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_group.rds_security_group_id
  instance_class        = "db.t4g.medium"
  allocated_storage     = 50
  max_allocated_storage = 200

  multi_az                     = true # 本番: マルチAZ有効
  backup_retention_period      = 14   # 本番: バックアップ保持期間延長
  recovery_window_in_days      = 30   # 本番: Secrets Manager 30日間復旧可能
  performance_insights_enabled = true # 本番: Performance Insights有効
}

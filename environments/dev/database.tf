# -----------------------------------------------------------------------------
# データストア層 (dev)
# S3バケット、RDSデータベースの設定。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# S3モジュール (アプリ用)
# アプリケーションが直接利用する汎用ストレージ
# -----------------------------------------------------------------------------
module "s3_app" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "app-storage"
  enable_versioning = true
}

# -----------------------------------------------------------------------------
# S3モジュール (CI/CDアーティファクト用)
# CodePipelineの中間生成物やデプロイパッケージの保管用
# -----------------------------------------------------------------------------
module "s3_artifacts" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "cicd-artifacts"
  enable_versioning = true
}

# -----------------------------------------------------------------------------
# S3モジュール (監査ログ用: CloudTrail/Config)
# セキュリティ監査ログの一元管理用バケット
# -----------------------------------------------------------------------------
module "s3_audit_logs" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "audit-logs"
  enable_versioning = true
  allow_cloudtrail  = true
  allow_config      = true
  force_destroy     = true # 開発環境: 環境削除を容易にするため強制削除を許可
}

# -----------------------------------------------------------------------------
# RDSモジュール (App1用)
# PostgreSQLマネージドデータベース。Gravitonインスタンスによるコスト最適化。
# -----------------------------------------------------------------------------
module "rds_app1" {
  source = "../../modules/rds"

  project_name          = local.project_name
  environment           = local.environment
  db_name               = "app1db"
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_group.rds_security_group_id
  instance_class        = "db.t4g.micro" # 開発環境: 最小スペック
  allocated_storage     = 20
  max_allocated_storage = 50

  multi_az                = false # 開発環境: コスト削減のためシングルAZ
  backup_retention_period = 3     # 開発環境: バックアップ保持期間を短縮
}

# -----------------------------------------------------------------------------
# RDSモジュール (App2用)
# -----------------------------------------------------------------------------
module "rds_app2" {
  source = "../../modules/rds"

  project_name          = local.project_name
  environment           = local.environment
  db_name               = "app2db"
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_group.rds_security_group_id
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 50

  multi_az                = false
  backup_retention_period = 3
}

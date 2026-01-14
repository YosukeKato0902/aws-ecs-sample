# -----------------------------------------------------------------------------
# データストア層 (stg)
# RDS, S3
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# S3モジュール (アプリ用)
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
# -----------------------------------------------------------------------------

module "s3_artifacts" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "cicd-artifacts"
  enable_versioning = true
}

# -----------------------------------------------------------------------------
# S3モジュール (監査ログ用) - 開発用
# -----------------------------------------------------------------------------

module "s3_audit_logs" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "audit-logs"
  enable_versioning = true
  allow_cloudtrail  = true
  allow_config      = true
  force_destroy     = false # ステージング: 安全のためfalse
}

# -----------------------------------------------------------------------------
# RDSモジュール (App1用)
# -----------------------------------------------------------------------------

module "rds_app1" {
  source = "../../modules/rds"

  project_name          = local.project_name
  environment           = local.environment
  db_name               = "app1db"
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_group.rds_security_group_id
  instance_class        = "db.t4g.micro" # コスト削減: Graviton2推奨
  allocated_storage     = 20
  max_allocated_storage = 100

  multi_az                = false # コスト削減: シングルAZ
  backup_retention_period = 7
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
  max_allocated_storage = 100

  multi_az                = false
  backup_retention_period = 7
}

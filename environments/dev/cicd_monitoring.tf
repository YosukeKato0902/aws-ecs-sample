# -----------------------------------------------------------------------------
# CI/CD・監視層 (dev)
# 継続的デリバリー（CodePipeline）、監視（CloudWatch）、バックアップの設定。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CI/CDモジュール (App1)
# ソース取得、ビルド、デプロイ（Blue/Green）の自動化
# -----------------------------------------------------------------------------
module "cicd_app1" {
  source = "../../modules/cicd"

  project_name         = local.project_name
  environment          = local.environment
  service_name         = "app1"
  ecr_repository_url   = module.ecr_app1.repository_url
  ecr_repository_arn   = module.ecr_app1.repository_arn
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  ecs_cluster_arn      = module.ecs_cluster.cluster_arn
  ecs_service_name     = module.ecs_service_app1.service_name
  ecs_service_arn      = module.ecs_service_app1.service_arn
  artifact_bucket_name = module.s3_artifacts.bucket_id
  artifact_bucket_arn  = module.s3_artifacts.bucket_arn
  github_repository    = "your-github-user/aws-ecs-portfolio"
  github_branch        = "develop"
  buildspec_path       = "app1/buildspec.yml"
}

# -----------------------------------------------------------------------------
# CI/CDモジュール (App2)
# -----------------------------------------------------------------------------
module "cicd_app2" {
  source = "../../modules/cicd"

  project_name         = local.project_name
  environment          = local.environment
  service_name         = "app2"
  ecr_repository_url   = module.ecr_app2.repository_url
  ecr_repository_arn   = module.ecr_app2.repository_arn
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  ecs_cluster_arn      = module.ecs_cluster.cluster_arn
  ecs_service_name     = module.ecs_service_app2.service_name
  ecs_service_arn      = module.ecs_service_app2.service_arn
  artifact_bucket_name = module.s3_artifacts.bucket_id
  artifact_bucket_arn  = module.s3_artifacts.bucket_arn
  github_repository    = "your-github-user/aws-ecs-portfolio"
  github_branch        = "develop"
  buildspec_path       = "app2/buildspec.yml"
}

# -----------------------------------------------------------------------------
# CloudWatchモジュール (監視・アラート・ダッシュボード)
# 全リソースのメトリクス監視および異常検知・通知
# -----------------------------------------------------------------------------
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name     = local.project_name
  environment      = local.environment
  ecs_cluster_name = module.ecs_cluster.cluster_name

  ecs_services = {
    app1 = {
      service_name = module.ecs_service_app1.service_name
      min_tasks    = 1
    }
    app2 = {
      service_name = module.ecs_service_app2.service_name
      min_tasks    = 1
    }
  }

  alb_arn_suffix = module.alb.alb_arn_suffix

  target_groups = {
    app1 = {
      arn_suffix = module.alb.app1_target_group_arn_suffix
    }
    app2 = {
      arn_suffix = module.alb.app2_target_group_arn_suffix
    }
  }

  rds_instances = {
    app1 = {
      identifier      = module.rds_app1.db_identifier
      max_connections = 85 # db.t4g.micro の最大接続数（目安）
    }
    app2 = {
      identifier      = module.rds_app2.db_identifier
      max_connections = 100
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Backupモジュール (RDS・S3の定期バックアップ)
# 災害復旧およびデータ保全のための自動化された保護プラン
# -----------------------------------------------------------------------------
module "backup" {
  source = "../../modules/backup"

  project_name = local.project_name
  environment  = local.environment

  # RDSバックアップ設定
  rds_arns = [
    module.rds_app1.db_arn,
    module.rds_app2.db_arn
  ]
  rds_daily_schedule        = "cron(0 17 * * ? *)" # 毎日 02:00 JST
  rds_daily_retention_days  = 7                    # 開発環境: 期間を短縮（7日間）
  enable_weekly_backup      = true
  rds_weekly_schedule       = "cron(0 17 ? * SUN *)" # 毎週日曜 02:00 JST
  rds_weekly_retention_days = 35                     # 週次バックアップ保持: 5週間

  # S3バックアップ設定
  enable_s3_backup = true
  s3_arns = [
    module.s3_app.bucket_arn
  ]
  s3_daily_schedule = "cron(0 18 * * ? *)" # 毎日 03:00 JST
  s3_retention_days = 30                   # S3バックアップ保持: 30日間
}

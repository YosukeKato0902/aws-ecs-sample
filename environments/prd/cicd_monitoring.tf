# -----------------------------------------------------------------------------
# CI/CD・監視層 (prd)
# CodePipeline, CloudWatch
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CI/CDモジュール (App1)
# -----------------------------------------------------------------------------

module "cicd_app1" {
  source = "../../modules/cicd"

  project_name         = local.project_name
  environment          = local.environment
  service_name         = "app1"
  ecr_repository_url   = data.aws_ecr_repository.app1.repository_url
  ecr_repository_arn   = data.aws_ecr_repository.app1.arn
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  ecs_cluster_arn      = module.ecs_cluster.cluster_arn
  ecs_service_name     = module.ecs_service_app1.service_name
  ecs_service_arn      = module.ecs_service_app1.service_arn
  artifact_bucket_name = module.s3_artifacts.bucket_id
  artifact_bucket_arn  = module.s3_artifacts.bucket_arn
  github_repository    = "your-github-user/aws-ecs-portfolio"
  github_branch        = "production"
  buildspec_path       = "app1/buildspec.yml"
  trigger_on_push      = false
}

# -----------------------------------------------------------------------------
# CI/CDモジュール (App2)
# -----------------------------------------------------------------------------

module "cicd_app2" {
  source = "../../modules/cicd"

  project_name         = local.project_name
  environment          = local.environment
  service_name         = "app2"
  ecr_repository_url   = data.aws_ecr_repository.app2.repository_url
  ecr_repository_arn   = data.aws_ecr_repository.app2.arn
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  ecs_cluster_arn      = module.ecs_cluster.cluster_arn
  ecs_service_name     = module.ecs_service_app2.service_name
  ecs_service_arn      = module.ecs_service_app2.service_arn
  artifact_bucket_name = module.s3_artifacts.bucket_id
  artifact_bucket_arn  = module.s3_artifacts.bucket_arn
  github_repository    = "your-github-user/aws-ecs-portfolio"
  github_branch        = "production"
  buildspec_path       = "app2/buildspec.yml"
  trigger_on_push      = false
}

# -----------------------------------------------------------------------------
# CloudWatchモジュール (監視・アラート・ダッシュボード) - 本番設定
# -----------------------------------------------------------------------------

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name     = local.project_name
  environment      = local.environment
  ecs_cluster_name = module.ecs_cluster.cluster_name

  ecs_services = {
    app1 = {
      service_name = module.ecs_service_app1.service_name
      min_tasks    = 2 # 本番: 最低2タスク
    }
    app2 = {
      service_name = module.ecs_service_app2.service_name
      min_tasks    = 2
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
      max_connections = 354 # db.t4g.medium の最大接続数目安
    }
    app2 = {
      identifier      = module.rds_app2.db_identifier
      max_connections = 400
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Backupモジュール (RDS・S3の定期バックアップ) - 本番設定
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
  rds_daily_retention_days  = 14                   # 本番: 14日間保持
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

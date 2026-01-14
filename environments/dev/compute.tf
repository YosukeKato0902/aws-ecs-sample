# -----------------------------------------------------------------------------
# コンピュート層 (dev)
# ECSクラスター、ECSサービス、Dockerイメージ管理（ECR）の設定。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ECSクラスターモジュール
# コンテナ実行環境の論理的なグループ
# -----------------------------------------------------------------------------
module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  project_name              = local.project_name
  environment               = local.environment
  enable_container_insights = true # オブザーバビリティ（可観測性）向上のため有効化
  use_fargate_spot          = true # 開発環境: コスト削減のためFargate Spotを優先利用
  log_retention_days        = 7    # 開発環境: ストレージコスト削減のため保持期間を短縮
}

# -----------------------------------------------------------------------------
# ECRモジュール
# アプリケーションごとのDockerイメージ保存先リポジトリ
# -----------------------------------------------------------------------------
module "ecr_app1" {
  source = "../../modules/ecr"

  project_name    = local.project_name
  repository_name = "app1"
}

module "ecr_app2" {
  source = "../../modules/ecr"

  project_name    = local.project_name
  repository_name = "app2"
}

# -----------------------------------------------------------------------------
# ECSサービスモジュール (App1)
# アプリケーション本体の実行タスク管理。Blue/Greenデプロイメントに対応。
# -----------------------------------------------------------------------------
module "ecs_service_app1" {
  source = "../../modules/ecs_service"

  project_name          = local.project_name
  environment           = local.environment
  service_name          = "app1"
  cluster_arn           = module.ecs_cluster.cluster_arn
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_group.ecs_security_group_id
  target_group_arn      = module.alb.app1_target_group_arn
  container_image       = "${module.ecr_app1.repository_url}:latest"
  container_port        = var.app_port
  cpu                   = 256 # 最小構成（0.25 vCPU）
  memory                = 512 # 最小構成（0.5 GB）
  desired_count         = 1   # 定常時のタスク数
  min_capacity          = 1   # オートスケーリング最小数
  max_capacity          = 2   # オートスケーリング最大数
  log_group_name        = module.ecs_cluster.log_group_name
  health_check_path     = var.health_check_path
  s3_bucket_arn         = module.s3_app.bucket_arn
  enable_s3_access      = true
  db_secret_arn         = module.rds_app1.db_secret_arn

  # --- CodeDeploy Blue/Green デプロイメント設定 ---
  alternate_target_group_arn   = module.alb.app1_target_group_green_arn
  production_listener_rule_arn = module.alb.app1_listener_rule_arn
  test_listener_rule_arn       = module.alb.app1_test_listener_rule_arn
  validation_url               = "http://${module.alb.alb_dns_name}:10080/app1${var.health_check_path}"
  bake_time_in_minutes         = 5 # テストトラフィックでの待機時間

  # アプリケーション環境変数
  environment_variables = [
    {
      name  = "DB_HOST"
      value = module.rds_app1.db_address
    },
    {
      name  = "DB_NAME"
      value = module.rds_app1.db_name
    },
    {
      name  = "ENVIRONMENT"
      value = local.environment
    }
  ]
}

# -----------------------------------------------------------------------------
# ECSサービスモジュール (App2)
# -----------------------------------------------------------------------------
module "ecs_service_app2" {
  source = "../../modules/ecs_service"

  project_name          = local.project_name
  environment           = local.environment
  service_name          = "app2"
  cluster_arn           = module.ecs_cluster.cluster_arn
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_group.ecs_security_group_id
  target_group_arn      = module.alb.app2_target_group_arn
  container_image       = "${module.ecr_app2.repository_url}:latest"
  container_port        = var.app_port
  cpu                   = 256
  memory                = 512
  desired_count         = 1
  min_capacity          = 1
  max_capacity          = 2
  log_group_name        = module.ecs_cluster.log_group_name
  health_check_path     = var.health_check_path
  s3_bucket_arn         = module.s3_app.bucket_arn
  enable_s3_access      = true
  db_secret_arn         = module.rds_app2.db_secret_arn

  # --- CodeDeploy Blue/Green デプロイメント設定 ---
  alternate_target_group_arn   = module.alb.app2_target_group_green_arn
  production_listener_rule_arn = module.alb.app2_listener_rule_arn
  test_listener_rule_arn       = module.alb.app2_test_listener_rule_arn
  validation_url               = "http://${module.alb.alb_dns_name}:10080/app2${var.health_check_path}"
  bake_time_in_minutes         = 5

  environment_variables = [
    {
      name  = "DB_HOST"
      value = module.rds_app2.db_address
    },
    {
      name  = "DB_NAME"
      value = module.rds_app2.db_name
    },
    {
      name  = "ENVIRONMENT"
      value = local.environment
    }
  ]
}

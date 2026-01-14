# -----------------------------------------------------------------------------
# コンピュート層 (stg)
# ECS Cluster, ECS Services, ECR(Data Source)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ECSクラスターモジュール
# -----------------------------------------------------------------------------

module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  project_name              = local.project_name
  environment               = local.environment
  enable_container_insights = true # stgではContainer Insights有効
  use_fargate_spot          = true # コスト削減: Fargate Spot使用
  log_retention_days        = 14   # stgはdev より長めに保持
}

# -----------------------------------------------------------------------------
# ECRモジュール (ECRはプロジェクト共通なのでdev環境のものを参照)
# -----------------------------------------------------------------------------

data "aws_ecr_repository" "app1" {
  name = "${local.project_name}/app1"
}

data "aws_ecr_repository" "app2" {
  name = "${local.project_name}/app2"
}

# -----------------------------------------------------------------------------
# ECSサービスモジュール (App1)
# -----------------------------------------------------------------------------

module "ecs_service_app1" {
  source = "../../modules/ecs_service"

  project_name          = local.project_name
  environment           = local.environment
  service_name          = "app1"
  db_secret_arn         = module.rds_app1.db_secret_arn
  cluster_arn           = module.ecs_cluster.cluster_arn
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_group.ecs_security_group_id
  target_group_arn      = module.alb.app1_target_group_arn
  container_image       = "${data.aws_ecr_repository.app1.repository_url}:latest"
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

  # Blue/Greenデプロイメント設定
  alternate_target_group_arn   = module.alb.app1_target_group_green_arn
  production_listener_rule_arn = module.alb.app1_listener_rule_arn
  test_listener_rule_arn       = module.alb.app1_test_listener_rule_arn
  validation_url               = "http://${module.alb.alb_dns_name}:10080/app1${var.health_check_path}"
  bake_time_in_minutes         = 5

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
  db_secret_arn         = module.rds_app2.db_secret_arn
  cluster_arn           = module.ecs_cluster.cluster_arn
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_group.ecs_security_group_id
  target_group_arn      = module.alb.app2_target_group_arn
  container_image       = "${data.aws_ecr_repository.app2.repository_url}:latest"
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

  # Blue/Greenデプロイメント設定
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

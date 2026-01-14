# -----------------------------------------------------------------------------
# ネットワーク・セキュリティ層 (dev)
# VPC、セキュリティグループ、ALB、WAFの設定。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPCモジュール
# ネットワークの基盤（Subnet, Gateway, Endpoint）を構築
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name         = local.project_name
  environment          = local.environment
  region               = local.region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  nat_gateway_count    = 1    # コスト削減: 1つのみ配置
  enable_vpc_endpoints = true # 通信の効率化とセキュリティ向上のため有効化
}

# -----------------------------------------------------------------------------
# セキュリティグループモジュール
# 各レイヤー（ALB, ECS, RDS）の通信許可ルールを定義
# -----------------------------------------------------------------------------
module "security_group" {
  source = "../../modules/security_group"

  project_name = local.project_name
  environment  = local.environment
  vpc_id       = module.vpc.vpc_id
  app_port     = var.app_port
}

# -----------------------------------------------------------------------------
# ALBモジュール
# アプリケーションへのトラフィックを分散する外部公開用のロードバランサー
# -----------------------------------------------------------------------------
module "alb" {
  source = "../../modules/alb"

  project_name          = local.project_name
  environment           = local.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_group.alb_security_group_id
  certificate_arn       = var.certificate_arn
  app_port              = var.app_port
  health_check_path     = var.health_check_path
}

# -----------------------------------------------------------------------------
# WAFモジュール
# 一般的な攻撃やDDoSからALBを保護する
# -----------------------------------------------------------------------------
module "waf" {
  source = "../../modules/waf"

  project_name   = local.project_name
  environment    = local.environment
  alb_arn        = module.alb.alb_arn
  rate_limit     = 2000
  enable_logging = false # 開発環境: コスト削減のためロギング無効
}

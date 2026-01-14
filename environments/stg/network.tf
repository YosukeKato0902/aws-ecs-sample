# -----------------------------------------------------------------------------
# ネットワーク・セキュリティ層 (stg)
# VPC, Security Group, ALB, WAF
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPCモジュール
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  project_name         = local.project_name
  environment          = local.environment
  region               = local.region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  nat_gateway_count    = 1    # コスト削減: 1つのみ
  enable_vpc_endpoints = true # コスト削減: VPC Endpoints有効
}

# -----------------------------------------------------------------------------
# セキュリティグループモジュール
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
# -----------------------------------------------------------------------------

module "waf" {
  source = "../../modules/waf"

  project_name   = local.project_name
  environment    = local.environment
  alb_arn        = module.alb.alb_arn
  rate_limit     = 2000
  enable_logging = false
}

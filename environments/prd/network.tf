# -----------------------------------------------------------------------------
# ネットワーク・セキュリティ層 (prd)
# VPC, Security Group, ALB, WAF
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPCモジュール (本番用: 高可用性設定)
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  project_name         = local.project_name
  environment          = local.environment
  region               = local.region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  nat_gateway_count    = 2    # 本番: 高可用性のため2つ
  enable_vpc_endpoints = true # 本番: VPC Endpoints有効化（セキュリティ向上・コスト削減）
  enable_flow_logs     = true # 本番: VPC Flow Logs有効化（ネットワーク監査）
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
  access_logs_bucket    = module.s3_alb_logs.bucket_id # 本番: ALBアクセスログ有効化
}

# -----------------------------------------------------------------------------
# WAFモジュール (本番用設定)
# -----------------------------------------------------------------------------

# WAF用ロググループ (名称は aws-waf-logs- で始まる必要がある)
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.project_name}-${local.environment}"
  retention_in_days = 90
}

module "waf" {
  source = "../../modules/waf"

  project_name        = local.project_name
  environment         = local.environment
  alb_arn             = module.alb.alb_arn
  rate_limit          = 3000 # 本番: 若干高めのレート制限
  enable_logging      = true # 本番: ロギングを有効化
  log_destination_arn = aws_cloudwatch_log_group.waf.arn
}

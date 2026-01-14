# -----------------------------------------------------------------------------
# dev環境 メイン設定ファイル
# 全体構成、プロバイダー、共通タグ、および共通変数を定義。
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AWSプロバイダー設定
provider "aws" {
  region = var.region

  # 全リソースへの共通タグ（コスト管理や環境識別に利用）
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = "development"
      Owner       = "platform-team"
    }
  }
}

# -----------------------------------------------------------------------------
# ローカル変数
# -----------------------------------------------------------------------------
locals {
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
}

# -----------------------------------------------------------------------------
# ファイル分割構成
# 運用の見通しを良くするため、リソースの種類ごとにファイルを分割して定義。
# 
# - network.tf          : VPC, SG, ALB, WAF
# - compute.tf          : ECS, ECR
# - database.tf         : RDS, S3
# - cicd_monitoring.tf  : CodePipeline, CloudWatch, AWS Backup
# - security.tf         : Security Hub, GuardDuty, Config, CloudTrail
# -----------------------------------------------------------------------------

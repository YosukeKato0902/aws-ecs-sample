# -----------------------------------------------------------------------------
# prd環境 メインファイル
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

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = "production"
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
# リソース定義は以下のファイルに分割されています
# - network.tf: VPC, SG, ALB, WAF
# - compute.tf: ECS, ECR
# - database.tf: RDS, S3
# - cicd_monitoring.tf: CodePipeline, CloudWatch, AWS Backup
# - security.tf: Security Hub, GuardDuty, Config, CloudTrail
# -----------------------------------------------------------------------------

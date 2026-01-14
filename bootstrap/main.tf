# -----------------------------------------------------------------------------
# tfstate管理用S3バケットとDynamoDBテーブルを作成
# 初回のみローカルで実行し、その後は各環境のbackend.tfで参照
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
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project   = "ecs-web-app"
      ManagedBy = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "ecs-web-app"
}

# -----------------------------------------------------------------------------
# tfstate用S3バケット
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

# バージョニング有効化
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# サーバーサイド暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# パブリックアクセスブロック
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# tfstateロック用DynamoDBテーブル
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "${var.project_name}-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# データソース
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# 出力
# -----------------------------------------------------------------------------

output "tfstate_bucket_name" {
  description = "tfstate用S3バケット名"
  value       = aws_s3_bucket.tfstate.id
}

output "tfstate_bucket_arn" {
  description = "tfstate用S3バケットARN"
  value       = aws_s3_bucket.tfstate.arn
}

output "dynamodb_table_name" {
  description = "tfstateロック用DynamoDBテーブル名"
  value       = aws_dynamodb_table.tfstate_lock.name
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC 認証設定
# GitHub ActionsからAWSリソースにアクセスするための設定
# -----------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHubリポジトリ名（owner/repo形式）"
  type        = string
  default     = "your-github-user/aws-ecs-portfolio"
}

variable "create_github_oidc" {
  description = "GitHub OIDC認証リソースを作成するか"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# GitHub OIDC プロバイダー
# -----------------------------------------------------------------------------

# GitHub OIDCプロバイダーの作成
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHubのサムプリント（固定値）
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "github-actions-oidc"
  }
}

# -----------------------------------------------------------------------------
# GitHub Actions用IAMロール（dev環境）
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_dev" {
  count = var.create_github_oidc ? 1 : 0

  name = "github-actions-${var.project_name}-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # developブランチからのアクセスのみ許可
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/develop"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "github-actions-${var.project_name}-dev"
    Environment = "dev"
  }
}

# dev環境用の権限ポリシー
resource "aws_iam_role_policy_attachment" "github_actions_dev" {
  count = var.create_github_oidc ? 1 : 0

  role       = aws_iam_role.github_actions_dev[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# GitHub Actions用IAMロール（stg環境）
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_stg" {
  count = var.create_github_oidc ? 1 : 0

  name = "github-actions-${var.project_name}-stg"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # stagingブランチからのアクセスのみ許可
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/staging"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "github-actions-${var.project_name}-stg"
    Environment = "stg"
  }
}

# stg環境用の権限ポリシー
resource "aws_iam_role_policy_attachment" "github_actions_stg" {
  count = var.create_github_oidc ? 1 : 0

  role       = aws_iam_role.github_actions_stg[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# GitHub Actions用IAMロール（prd環境）
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_prd" {
  count = var.create_github_oidc ? 1 : 0

  name = "github-actions-${var.project_name}-prd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # productionブランチからのアクセスのみ許可
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/production"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "github-actions-${var.project_name}-prd"
    Environment = "prd"
  }
}

# prd環境用の権限ポリシー
resource "aws_iam_role_policy_attachment" "github_actions_prd" {
  count = var.create_github_oidc ? 1 : 0

  role       = aws_iam_role.github_actions_prd[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC 出力
# -----------------------------------------------------------------------------

output "github_oidc_provider_arn" {
  description = "GitHub OIDC プロバイダーARN"
  value       = var.create_github_oidc ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "github_actions_role_arn_dev" {
  description = "GitHub Actions用IAMロールARN（dev環境）- GitHub Secretsに設定: AWS_ROLE_ARN_DEV"
  value       = var.create_github_oidc ? aws_iam_role.github_actions_dev[0].arn : null
}

output "github_actions_role_arn_stg" {
  description = "GitHub Actions用IAMロールARN（stg環境）- GitHub Secretsに設定: AWS_ROLE_ARN_STG"
  value       = var.create_github_oidc ? aws_iam_role.github_actions_stg[0].arn : null
}

output "github_actions_role_arn_prd" {
  description = "GitHub Actions用IAMロールARN（prd環境）- GitHub Secretsに設定: AWS_ROLE_ARN_PRD"
  value       = var.create_github_oidc ? aws_iam_role.github_actions_prd[0].arn : null
}

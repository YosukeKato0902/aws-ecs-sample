# -----------------------------------------------------------------------------
# S3モジュール
# オブジェクトストレージ基盤（Bucket, Versioning, Encryption, Policy）を定義。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# S3バケット本体: データの永続化領域を確保
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "main" {
  # バケット名はグローバルで一意とするためアカウントIDを付与
  bucket = "${var.project_name}-${var.environment}-${var.bucket_name}-${data.aws_caller_identity.current.account_id}"
  # 開発環境等でバケット内のオブジェクトごと削除を許可する場合に使用
  force_destroy = var.force_destroy

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.bucket_name}"
  }
}

# -----------------------------------------------------------------------------
# バージョニング設定: 誤削除・誤上書きからの復旧を可能とする履歴管理
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# -----------------------------------------------------------------------------
# サーバーサイド暗号化: 保存データの透過的な暗号化保護
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # 標準の暗号化方式（SSE-S3）を使用
    }
  }
}

# -----------------------------------------------------------------------------
# パブリックアクセスブロック: インターネット公開をバケットレベルで強制拒否
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# ライフサイクル設定: 古いファイルの自動移行・削除
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    # 90日経過したファイルを安価なGlacierストレージへ移行
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # 以前のバージョン（履歴）を30日後にGlacierへ移行
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    # 以前のバージョンを1年（365日）後に完全に削除
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# -----------------------------------------------------------------------------
# CORS設定: ブラウザからの直接アクセスを許可（必要な場合のみ設定）
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_cors_configuration" "main" {
  count  = length(var.cors_allowed_origins) > 0 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# -----------------------------------------------------------------------------
# データソース: 現在のアカウント情報の取得
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ALBアクセスログを受け入れるために必要な、リージョン別のELB専用AWSアカウントIDを取得
data "aws_elb_service_account" "main" {}

# -----------------------------------------------------------------------------
# バケットポリシー設定（外部サービスからの書き込みを許可）
# ALBアクセスログ、CloudTrail、AWS Config等のデータを保存するために必要
# -----------------------------------------------------------------------------

# ALBアクセスログ用
data "aws_iam_policy_document" "alb_logs" {
  count = var.enable_alb_logs ? 1 : 0

  # 最新の方式（ELBサービスプリンシパル経由）
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.main.arn]
  }

  # 従来の方式（特定のアカウントID経由）※リージョンによっては必須となる
  statement {
    sid    = "ELBAccessLogs"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }
}

# CloudTrailログ用
data "aws_iam_policy_document" "cloudtrail" {
  count = var.allow_cloudtrail ? 1 : 0

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.main.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]
    # AWS推奨の条件（バケット所有者のフルコントロール確認）を付与
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# AWS Configログ用
data "aws_iam_policy_document" "config" {
  count = var.allow_config ? 1 : 0

  statement {
    sid    = "AWSConfigAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.main.arn]
  }

  statement {
    sid    = "AWSConfigWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# 選択された各ポリシーを1つに統合するドキュメントを作成
data "aws_iam_policy_document" "combined" {
  source_policy_documents = compact([
    var.enable_alb_logs ? data.aws_iam_policy_document.alb_logs[0].json : "",
    var.allow_cloudtrail ? data.aws_iam_policy_document.cloudtrail[0].json : "",
    var.allow_config ? data.aws_iam_policy_document.config[0].json : ""
  ])
}

# 実際にバケットへポリシーを適用するリソース
resource "aws_s3_bucket_policy" "main" {
  count  = (var.enable_alb_logs || var.allow_cloudtrail || var.allow_config) ? 1 : 0
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.combined.json

  # 公開ブロック設定の完了後にポリシーを適用（依存関係を明示）
  depends_on = [aws_s3_bucket_public_access_block.main]
}


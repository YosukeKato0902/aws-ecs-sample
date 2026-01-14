# -----------------------------------------------------------------------------
# AWS Config モジュール
# このモジュールは、AWSリソースの設定変更を継続的に記録し、
# 構成履歴の保存およびベストプラクティスに基づいた設定監査を可能にする。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Config レコーダー用IAMロール
# AWS Configサービスがリソースの設定情報を読み取り、S3へ出力するための権限
# -----------------------------------------------------------------------------
resource "aws_iam_role" "config" {
  name = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-config-role"
  }
}

# AWS管理ポリシーの適用（Configサービスに必要な標準権限）
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# ログ保存先S3バケットへの書き込み権限
resource "aws_iam_role_policy" "config_s3" {
  name = "${var.project_name}-${var.environment}-config-s3-policy"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.config_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl"
        Resource = var.config_bucket_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Config レコーダー
# 記録対象のリソース（全サポートリソース）を定義する
# -----------------------------------------------------------------------------
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.environment}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true # 対応する全リソースを記録対象とする
  }
}

# -----------------------------------------------------------------------------
# Config 配信チャネル
# 記録した情報の出力先（S3バケット）を指定する
# -----------------------------------------------------------------------------
resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-${var.environment}-delivery-channel"
  s3_bucket_name = var.config_bucket_name

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# Config レコーダーの有効化
# 定義したレコーダーを実際に「記録中」の状態にする
# -----------------------------------------------------------------------------
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

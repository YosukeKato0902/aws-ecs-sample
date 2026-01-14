# -----------------------------------------------------------------------------
# CloudTrail モジュール
# このモジュールは、AWSアカウント内の全リージョンにおけるAPI操作を記録し、
# 監査やトラブルシューティングのためのログをS3およびCloudWatch Logsへ出力する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CloudTrail 本体
# -----------------------------------------------------------------------------
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-trail"
  s3_bucket_name                = var.trail_bucket_name # ログの保存先S3バケット名
  include_global_service_events = true                  # IAM等のグローバルサービスのイベントを含める
  is_multi_region_trail         = true                  # 全リージョンのログを単一の証跡に集約する
  enable_logging                = true                  # ログ記録を有効化

  # CloudWatch Logs連携設定 (管理コンソールでの検索性が向上)
  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? "${var.cloudwatch_log_group_arn}:*" : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail_cloudwatch[0].arn : null

  # データイベント記録の設定
  event_selector {
    read_write_type           = "All" # 読み取り・書き込みの両方のイベントを記録
    include_management_events = true  # マネジメントイベント（リソース作成等）を記録

    # S3バケット内のオブジェクト操作（データイベント）を記録する設定 (オプション)
    dynamic "data_resource" {
      for_each = var.enable_s3_logging ? [1] : []
      content {
        type   = "AWS::S3::Object"
        values = ["arn:aws:s3"] # 全てのS3バケットを対象とする（必要に応じて絞り込み可）
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-trail"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Logs連携用IAMロール (オプション)
# CloudTrailサービスがCloudWatch Logsへログを書き込むための権限
# -----------------------------------------------------------------------------
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-cloudtrail-cw-role"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Logs連携用IAMポリシー
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-cloudtrail-cw-policy"
  role  = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${var.cloudwatch_log_group_arn}:*"
      }
    ]
  })
}

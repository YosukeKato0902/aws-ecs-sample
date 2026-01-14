# -----------------------------------------------------------------------------
# CloudTrail モジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "trail_bucket_name" {
  description = "CloudTrailログ保存用S3バケット名"
  type        = string
}

variable "cloudwatch_log_group_arn" {
  description = "CloudWatch Logs連携用ロググループARN (空の場合は無効)"
  type        = string
  default     = ""
}

variable "enable_s3_logging" {
  description = "S3データイベントのログ記録を有効化するか"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_logs" {
  description = "CloudWatch Logsへの転送を有効化するか"
  type        = bool
  default     = false
}

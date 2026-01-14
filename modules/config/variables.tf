# -----------------------------------------------------------------------------
# AWS Config モジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "config_bucket_name" {
  description = "Config設定履歴保存用S3バケット名"
  type        = string
}

variable "config_bucket_arn" {
  description = "Config設定履歴保存用S3バケットARN"
  type        = string
}

# -----------------------------------------------------------------------------
# WAFモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "alb_arn" {
  description = "ALBのARN"
  type        = string
}

variable "rate_limit" {
  description = "5分間あたりのリクエストレート制限"
  type        = number
  default     = 2000
}

variable "enable_logging" {
  description = "WAFロギングを有効化するか"
  type        = bool
  default     = false
}

variable "log_destination_arn" {
  description = "ログ送信先のARN (Kinesis Firehose or CloudWatch Logs)"
  type        = string
  default     = ""
}

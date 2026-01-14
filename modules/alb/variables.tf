# -----------------------------------------------------------------------------
# ALBモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "パブリックサブネットIDのリスト"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB用セキュリティグループID"
  type        = string
}

variable "certificate_arn" {
  description = "ACM証明書のARN (空の場合はHTTPのみ)"
  type        = string
  default     = ""
}

variable "app_port" {
  description = "アプリケーションのポート番号"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ヘルスチェックのパス"
  type        = string
  default     = "/health"
}

variable "access_logs_bucket" {
  description = "アクセスログ用S3バケット名（空の場合はログ無効）"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# セキュリティグループモジュール 変数定義
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

variable "app_port" {
  description = "アプリケーションのポート番号"
  type        = number
  default     = 8080
}

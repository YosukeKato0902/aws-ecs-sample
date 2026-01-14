# -----------------------------------------------------------------------------
# prd環境 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "ecs-web-app"
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = "prd"
}

variable "region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "app_port" {
  description = "アプリケーションのポート番号"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "ヘルスチェックのパス"
  type        = string
  default     = "/"
}

variable "certificate_arn" {
  description = "ACM証明書のARN"
  type        = string
  default     = ""
}

variable "db_password_app1" {
  description = "App1のDBパスワード（Secrets Manager利用のため実際には未使用だがCI/CDで必要）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_password_app2" {
  description = "App2のDBパスワード（Secrets Manager利用のため実際には未使用だがCI/CDで必要）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alert_email" {
  description = "CloudWatchアラートの通知先メールアドレス"
  type        = string
  default     = ""
}



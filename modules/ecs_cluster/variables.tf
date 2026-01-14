# -----------------------------------------------------------------------------
# ECSクラスターモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "enable_container_insights" {
  description = "Container Insightsを有効化するか"
  type        = bool
  default     = true
}

variable "use_fargate_spot" {
  description = "Fargate Spotを使用するか (コスト削減用)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logsの保持日数"
  type        = number
  default     = 30
}

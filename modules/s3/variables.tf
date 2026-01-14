# -----------------------------------------------------------------------------
# S3モジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "bucket_name" {
  description = "バケット名 (サフィックス)"
  type        = string
}

variable "enable_versioning" {
  description = "バージョニングを有効化するか"
  type        = bool
  default     = true
}

variable "enable_lifecycle_rules" {
  description = "ライフサイクルルールを有効化するか"
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "CORS許可オリジンのリスト"
  type        = list(string)
  default     = []
}

variable "enable_alb_logs" {
  description = "ALBアクセスログ用バケットポリシーを有効化するか"
  type        = bool
  default     = false
}


variable "allow_cloudtrail" {
  description = "CloudTrailからの書き込みを許可するか"
  type        = bool
  default     = false
}

variable "allow_config" {
  description = "AWS Configからの書き込みを許可するか"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "バケット削除時にオブジェクトを強制削除するか"
  type        = bool
  default     = false
}

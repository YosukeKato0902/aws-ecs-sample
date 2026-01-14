# -----------------------------------------------------------------------------
# 入力変数
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev, stg, prd)"
  type        = string
}

# -----------------------------------------------------------------------------
# RDSバックアップ設定
# -----------------------------------------------------------------------------

variable "rds_arns" {
  description = "バックアップ対象のRDSインスタンスARNリスト"
  type        = list(string)
}

variable "rds_daily_schedule" {
  description = "RDS日次バックアップスケジュール (cron形式、UTC)"
  type        = string
  default     = "cron(0 17 * * ? *)" # 毎日 02:00 JST (17:00 UTC)
}

variable "rds_daily_retention_days" {
  description = "RDS日次バックアップ保持日数"
  type        = number
  default     = 7
}

variable "enable_weekly_backup" {
  description = "週次バックアップを有効にするか"
  type        = bool
  default     = true
}

variable "rds_weekly_schedule" {
  description = "RDS週次バックアップスケジュール (cron形式、UTC)"
  type        = string
  default     = "cron(0 17 ? * SUN *)" # 毎週日曜 02:00 JST
}

variable "rds_weekly_retention_days" {
  description = "RDS週次バックアップ保持日数"
  type        = number
  default     = 35 # 5週間
}

# -----------------------------------------------------------------------------
# S3バックアップ設定
# -----------------------------------------------------------------------------

variable "enable_s3_backup" {
  description = "S3バックアップを有効にするか"
  type        = bool
  default     = true
}

variable "s3_arns" {
  description = "バックアップ対象のS3バケットARNリスト"
  type        = list(string)
  default     = []
}

variable "s3_daily_schedule" {
  description = "S3日次バックアップスケジュール (cron形式、UTC)"
  type        = string
  default     = "cron(0 18 * * ? *)" # 毎日 03:00 JST (18:00 UTC)
}

variable "s3_retention_days" {
  description = "S3バックアップ保持日数"
  type        = number
  default     = 30
}

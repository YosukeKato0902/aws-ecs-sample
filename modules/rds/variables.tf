# -----------------------------------------------------------------------------
# RDSモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "db_name" {
  description = "データベース名"
  type        = string
}

variable "private_subnet_ids" {
  description = "プライベートサブネットIDのリスト"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "RDS用セキュリティグループID"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQLのバージョン"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDSインスタンスクラス"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "初期ストレージサイズ (GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "最大ストレージサイズ (GB) - オートスケーリング"
  type        = number
  default     = 100
}

variable "db_username" {
  description = "マスターユーザー名"
  type        = string
  default     = "postgres"
}



variable "backup_retention_period" {
  description = "バックアップ保持期間 (日)"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "マルチAZ配置を有効化するか"
  type        = bool
  default     = false
}

variable "recovery_window_in_days" {
  description = "Secrets Manager削除時の復旧期間 (日)。0=即時削除、7-30=復旧可能期間"
  type        = number
  default     = 0
}

variable "performance_insights_enabled" {
  description = "Performance Insightsを有効化するか"
  type        = bool
  default     = false
}


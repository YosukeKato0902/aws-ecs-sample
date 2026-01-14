# -----------------------------------------------------------------------------
# CloudWatchモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECSクラスター名"
  type        = string
}

variable "ecs_services" {
  description = "ECSサービス情報のマップ"
  type = map(object({
    service_name = string
    min_tasks    = number
  }))
}

variable "alb_arn_suffix" {
  description = "ALBのARNサフィックス"
  type        = string
}

variable "target_groups" {
  description = "ターゲットグループ情報のマップ"
  type = map(object({
    arn_suffix = string
  }))
}

variable "rds_instances" {
  description = "RDSインスタンス情報のマップ"
  type = map(object({
    identifier      = string
    max_connections = number
  }))
}

variable "alert_email" {
  description = "アラート通知先メールアドレス（空の場合はサブスクリプション作成しない）"
  type        = string
  default     = ""
}

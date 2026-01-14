# -----------------------------------------------------------------------------
# ECSサービスモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "service_name" {
  description = "サービス名 (app1/app2)"
  type        = string
}

variable "cluster_arn" {
  description = "ECSクラスターARN"
  type        = string
}

variable "cluster_name" {
  description = "ECSクラスター名"
  type        = string
}

variable "private_subnet_ids" {
  description = "プライベートサブネットIDのリスト"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS用セキュリティグループID"
  type        = string
}

variable "target_group_arn" {
  description = "ターゲットグループARN"
  type        = string
}

variable "container_image" {
  description = "コンテナイメージURI"
  type        = string
}

variable "container_port" {
  description = "コンテナのポート番号"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "タスクのCPUユニット"
  type        = number
  default     = 256
}

variable "memory" {
  description = "タスクのメモリ (MB)"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "起動するタスク数"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Auto Scalingの最小タスク数"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Auto Scalingの最大タスク数"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "CPU使用率のターゲット値 (%)"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "メモリ使用率のターゲット値 (%)"
  type        = number
  default     = 80
}

variable "log_group_name" {
  description = "CloudWatch Logsロググループ名"
  type        = string
}

variable "health_check_path" {
  description = "ヘルスチェックのパス"
  type        = string
  default     = "/health"
}

variable "environment_variables" {
  description = "環境変数のリスト"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "db_secret_arn" {
  description = "DBパスワードが格納されたSecrets ManagerのARN"
  type        = string
}

variable "enable_s3_access" {
  description = "S3アクセスを有効にするか"
  type        = bool
  default     = false
}

variable "s3_bucket_arn" {
  description = "アクセス許可するS3バケットARN"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Blue/Greenデプロイメント設定
# -----------------------------------------------------------------------------

variable "alternate_target_group_arn" {
  description = "Blue/Green用のグリーンターゲットグループARN"
  type        = string
}

variable "production_listener_rule_arn" {
  description = "本番トラフィック用リスナールールARN"
  type        = string
}

variable "bake_time_in_minutes" {
  description = "ベイク時間（分）: トラフィック切替後、旧バージョン削除までの待機時間"
  type        = number
  default     = 5
}

variable "test_listener_rule_arn" {
  description = "Blue/Green検証用テストリスナールールARN"
  type        = string
}

variable "validation_url" {
  description = "検証用URL (例: http://alb-dns-name:10080/app1/health)"
  type        = string
}

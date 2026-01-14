# -----------------------------------------------------------------------------
# CI/CDモジュール 変数定義
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
  description = "サービス名"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECRリポジトリURL"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECSクラスター名"
  type        = string
}

variable "ecs_service_name" {
  description = "ECSサービス名"
  type        = string
}

variable "artifact_bucket_name" {
  description = "アーティファクト用S3バケット名"
  type        = string
}

variable "artifact_bucket_arn" {
  description = "アーティファクト用S3バケットARN"
  type        = string
}

variable "buildspec_path" {
  description = "buildspec.ymlのパス"
  type        = string
  default     = "buildspec.yml"
}

variable "github_repository" {
  description = "GitHubリポジトリ (例: owner/repo)"
  type        = string
}

variable "github_branch" {
  description = "対象ブランチ名"
  type        = string
  default     = "main"
}

variable "trigger_on_push" {
  description = "GitHubへのPushをトリガーにするか (prd環境ではfalse推奨)"
  type        = bool
  default     = true
}

variable "ecr_repository_arn" {
  description = "ECRリポジトリARN（IAM最小権限用）"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ECSクラスターARN（IAM最小権限用）"
  type        = string
}

variable "ecs_service_arn" {
  description = "ECSサービスARN（IAM最小権限用）"
  type        = string
  default     = ""
}


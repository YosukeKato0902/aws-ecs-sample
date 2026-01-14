# -----------------------------------------------------------------------------
# ECRモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "repository_name" {
  description = "リポジトリ名"
  type        = string
}

variable "enable_cross_account_access" {
  description = "クロスアカウントアクセスを有効化するか"
  type        = bool
  default     = false
}

variable "cross_account_principals" {
  description = "クロスアカウントアクセスを許可するAWSプリンシパル"
  type        = list(string)
  default     = []
}

variable "image_tag_mutability" {
  description = "イメージタグの変更可能性 (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}


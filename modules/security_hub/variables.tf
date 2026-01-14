# -----------------------------------------------------------------------------
# Security Hub モジュール 変数定義
# -----------------------------------------------------------------------------

variable "enable_cis_standard" {
  description = "CIS AWS Foundations Benchmark標準を有効化するか"
  type        = bool
  default     = false
}

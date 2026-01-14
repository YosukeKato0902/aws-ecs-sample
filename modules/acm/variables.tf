# -----------------------------------------------------------------------------
# ACMモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "domain_name" {
  description = "証明書のドメイン名"
  type        = string
}

variable "subject_alternative_names" {
  description = "SAN (Subject Alternative Names)"
  type        = list(string)
  default     = []
}

variable "create_route53_records" {
  description = "Route53でDNS検証レコードを作成するか"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53ホストゾーンID"
  type        = string
  default     = ""
}

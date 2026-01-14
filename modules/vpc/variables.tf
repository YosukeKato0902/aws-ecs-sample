# -----------------------------------------------------------------------------
# VPCモジュール 変数定義
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名 (dev/stg/prd)"
  type        = string
}

variable "region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "nat_gateway_count" {
  description = "作成するNAT Gatewayの数"
  type        = number
  default     = 1
}

variable "enable_vpc_endpoints" {
  description = "VPC Endpointsを有効化するか (コスト削減用)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "VPC Flow Logsを有効化するか"
  type        = bool
  default     = false
}


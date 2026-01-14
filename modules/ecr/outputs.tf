# -----------------------------------------------------------------------------
# ECRモジュール 出力定義
# -----------------------------------------------------------------------------

output "repository_url" {
  description = "ECRリポジトリURL"
  value       = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  description = "ECRリポジトリARN"
  value       = aws_ecr_repository.main.arn
}

output "repository_name" {
  description = "ECRリポジトリ名"
  value       = aws_ecr_repository.main.name
}

output "registry_id" {
  description = "ECRレジストリID"
  value       = aws_ecr_repository.main.registry_id
}

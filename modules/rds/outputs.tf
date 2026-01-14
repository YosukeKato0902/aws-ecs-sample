# -----------------------------------------------------------------------------
# RDSモジュール 出力定義
# -----------------------------------------------------------------------------

output "db_address" {
  description = "RDSインスタンスのアドレス"
  value       = aws_db_instance.main.address
}

output "db_identifier" {
  description = "RDSインスタンス識別子"
  value       = aws_db_instance.main.identifier
}

output "db_name" {
  description = "データベース名"
  value       = aws_db_instance.main.db_name
}

output "db_endpoint" {
  description = "RDSインスタンスのエンドポイント (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_secret_arn" {
  description = "DBパスワード格納Secrets ManagerのARN"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_arn" {
  description = "RDSインスタンスのARN"
  value       = aws_db_instance.main.arn
}

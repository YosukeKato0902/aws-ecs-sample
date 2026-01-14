# -----------------------------------------------------------------------------
# 出力値
# -----------------------------------------------------------------------------

output "backup_vault_arn" {
  description = "バックアップボルトのARN"
  value       = aws_backup_vault.main.arn
}

output "backup_vault_name" {
  description = "バックアップボルト名"
  value       = aws_backup_vault.main.name
}

output "backup_role_arn" {
  description = "バックアップ用IAMロールのARN"
  value       = aws_iam_role.backup.arn
}

output "rds_backup_plan_id" {
  description = "RDSバックアッププランID"
  value       = aws_backup_plan.rds.id
}

output "rds_backup_plan_arn" {
  description = "RDSバックアッププランARN"
  value       = aws_backup_plan.rds.arn
}

output "s3_backup_plan_id" {
  description = "S3バックアッププランID"
  value       = var.enable_s3_backup ? aws_backup_plan.s3[0].id : null
}

output "s3_backup_plan_arn" {
  description = "S3バックアッププランARN"
  value       = var.enable_s3_backup ? aws_backup_plan.s3[0].arn : null
}

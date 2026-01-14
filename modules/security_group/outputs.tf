# -----------------------------------------------------------------------------
# セキュリティグループモジュール 出力定義
# -----------------------------------------------------------------------------

output "alb_security_group_id" {
  description = "ALB用セキュリティグループID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS用セキュリティグループID"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "RDS用セキュリティグループID"
  value       = aws_security_group.rds.id
}

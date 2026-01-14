# -----------------------------------------------------------------------------
# prd環境 出力定義
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "ALBのDNS名"
  value       = module.alb.alb_dns_name
}

output "rds_app1_endpoint" {
  description = "App1用RDSエンドポイント"
  value       = module.rds_app1.db_endpoint
}

output "rds_app2_endpoint" {
  description = "App2用RDSエンドポイント"
  value       = module.rds_app2.db_endpoint
}

output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = module.ecs_cluster.cluster_name
}

output "s3_app_bucket" {
  description = "アプリ用S3バケット名"
  value       = module.s3_app.bucket_id
}

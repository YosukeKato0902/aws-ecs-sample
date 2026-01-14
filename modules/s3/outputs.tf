# -----------------------------------------------------------------------------
# S3モジュール 出力定義
# -----------------------------------------------------------------------------

output "bucket_id" {
  description = "S3バケットID"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "S3バケットARN"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "S3バケットドメイン名"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3バケットリージョナルドメイン名"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

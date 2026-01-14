# -----------------------------------------------------------------------------
# prd環境 S3バックエンド設定
# -----------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "ecs-web-app-tfstate-123456789012"
    key            = "prd/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "ecs-web-app-tfstate-lock"
  }
}

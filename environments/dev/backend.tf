# -----------------------------------------------------------------------------
# dev環境 S3バックエンド設定
# 事前にbootstrapでS3バケットとDynamoDBテーブルを作成しておくこと
# -----------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "ecs-web-app-tfstate-123456789012" # 実際のアカウントIDに置き換え
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "ecs-web-app-tfstate-lock"
  }
}

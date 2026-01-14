# -----------------------------------------------------------------------------
# ECSクラスターモジュール
# このモジュールは、ECSタスクを実行するための論理的なグループであるクラスター、
# 実行基盤（Fargate）の設定、および共通のロググループを定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ECSクラスター本体
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  # Container Insightsの設定: 有効化によりCPUやメモリの詳細なメトリクスを収集する
  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# -----------------------------------------------------------------------------
# キャパシティプロバイダー設定
# FargateおよびFargate Spotの使用を許可し、デフォルトの起動戦略を定義する
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  # 利用可能なキャパシティプロバイダーの一覧
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # デフォルトの戦略: タスク起動時に明示的な指定がない場合に適用される
  default_capacity_provider_strategy {
    base              = 1   # 最低1タスクはFARGATE（通常）で起動することを保障
    weight            = 100 # 重み付けによる配分比率
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Logsロググループ
# クラスターに属する各コンテナが出力する標準ログの集約先
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days # ログの保存日数（変数を参照）

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-logs"
  }
}

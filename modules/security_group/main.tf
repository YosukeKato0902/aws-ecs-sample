# -----------------------------------------------------------------------------
# セキュリティグループモジュール
# このモジュールは、ALB、ECS、RDSそれぞれのレイヤーにおける
# インバウンド・アウトバウンド通信を制御するための「仮想ファイアウォール」を定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ALB用セキュリティグループ
# インターネットからのHTTP/HTTPSアクセスを待ち受ける
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "ALB Security Group - Allow HTTP/HTTPS traffic"
  vpc_id      = var.vpc_id

  # HTTPS通信の許可
  ingress {
    description = "Allow HTTPS traffic from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP通信の許可 (主にHTTPSへのリダイレクトに使用)
  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # テスト用HTTP通信の許可 (Blue/Greenデプロイ時の検証用ポート)
  ingress {
    description = "Allow Test HTTP traffic"
    from_port   = 10080
    to_port     = 10080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 検証時は必要に応じてIP制限の追加を推奨
  }

  # 外部への全通信の許可
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# ECS用セキュリティグループ
# ロードバランサー（ALB）からの通信のみを許可し、直接のアクセスを遮断する
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "ECS Security Group - Allow traffic only from ALB"
  vpc_id      = var.vpc_id

  # ALBからのアプリケーション通信のみを許可
  ingress {
    description     = "Allow traffic from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # 送信元をALBのSGに限定
  }

  # 外部への全通信の許可 (イメージの取得や外部API通信に必要)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-sg"
  }
}

# -----------------------------------------------------------------------------
# RDS用セキュリティグループ
# アプリケーションサーバー（ECS）からのデータベース接続のみを許可する
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "RDS Security Group - Allow traffic only from ECS"
  vpc_id      = var.vpc_id

  # ECSからのPostgreSQL接続を許可
  ingress {
    description     = "Allow PostgreSQL traffic from ECS only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id] # 送信元をECSのSGに限定
  }

  # 外部への全通信の許可 (通常RDSからの発信は不要だが、運用上のトラブル防止のため許可)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

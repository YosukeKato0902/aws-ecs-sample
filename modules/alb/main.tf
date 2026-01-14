# -----------------------------------------------------------------------------
# ALB（Application Load Balancer）モジュール
# このモジュールは、ロードバランサー本体、各種ポートのリスナー、
# およびアプリケーションを振り分けるターゲットグループを定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Application Load Balancer 本体
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false                       # 外部公開用（インターネット向け）
  load_balancer_type = "application"               # HTTP/HTTPSを扱うL7ロードバランサー
  security_groups    = [var.alb_security_group_id] # 適用するセキュリティグループ
  subnets            = var.public_subnet_ids       # パブリックサブネットに配置

  # 削除保護設定（本番環境では誤削除防止のため有効化）
  enable_deletion_protection = var.environment == "prd" ? true : false

  # アクセスログの保存設定（S3バケットが指定されている場合のみ動的に作成）
  dynamic "access_logs" {
    for_each = var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "alb/${var.project_name}-${var.environment}"
      enabled = true
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# -----------------------------------------------------------------------------
# HTTPSリスナー: ポート443でのアクセスを待ち受け
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0 # 証明書がある場合のみ作成
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # セキュリティポリシー（TLS1.3推奨）
  certificate_arn   = var.certificate_arn                   # SSL証明書のARN

  # デフォルトアクション: ルールに合致しない場合は404を返す
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# -----------------------------------------------------------------------------
# HTTPリスナー: ポート80でのアクセスを待ち受け
# HTTPSが有効な場合はリダイレクトを行い、そうでない場合はルーティングする
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    # 証明書がある場合はHTTPS(443)にリダイレクト、なければ固定レスポンス
    type = var.certificate_arn != "" ? "redirect" : "fixed-response"

    # HTTPSへのリダイレクト設定
    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301" # 恒久的なリダイレクト
      }
    }

    # 固定レスポンス設定（HTTPS未使用時）
    dynamic "fixed_response" {
      for_each = var.certificate_arn == "" ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Not Found"
        status_code  = "404"
      }
    }
  }
}


# テスト用リスナー（ポート10080）: Blue/Greenデプロイ時の検証トラフィック用
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = "10080" # 開発・テスト用の特設ポート
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found (Test Listener)"
      status_code  = "404"
    }
  }
}

# -----------------------------------------------------------------------------
# ターゲットグループ: トラフィックの配布先（ECSタスク）を定義
# -----------------------------------------------------------------------------

# App1用ターゲットグループ (Blue)
resource "aws_lb_target_group" "app1" {
  name        = "${var.project_name}-${var.environment}-app1-tg"
  port        = var.app_port # コンテナのポート
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate利用のためIPターゲット

  health_check {
    enabled             = true
    healthy_threshold   = 2                     # 2回成功で正常とみなす
    interval            = 30                    # 30秒間隔でチェック
    matcher             = "200"                 # HTTP 200を期待
    path                = var.health_check_path # ヘルスチェック用パス
    port                = "traffic-port"        # 通信用ポートと同じポートを使用
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3 # 3回失敗で異常とみなす
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app1-tg"
  }
}

# App1用ターゲットグループ (Green)
resource "aws_lb_target_group" "app1_green" {
  name        = "${var.project_name}-${var.environment}-app1-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app1-tg-green"
  }
}

# -----------------------------------------------------------------------------
# App2用ターゲットグループ（こちらも2セット）
# -----------------------------------------------------------------------------

# 通常稼働用
resource "aws_lb_target_group" "app2" {
  name        = "${var.project_name}-${var.environment}-app2-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app2-tg"
  }
}

# デプロイ用（Green）
resource "aws_lb_target_group" "app2_green" {
  name        = "${var.project_name}-${var.environment}-app2-tg-green"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app2-tg-green"
  }
}

# -----------------------------------------------------------------------------
# リスナールール: パスベースルーティングの設定
# -----------------------------------------------------------------------------

# App1への振り分け（HTTPS）
resource "aws_lb_listener_rule" "app1_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100 # 優先順位（小さいほど先に評価される）

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1.arn
  }

  condition {
    path_pattern {
      values = ["/app1/*", "/app1"] # 指定のパスに来たリクエストを転送
    }
  }

  # Blue/Greenデプロイ時にCodeDeployがaction（ターゲットグループ）を動的に変更するため
  # Terraform側で意図した変更を上書きしないよう除外設定
  lifecycle {
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "app2_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 200 # 優先順位

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app2.arn
  }

  condition {
    path_pattern {
      values = ["/app2/*", "/app2"] # 指定のパスに来たリクエストを転送
    }
  }

  # 【重要】Blue/Greenデプロイ時にECSがこのルール（宛先TG）を直接書き換えるため
  # Terraformが「設定と違う」と戻してしまわないよう、監視対象から除外
  lifecycle {
    ignore_changes = [action]
  }
}

# -----------------------------------------------------------------------------
# HTTP用 パスベースルーティングルール（証明書がない開発環境等用）
# -----------------------------------------------------------------------------
resource "aws_lb_listener_rule" "app1_http" {
  count        = var.certificate_arn == "" ? 1 : 0 # 証明書がない場合のみ作成
  listener_arn = aws_lb_listener.http.arn
  priority     = 100 # 優先順位

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1.arn
  }

  condition {
    path_pattern {
      values = ["/app1/*", "/app1"]
    }
  }

  # 【重要】Blue/Greenデプロイ時にECSがルールを書き換えるため、監視から除外
  lifecycle {
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "app2_http" {
  count        = var.certificate_arn == "" ? 1 : 0 # 証明書がない場合のみ作成
  listener_arn = aws_lb_listener.http.arn
  priority     = 200 # 優先順位

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app2.arn
  }

  condition {
    path_pattern {
      values = ["/app2/*", "/app2"]
    }
  }

  # 【重要】Blue/Greenデプロイ時にECSがルールを書き換えるため、監視から除外
  lifecycle {
    ignore_changes = [action]
  }
}


# App1用テストルーティング
resource "aws_lb_listener_rule" "app1_test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1_green.arn # デフォルトでGreen側を向くように設定
  }

  condition {
    path_pattern {
      values = ["/app1/*", "/app1"]
    }
  }

  # ここもECSが書き換える可能性があるため監視対象外とする
  lifecycle {
    ignore_changes = [action]
  }
}

# App2用テストルーティング
resource "aws_lb_listener_rule" "app2_test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app2_green.arn
  }

  condition {
    path_pattern {
      values = ["/app2/*", "/app2"]
    }
  }

  lifecycle {
    ignore_changes = [action]
  }
}

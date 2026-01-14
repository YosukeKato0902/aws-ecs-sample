# -----------------------------------------------------------------------------
# WAFモジュール
# このモジュールは、Webアプリケーションファイアウォール（WAF）を定義し、
# 一般的なWeb攻撃（SQLインジェクション、XSS等）やDDoS攻撃からALBを保護する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# WAF WebACL
# セキュリティルールのセットを定義し、ALBに適用する
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-${var.environment}-waf"
  description = "WAF WebACL for ALB"
  scope       = "REGIONAL" # リージョンリソース（ALB用）を指定

  # デフォルトアクション: どのルールにもマッチしない通信は許可する
  default_action {
    allow {}
  }

  # --- ルール1: AWSマネージドルール (Common Rule Set) ---
  # 一般的なWebサイトへの攻撃（OWASP Top 10等）を広範にカバー
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {} # ルールグループ内の個別アクションに従う
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # --- ルール2: AWSマネージドルール (Known Bad Inputs) ---
  # 無効な文字セット等、悪意のある既知の入力パターンをブロック
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # --- ルール3: AWSマネージドルール (SQL Injection) ---
  # データベースへの不正操作を狙うSQLインジェクション攻撃を防御
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # --- ルール4: レートベースルール (DDoS対策) ---
  # 同一IPからの短時間（5分間）での過剰なリクエストをブロック
  rule {
    name     = "RateBasedRule"
    priority = 4

    action {
      block {} # 閾値を超えたら遮断
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit # IPあたりのリクエスト上限数
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # WebACL全体の可視化設定
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-waf"
  }
}

# -----------------------------------------------------------------------------
# WAF-ALB関連付け
# 作成したWebACLを特定のALBのリソースARNに紐付ける
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# -----------------------------------------------------------------------------
# WAFロギング設定 (オプション)
# 通信のログをS3やCloudWatch Logs等に転送する
# -----------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.enable_logging ? 1 : 0
  log_destination_configs = [var.log_destination_arn] # 保存先ARN
  resource_arn            = aws_wafv2_web_acl.main.arn

  # ロギングフィルター: 全てのログを保存するか、特定のアクションのみかを選択可能
  logging_filter {
    default_behavior = "KEEP" # デフォルトでは全ログを保持

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK" # ブロックされた通信のみに絞る等の設定も可能（現在は例示）
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}

# AWS Cognito 認証基盤 (参考資料)

本ドキュメントでは、将来的な認証基盤の導入に備え、Amazon Cognito を用いたユーザー管理および認証フローの定義例を詳説する。

---

## 目次

1. [構成概要](#1-構成概要)
2. [Terraform 定義例](#2-terraform-定義例)
3. [各リソースの役割と詳細解説](#3-各リソースの役割と詳細解説)
4. [既存インフラとの連携（ALB 認証）](#4-既存インフラとの連携alb-認証)

---

## 1. 構成概要

Amazon Cognito は、Web およびモバイルアプリの認証、承認、およびユーザー管理を提供するサービス。本プロジェクトの ECS Fargate アプリケーションに導入する場合、ALB の認証機能と組み合わせることで、アプリケーションコードを大幅に変更することなくセキュアな認証を実装可能。

- **User Pool**: ユーザーディレクトリ。サインアップ、サインイン、プロファイルの保存を行う。
- **User Pool Client**: アプリケーションから Cognito を利用するためのインターフェース設定。
- **Cognito Domain**: 認証画面（ホストされた UI）やトークン発行に使用するドメイン。

---

## 2. Terraform 定義例

以下は、標準的なセキュリティ要件を満たす Cognito 構成の HCL 定義である。

```hcl
# -----------------------------------------------------------------------------
# Amazon Cognito User Pool
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # ユーザー属性の設定（emailをログインIDとして使用）
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # パスワードポリシー
  password_policy {
    minimum_length      = 8
    require_lowercase   = true
    require_numbers     = true
    require_symbols     = true
    require_uppercase   = true
    temporary_password_validity_days = 7
  }

  # セルフサインアップ設定
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # 多要素認証 (MFA) の設定 (任意: OFF, ON, OPTIONAL)
  mfa_configuration = "OFF"

  # アカウントリカバリ設定
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # スキーマ（カスタム属性が必要な場合）
  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "nickname"
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
}

# -----------------------------------------------------------------------------
# Cognito User Pool Client
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool_client" "main" {
  name = "${var.project_name}-${var.environment}-app-client"

  user_pool_id = aws_cognito_user_pool.main.id

  # 認証フローの設定
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # OAuth 設定（ALB連携に必要）
  allowed_oauth_flows          = ["code"]
  allowed_oauth_scopes         = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # コールバックURL / サインアウトURL（ALBのDNS名などを指定）
  callback_urls = ["https://${var.alb_dns_name}/oauth2/idpresponse"]
  logout_urls   = ["https://${var.alb_dns_name}/logout"]

  # クライアントシークレットの生成（サーバーサイドアプリでは必要）
  generate_secret = true
}

# -----------------------------------------------------------------------------
# Cognito Domain
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}
```

---

## 3. 各リソースの役割と詳細解説

### 3.1 `aws_cognito_user_pool` (ユーザープール本体)

| 引数/ブロック | 役割 | 解説 |
|:---|:---|:---|
| `username_attributes` | ログインIDの定義 | `["email"]` を指定することで、ユーザー名ではなくメールアドレスでサインイン可能にする。 |
| `auto_verified_attributes` | 自動検証 | サインアップ時に管理者の介入なしでメールアドレスを自動検証する。 |
| `password_policy` | 強度制限 | 英大小文字、数字、記号を必須とし、セキュリティ強度を確保。 |
| `admin_create_user_config` | 登録制限 | `allow_admin_create_user_only = false` により、一般ユーザーのセルフサインアップを許可。 |

### 3.2 `aws_cognito_user_pool_client` (アプリクライアント)

| 引数/ブロック | 役割 | 解説 |
|:---|:---|:---|
| `explicit_auth_flows` | 認証パス | SRP（セキュアリモートパスワード）やリフレッシュトークンによる認証を許可。 |
| `allowed_oauth_flows` | 認可フロー | `["code"]` (Authorization Code Grant) は ALB 認証で必須。 |
| `callback_urls` | リダイレクト先 | 認証成功後の戻り先。ALB の `/oauth2/idpresponse` は ALB 側で予約された特殊なパス。 |
| `generate_secret` | 秘密鍵 | ALB 側でトークンを検証するために必要。 |

---

## 4. 既存インフラとの連携（ALB 認証）

本プロジェクトの `modules/alb` 内で以下のようにリスナールールを追加することで、Cognito 認証を有効化できる。

```hcl
# 連携イメージ (ALB リスナールール)
resource "aws_lb_listener_rule" "auth" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type = "authenticate-cognito"
    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.main.arn
      user_pool_client_id = aws_cognito_user_pool_client.main.id
      user_pool_domain    = aws_cognito_user_pool_domain.main.domain
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1.arn
  }

  condition {
    path_pattern {
      values = ["/app1/*"]
    }
  }
}
```

この設定により、ユーザーが `/app1/*` にアクセスした際、未認証であれば自動的に Cognito のログイン画面へリダイレクトされる。アプリケーション側は、ALB が付与する HTTP ヘッダー (`x-amzn-oidc-data`) を検証するだけで、信頼できるユーザー情報を取得可能となる。

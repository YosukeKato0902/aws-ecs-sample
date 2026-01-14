# -----------------------------------------------------------------------------
# ECR（Elastic Container Registry）モジュール
# このモジュールは、Dockerイメージを保存するリポジトリ、
# イメージの自動クリーンアップルール、およびアクセス権限を定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ECRリポジトリ本体
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "main" {
  name                 = "${var.project_name}/${var.repository_name}" # リポジトリ名（例: proj/app1）
  image_tag_mutability = var.image_tag_mutability                     # タグの上書き可能性（MUTABLE/IMMUTABLE）

  # イメージプッシュ時の自動脆弱性診断設定
  image_scanning_configuration {
    scan_on_push = true
  }

  # 保存データの暗号化（デフォルトのAES256を指定）
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.repository_name}"
  }
}

# -----------------------------------------------------------------------------
# ライフサイクルポリシー: ストレージ容量の節約と管理のため、古いイメージを自動削除する
# -----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        # --- ルール1: タグなしイメージの削除 ---
        # ビルド失敗時や、新イメージにタグを奪われた古い「宙ぶらりん」なイメージを削除
        rulePriority = 1
        description  = "タグなしイメージを1日後に削除"
        selection = {
          tagStatus   = "untagged"         # タグがないもの
          countType   = "sinceImagePushed" # プッシュされてからの期間
          countUnit   = "days"             # 日数単位
          countNumber = 1                  # 1日
        }
        action = {
          type = "expire" # 削除（期限切れ）
        }
      },
      {
        # --- ルール2: 開発環境(dev-)用イメージの制限 ---
        rulePriority = 2
        description  = "dev-タグのイメージを10個残して削除"
        selection = {
          tagStatus     = "tagged"             # タグがあるもの
          tagPrefixList = ["dev-"]             # "dev-" で始まるタグが対象
          countType     = "imageCountMoreThan" # 個数制限
          countNumber   = 10                   # 10個を超えたら古い方から削除
        }
        action = {
          type = "expire"
        }
      },
      {
        # --- ルール3: ステージング環境(stg-)用イメージの制限 ---
        rulePriority = 3
        description  = "stg-タグのイメージを10個残して削除"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["stg-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        # --- ルール4: 本番環境(prd-)用イメージの制限 ---
        # 本番用は、万が一のロールバックのため多めに（30世代分）残す設定
        rulePriority = 4
        description  = "prd-タグのイメージを30個残して削除"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prd-"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECRリポジトリポリシー: 他のアカウント等からのアクセスを許可する設定
# -----------------------------------------------------------------------------
resource "aws_ecr_repository_policy" "main" {
  count      = var.enable_cross_account_access ? 1 : 0 # フラグ有効時のみ作成
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountAccess"
        Effect = "Allow"
        Principal = {
          # 許可する外部アカウントのARNリスト（変数より注入）
          AWS = var.cross_account_principals
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",     # レイヤーのダウンロード
          "ecr:BatchGetImage",              # イメージの取得
          "ecr:BatchCheckLayerAvailability" # レイヤーの有無確認
        ]
      }
    ]
  })
}

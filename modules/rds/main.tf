# -----------------------------------------------------------------------------
# RDSモジュール
# このモジュールは、RDS PostgreSQLインスタンス、DBサブネットグループ、
# パラメータグループ、およびSecrets Managerによるパスワード管理を定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DBサブネットグループ: RDSを配置するサブネットの集合を定義
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-${var.db_name}-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids  = var.private_subnet_ids # 安全なプライベートサブネットに配置する

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.db_name}-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# パラメータグループ: データベースエンジンの設定を定義
# -----------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name        = "${var.project_name}-${var.environment}-${var.db_name}-params"
  family      = "postgres${split(".", var.engine_version)[0]}" # PostgreSQLのバージョンに合わせ、ファミリー名を作成
  description = "Parameter group for RDS PostgreSQL"

  parameter {
    name  = "log_statement"
    value = "all" # 全てのSQLステートメントをログ出力する設定
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # 1秒以上かかるスロークエリをログ出力する設定
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.db_name}-params"
  }
}

# -----------------------------------------------------------------------------
# シークレット管理 (DBパスワード): パスワードの自動生成と安全な保管
# -----------------------------------------------------------------------------

# ランダムな16文字のパスワードを生成
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?" # RDSで使用不可能な文字を除外
}

# Secrets Managerにパスワードを保管
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.project_name}-${var.environment}-${var.db_name}-password"
  description = "RDSデータベース (${var.db_name}) のマスターパスワード"

  # リソース削除時の復旧猶予期間を指定
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.db_name}-password"
  }
}

# パスワード、ユーザー名、接続先情報をJSON形式で保存する
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL インスタンス本体
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-${var.db_name}"

  # 基本スペック設定: エンジン、バージョン、インスタンスタイプ（Graviton推奨）
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # ストレージ設定: gp3による性能確保と容量、最大拡張設定
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # 認証管理: マスターユーザーとランダム生成されたパスワード設定
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # ネットワーク・セキュリティ: サブネットグループ、専用SG、パブリックアクセス拒否
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  # カスタムパラメータの適用
  parameter_group_name = aws_db_parameter_group.main.name

  # バックアップ設定
  backup_retention_period = var.backup_retention_period # バックアップ保存日数
  backup_window           = "03:00-04:00"               # バックアップ実施時間帯
  maintenance_window      = "Mon:04:00-Mon:05:00"       # メンテナンス実施時間帯

  # 高可用性(Multi-AZ)設定
  # 有効な場合、別のAZにスタンバイ機を作成し、障害時に自動フェイルオーバーする
  multi_az = var.multi_az

  # 削除・保護設定（本番環境用の安全策）
  deletion_protection       = var.environment == "prd" ? true : false
  skip_final_snapshot       = var.environment == "prd" ? false : true # 削除時にスナップショットを取得するか
  final_snapshot_identifier = var.environment == "prd" ? "${var.project_name}-${var.environment}-${var.db_name}-final-snapshot" : null

  # パフォーマンスモニタリング設定
  # 有効な場合、データベースの重いクエリや負荷の詳細分析を可能とする
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : 0

  # 自動マイナーアップデート設定
  auto_minor_version_upgrade = true # マイナーパッチ等の自動適用

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.db_name}"
  }
}

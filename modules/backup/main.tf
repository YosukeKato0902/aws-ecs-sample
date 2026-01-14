# -----------------------------------------------------------------------------
# AWS Backup モジュール
# このモジュールは、RDSインスタンスやS3バケット等のステートフルなリソースに対し、
# 定義されたスケジュールと保持期間に基づいた自動バックアップを管理する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# バックアップボルト（バックアップの論理的な保管場所）
# -----------------------------------------------------------------------------
resource "aws_backup_vault" "main" {
  name = "${var.project_name}-${var.environment}-backup-vault"

  # セキュリティ向上のためのKMSによる暗号化等もここで設定可能
  tags = {
    Name = "${var.project_name}-${var.environment}-backup-vault"
  }
}

# -----------------------------------------------------------------------------
# IAMロール（AWS Backup サービス用）
# AWS Backupが対象リソース（RDS, S3等）に対してバックアップ作成・復元を行う権限
# -----------------------------------------------------------------------------
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-backup-role"
  }
}

# 共通のバックアップ/リカバリ用マネージドポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "backup_default" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

# S3特有のバックアップ権限（S3のバックアップには別途必要）
resource "aws_iam_role_policy_attachment" "backup_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "backup_s3_restore" {
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
  role       = aws_iam_role.backup.name
}

# -----------------------------------------------------------------------------
# RDSバックアッププラン
# 日次およびオプションの週次スケジュール、保存期間を定義する
# -----------------------------------------------------------------------------
resource "aws_backup_plan" "rds" {
  name = "${var.project_name}-${var.environment}-rds-backup-plan"

  # --- ルール1: 日次バックアップ ---
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.rds_daily_schedule # cron形式 (例: 深夜帯に実行)
    start_window      = 60                     # スケジュール時刻から実行開始までの猶予時間
    completion_window = 180                    # 実行完了までの猶予時間

    lifecycle {
      delete_after = var.rds_daily_retention_days # 指定日数経過後に自動削除
    }

    # リカバリポイント（各バックアップファイル）に識別用タグを付与
    recovery_point_tags = {
      Type        = "daily"
      Environment = var.environment
    }
  }

  # --- ルール2: 週次バックアップ (オプション) ---
  dynamic "rule" {
    for_each = var.enable_weekly_backup ? [1] : []
    content {
      rule_name         = "weekly-backup"
      target_vault_name = aws_backup_vault.main.name
      schedule          = var.rds_weekly_schedule
      start_window      = 60
      completion_window = 180

      lifecycle {
        delete_after = var.rds_weekly_retention_days
      }

      recovery_point_tags = {
        Type        = "weekly"
        Environment = var.environment
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-backup-plan"
  }
}

# RDSバックアップ対象の選択
# 指定されたARNのリソースや、特定のタグを持つリソースをプランに紐付ける
resource "aws_backup_selection" "rds" {
  name         = "${var.project_name}-${var.environment}-rds-selection"
  plan_id      = aws_backup_plan.rds.id
  iam_role_arn = aws_iam_role.backup.arn

  # 特定のリソースARNを直接指定
  resources = var.rds_arns

  # または、特定のタグ条件に一致するリソースを自動選択する設定
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = var.project_name
  }
}

# -----------------------------------------------------------------------------
# S3バックアッププラン
# S3特化のバックアップ設定を定義する（バケット内オブジェクトの不変性保持等のためRDSと分離）
# -----------------------------------------------------------------------------
resource "aws_backup_plan" "s3" {
  count = var.enable_s3_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-s3-backup-plan"

  rule {
    rule_name         = "daily-s3-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.s3_daily_schedule
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.s3_retention_days
    }

    recovery_point_tags = {
      Type        = "s3-daily"
      Environment = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-backup-plan"
  }
}

# S3バックアップ対象の選択
resource "aws_backup_selection" "s3" {
  count = var.enable_s3_backup ? 1 : 0

  name         = "${var.project_name}-${var.environment}-s3-selection"
  plan_id      = aws_backup_plan.s3[0].id
  iam_role_arn = aws_iam_role.backup.arn

  resources = var.s3_arns
}

# -----------------------------------------------------------------------------
# GuardDuty モジュール
# このモジュールは、Amazon GuardDutyを有効化し、
# 悪意のある操作や不審なアクティビティを継続的に監視・検知する設定を定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# GuardDuty 有効化
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector" "main" {
  enable = true # 脅威検知を有効化

  tags = {
    Name = "${var.project_name}-${var.environment}-guardduty"
  }
}

# -----------------------------------------------------------------------------
# S3 Protection 有効化
# S3バケット内のオブジェクトに対する不正アクセスや異常な操作を検知する
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.main.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

# -----------------------------------------------------------------------------
# EBS Malware Protection 有効化
# EC2インスタンスにアタッチされたEBSボリュームのスキャン（マルウェア検知）を有効にする
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector_feature" "ebs_malware_protection" {
  detector_id = aws_guardduty_detector.main.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

# -----------------------------------------------------------------------------
# RDS Login Activity Protection 有効化
# RDSへの不審なログイン試行（ブルートフォース攻撃等）を検知する
# -----------------------------------------------------------------------------
resource "aws_guardduty_detector_feature" "rds_login_events" {
  detector_id = aws_guardduty_detector.main.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}


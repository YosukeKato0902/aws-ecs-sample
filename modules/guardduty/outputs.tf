# -----------------------------------------------------------------------------
# GuardDuty モジュール 出力定義
# -----------------------------------------------------------------------------

output "detector_id" {
  description = "GuardDuty Detector ID"
  value       = aws_guardduty_detector.main.id
}

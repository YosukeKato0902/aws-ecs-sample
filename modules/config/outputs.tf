# -----------------------------------------------------------------------------
# AWS Config モジュール 出力定義
# -----------------------------------------------------------------------------

output "recorder_id" {
  description = "Config Recorder ID"
  value       = aws_config_configuration_recorder.main.id
}

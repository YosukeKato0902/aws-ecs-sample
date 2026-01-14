# -----------------------------------------------------------------------------
# ALBモジュール 出力定義
# -----------------------------------------------------------------------------

output "alb_arn" {
  description = "ALBのARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALBのDNS名"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALBのホストゾーンID"
  value       = aws_lb.main.zone_id
}

output "http_listener_arn" {
  description = "HTTPリスナーのARN"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "HTTPSリスナーのARN"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : ""
}

output "app1_target_group_arn" {
  description = "App1ターゲットグループのARN"
  value       = aws_lb_target_group.app1.arn
}

output "app1_target_group_name" {
  description = "App1ターゲットグループ名"
  value       = aws_lb_target_group.app1.name
}

output "app1_target_group_green_arn" {
  description = "App1ターゲットグループ(Green)のARN"
  value       = aws_lb_target_group.app1_green.arn
}

output "app1_target_group_green_name" {
  description = "App1ターゲットグループ(Green)名"
  value       = aws_lb_target_group.app1_green.name
}

output "app2_target_group_arn" {
  description = "App2ターゲットグループのARN"
  value       = aws_lb_target_group.app2.arn
}

output "app2_target_group_name" {
  description = "App2ターゲットグループ名"
  value       = aws_lb_target_group.app2.name
}

output "app2_target_group_green_arn" {
  description = "App2ターゲットグループ(Green)のARN"
  value       = aws_lb_target_group.app2_green.arn
}

output "app2_target_group_green_name" {
  description = "App2ターゲットグループ(Green)名"
  value       = aws_lb_target_group.app2_green.name
}

# CloudWatch監視用出力
output "alb_arn_suffix" {
  description = "ALBのARNサフィックス (CloudWatch用)"
  value       = aws_lb.main.arn_suffix
}

output "app1_target_group_arn_suffix" {
  description = "App1ターゲットグループのARNサフィックス"
  value       = aws_lb_target_group.app1.arn_suffix
}

output "app2_target_group_arn_suffix" {
  description = "App2ターゲットグループのARNサフィックス"
  value       = aws_lb_target_group.app2.arn_suffix
}

# Blue/Greenデプロイ用リスナールールARN
output "app1_listener_rule_arn" {
  description = "App1用リスナールールARN"
  value       = length(aws_lb_listener_rule.app1_https) > 0 ? aws_lb_listener_rule.app1_https[0].arn : (length(aws_lb_listener_rule.app1_http) > 0 ? aws_lb_listener_rule.app1_http[0].arn : "")
}

output "app2_listener_rule_arn" {
  description = "App2用リスナールールARN"
  value       = length(aws_lb_listener_rule.app2_https) > 0 ? aws_lb_listener_rule.app2_https[0].arn : (length(aws_lb_listener_rule.app2_http) > 0 ? aws_lb_listener_rule.app2_http[0].arn : "")
}

output "app1_test_listener_rule_arn" {
  description = "App1用テストリスナールールARN"
  value       = aws_lb_listener_rule.app1_test.arn
}

output "app2_test_listener_rule_arn" {
  description = "App2用テストリスナールールARN"
  value       = aws_lb_listener_rule.app2_test.arn
}

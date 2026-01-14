# -----------------------------------------------------------------------------
# CloudWatchモジュール
# システム監視基盤（Alarms, SNS Notification, Dashboard）を定義。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# データソース: リージョン情報の取得
# -----------------------------------------------------------------------------
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# SNSトピック: アラート通知の共通基盤
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Name = "${var.project_name}-${var.environment}-alerts"
  }
}

# -----------------------------------------------------------------------------
# ECSアラーム: コンテナリソースの負荷および正常性監視
# -----------------------------------------------------------------------------

# CPU使用率アラーム: スケーリング不足やループ等の異常を検知
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = var.ecs_services

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2 # 一時的なスパイクを除外するため2期間連続で判定
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "${each.key} CPU使用率80%超過"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value.service_name
  }
}

# メモリ使用率アラーム: メモリリークやリソース枯渇を検知
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  for_each = var.ecs_services

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "${each.key} メモリ使用率80%超過"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value.service_name
  }
}

# タスク数低下アラーム: 異常終了やデプロイ失敗による可用性低下を監視
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  for_each = var.ecs_services

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = each.value.min_tasks
  alarm_description   = "${each.key} 稼働タスク数が最小設定値(${each.value.min_tasks})未満"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching" # 全タスクダウン（データなし）を障害として判定

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value.service_name
  }
}

# -----------------------------------------------------------------------------
# ALBアラーム: トラフィック品質およびエンドポイント健全性監視
# -----------------------------------------------------------------------------

# リスナー5xxエラー: ALB自体または設定起因の致命的エラーを検知
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xxエラー発生（閾値10件超過）"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# ターゲット5xxエラー: アプリケーションコンテナ内部のバグや例外を検知
resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-target-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ターゲットコンテナ内 5xxエラー発生"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# レスポンスタイム遅延: Web体験低下（p95遅延）を早期検知
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 3 # 3秒以上
  alarm_description   = "ALBレスポンスタイム(p95)継続遅延"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# Unhealthyターゲット: 切り離された異常インスタンスの存在を警告
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  for_each = var.target_groups

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0 # 1つでも異常があれば通知
  alarm_description   = "${each.key} 異常なコンテナを検知"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value.arn_suffix
  }
}

# -----------------------------------------------------------------------------
# RDSアラーム: データベース生存確認およびリソース圧迫監視
# -----------------------------------------------------------------------------

# CPU使用率アラーム: クエリ詰まりや実行計画の悪化を検知
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  for_each = var.rds_instances

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "${each.key} RDS CPU使用率80%超過"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = each.value.identifier
  }
}

# 空きストレージアラーム: ストレージ枯渇によるDBダウンの未然防止
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  for_each = var.rds_instances

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5GB
  alarm_description   = "${each.key} RDS空き容量5GB未満"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = each.value.identifier
  }
}

# 接続数オーバー: アプリ層のコネクション管理不備や過負荷を検知
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  for_each = var.rds_instances

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = each.value.max_connections * 0.8
  alarm_description   = "${each.key} RDS接続数が上限の80%超過"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = each.value.identifier
  }
}

# -----------------------------------------------------------------------------
# CloudWatchダッシュボード: 指標の集約可視化
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 1
          properties = {
            markdown = "# ${var.project_name} - ${var.environment} Dashboard"
          }
        }
      ],
      [
        {
          type   = "text"
          x      = 0
          y      = 1
          width  = 24
          height = 1
          properties = {
            markdown = "## ECS Service Health"
          }
        }
      ],
      [
        for idx, service in keys(var.ecs_services) : {
          type   = "metric"
          x      = (idx % 2) * 12
          y      = 2 + floor(idx / 2) * 6
          width  = 12
          height = 6
          properties = {
            title  = "ECS Service: ${service} - Resource Usage"
            region = data.aws_region.current.id
            metrics = [
              ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_services[service].service_name, { label = "CPU %" }],
              ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_services[service].service_name, { label = "Memory %" }]
            ]
            period = 300
            stat   = "Average"
            yAxis = {
              left = {
                min = 0
                max = 100
              }
            }
          }
        }
      ],
      [
        {
          type   = "text"
          x      = 0
          y      = 8
          width  = 24
          height = 1
          properties = {
            markdown = "## ALB Traffic & Performance"
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 9
          width  = 8
          height = 6
          properties = {
            title  = "ALB: Request Throughput"
            region = data.aws_region.current.id
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { label = "Total Requests" }]
            ]
            period = 60
            stat   = "Sum"
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 9
          width  = 8
          height = 6
          properties = {
            title  = "ALB: Latency"
            region = data.aws_region.current.id
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { label = "p95", stat = "p95" }],
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { label = "Average", stat = "Average" }]
            ]
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 9
          width  = 8
          height = 6
          properties = {
            title  = "ALB: Error Rates"
            region = data.aws_region.current.id
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "ALB 5XX", color = "#d62728" }],
              ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "App 5XX", color = "#9467bd" }],
              ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "Client 4XX", color = "#ff7f0e" }]
            ]
            period = 60
            stat   = "Sum"
          }
        }
      ],
      [
        {
          type   = "text"
          x      = 0
          y      = 15
          width  = 24
          height = 1
          properties = {
            markdown = "## RDS Database Health"
          }
        }
      ],
      [
        for idx, db in keys(var.rds_instances) : {
          type   = "metric"
          x      = (idx % 2) * 12
          y      = 16 + floor(idx / 2) * 6
          width  = 12
          height = 6
          properties = {
            title  = "RDS: ${db} - Load"
            region = data.aws_region.current.id
            metrics = [
              ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instances[db].identifier, { label = "CPU %" }],
              ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instances[db].identifier, { label = "Connections", yAxis = "right" }]
            ]
            period = 300
            stat   = "Average"
          }
        }
      ]
    )
  })
}

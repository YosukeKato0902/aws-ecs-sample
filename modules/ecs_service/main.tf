# -----------------------------------------------------------------------------
# ECSサービスモジュール
# タスク定義、サービス管理、オートスケーリング、およびBlue/Greenデプロイを定義。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# データソース: リージョン情報の取得
# -----------------------------------------------------------------------------
data "aws_region" "current" {} # 現在の実行リージョン（ap-northeast-1等）を取得

# -----------------------------------------------------------------------------
# タスク実行ロール: ECSエージェント用の権限（イメージ取得、ログ出力等）
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# タスクロール: アプリケーション本体用の権限（S3アクセス、DB操作等）
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-task-role"
  }
}

# S3アクセスポリシー（有効化されている場合のみ作成）
resource "aws_iam_role_policy" "ecs_task_s3" {
  count = var.enable_s3_access ? 1 : 0
  name  = "${var.project_name}-${var.environment}-${var.service_name}-s3-policy"
  role  = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Secrets Managerアクセスポリシー
resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = [
          var.db_secret_arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECSインフラストラクチャロール: ロードバランサー（ALB）操作用
# Blue/Greenデプロイメント時にECSがALBのリスナールールを書き換えるために必須
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_infrastructure_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-infra-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-infra-role"
  }
}

# ALBのターゲットグループやリスナールールを操作するためのポリシー定義
resource "aws_iam_role_policy" "ecs_infrastructure_policy" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-infra-policy"
  role = aws_iam_role.ecs_infrastructure_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups", # ターゲットグループ情報の参照
          "elasticloadbalancing:DescribeTargetHealth", # ヘルス状態の参照
          "elasticloadbalancing:DescribeRules",        # リスナールールの参照
          "elasticloadbalancing:ModifyRule",           # 【重要】リスナールールの書き換え（新旧切り替えで使用）
          "elasticloadbalancing:ModifyTargetGroup",    # ターゲットグループ属性の変更
          "elasticloadbalancing:RegisterTargets",      # ターゲットの登録
          "elasticloadbalancing:DeregisterTargets"     # ターゲットの登録解除
        ]
        Resource = "*" # 全てのALBリソースを対象
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# タスク定義: コンテナの設計図
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.environment}-${var.service_name}"
  network_mode             = "awsvpc"                            # Fargateでは awsvpc 固定
  requires_compatibilities = ["FARGATE"]                         # Fargate 互換
  cpu                      = var.cpu                             # CPU割り当て
  memory                   = var.memory                          # メモリ割り当て
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn # 実行ロールの指定
  task_role_arn            = aws_iam_role.ecs_task.arn           # タスクロールの指定

  # コンテナ詳細定義（JSON形式）
  container_definitions = jsonencode([
    {
      name      = var.service_name    # コンテナ名
      image     = var.container_image # ECR上のイメージURL
      essential = true                # 必須コンテナ（停止したらタスクごと停止）

      # ポートマッピング設定
      portMappings = [
        {
          containerPort = var.container_port # コンテナ側の待機ポート
          hostPort      = var.container_port # ホスト側のポート（Fargateでは同じにする）
          protocol      = "tcp"
        }
      ]

      # 環境変数（Terraformの変数から渡されるリスト）
      environment = var.environment_variables

      # ログ出力設定（CloudWatch Logsへ出力）
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name         # ロググループ名
          "awslogs-region"        = data.aws_region.current.id # リージョン
          "awslogs-stream-prefix" = var.service_name           # プレフィックス
        }
      }

      # Secrets Managerからの機密情報読み込み
      secrets = [
        {
          name      = "DB_PASSWORD"                     # 環境変数名
          valueFrom = "${var.db_secret_arn}:password::" # JSONの特定キーを取得
        }
      ]

      # コンテナ内ヘルスチェック設定（OSレベルでのチェック）
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30 # チェック間隔（秒）
        timeout     = 5  # タイムアウト（秒）
        retries     = 3  # 失敗許容回数
        startPeriod = 60 # 起動直後の猶予期間（秒）
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-task"
  }
}


# -----------------------------------------------------------------------------
# ライフサイクルフック用Lambda関数: Blue/Greenの自動検証を担う
# -----------------------------------------------------------------------------

# Lambdaが実行される際のIAMロール
resource "aws_iam_role" "lifecycle_hook_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-hook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-hook-role"
  }
}

# 基本的な実行権限アタッチ（CloudWatch Logsへの書き込み）
resource "aws_iam_role_policy_attachment" "lifecycle_hook_basic" {
  role       = aws_iam_role.lifecycle_hook_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC内での実行権限アタッチ（テストリスナーへアクセスするため）
resource "aws_iam_role_policy_attachment" "lifecycle_hook_vpc" {
  role       = aws_iam_role.lifecycle_hook_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambdaコードのパッケージ化（PythonファイルをZIPに圧縮）
data "archive_file" "validation_hook" {
  type        = "zip"
  source_file = "${path.module}/lambda/validation_hook.py"
  output_path = "${path.module}/lambda/validation_hook.zip"
}

# 検証用Lambdaファンクション本体
resource "aws_lambda_function" "validation_hook" {
  filename         = data.archive_file.validation_hook.output_path
  function_name    = "${var.project_name}-${var.environment}-${var.service_name}-validation-hook"
  role             = aws_iam_role.lifecycle_hook_role.arn
  handler          = "validation_hook.lambda_handler" # 関数内のエントリーポイント
  source_code_hash = data.archive_file.validation_hook.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60 # タイムアウトは余裕を持って60秒に設定

  # VPC設定: ECSが動くプライベートサブネットに配置して通信を可能にする
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ecs_security_group_id] # ECSと同じSGを使用してALB/10080へアクセス
  }

  # 環境変数: 検証対象のURL（テストリスナーのFQDN）を渡す
  environment {
    variables = {
      VALIDATION_URL = var.validation_url # 例: http://alb-dns:10080/health
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-validation-hook"
  }
}

# ECSがこのLambdaを直接呼び出せるようにするためのIAMロール
resource "aws_iam_role" "ecs_lifecycle_role" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-lifecycle-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

# ECSによるLambdaのInvoke（呼び出し）許可
resource "aws_iam_role_policy" "ecs_lifecycle_policy" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-lifecycle-policy"
  role = aws_iam_role.ecs_lifecycle_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction" # 関数の実行許可
        Resource = aws_lambda_function.validation_hook.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECSサービス本体: アプリケーションの実行維持とデプロイ制御
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "main" {
  name                              = "${var.project_name}-${var.environment}-${var.service_name}"
  cluster                           = var.cluster_arn
  task_definition                   = aws_ecs_task_definition.main.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60 # 起動直後にヘルスチェックで失敗しないための猶予

  # ECS組み込みBlue/Greenデプロイメントの心臓部
  deployment_controller {
    type = "ECS" # CodeDeployを使わずにECS単体で制御する方式
  }

  deployment_configuration {
    strategy             = "BLUE_GREEN"             # ブルーグリーン方式を指定
    bake_time_in_minutes = var.bake_time_in_minutes # 切り替え後の様子見時間（この時間は旧版が生存）

    # 作成したLambdaをデプロイフローに統合
    lifecycle_hook {
      hook_target_arn  = aws_lambda_function.validation_hook.arn # 呼び出すLambda
      role_arn         = aws_iam_role.ecs_lifecycle_role.arn     # 呼び出すための権限
      lifecycle_stages = ["POST_TEST_TRAFFIC_SHIFT"]             # テスト通信開始直後に実行
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false # プライベートサブネットのためパブリックIP不要
  }

  # ロードバランサーとの高度な連携設定
  load_balancer {
    target_group_arn = var.target_group_arn # メインターゲットグループ（Blue）
    container_name   = var.service_name
    container_port   = var.container_port

    # Blue/Greenデプロイ用の追加設定（2つのTGと2つのリスナールールを制御）
    advanced_configuration {
      alternate_target_group_arn = var.alternate_target_group_arn           # サブターゲットグループ（Green）
      production_listener_rule   = var.production_listener_rule_arn         # 本番用(80/443)リスナールール
      test_listener_rule         = var.test_listener_rule_arn               # 検証用(10080)リスナールール
      role_arn                   = aws_iam_role.ecs_infrastructure_role.arn # ALB操作用のIAMロール
    }
  }

  # 手動でのタスク数変更やAuto Scalingによる変更をTerraformが上書きしないよう除外設定
  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}"
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling: トラフィック等に応じたタスク数の自動増減
# -----------------------------------------------------------------------------

# スケーリングのターゲット定義
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity # 最大タスク数
  min_capacity       = var.min_capacity # 最小タスク数
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU使用率ベースのスケーリングポリシー（ターゲット追跡スケーリング）
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-${var.environment}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization" # CPU平均使用率
    }
    target_value       = var.cpu_target_value # 目標値（例: 70%）
    scale_in_cooldown  = 300                  # 縮小(Scale-in)までの待ち時間（秒）
    scale_out_cooldown = 60                   # 拡大(Scale-out)までの待ち時間（秒）
  }
}

# メモリ使用率ベースのスケーリングポリシー
resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = "${var.project_name}-${var.environment}-${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization" # メモリ平均使用率
    }
    target_value       = var.memory_target_value # 目標値（例: 80%）
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

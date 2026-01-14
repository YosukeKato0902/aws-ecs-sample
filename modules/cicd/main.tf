# -----------------------------------------------------------------------------
# CI/CDモジュール
# CodeBuild、CodePipeline、およびGitHub連携（CodeStar Connection）を定義。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# データソース: アカウント情報の取得
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# CodeBuild IAMロール: ビルドおよびイメージプッシュ権限
# -----------------------------------------------------------------------------
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-codebuild-role"
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ログ出力
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        # ECR認証
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # ECRプッシュ/プル
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = var.ecr_repository_arn
      },
      {
        # アーティファクト操作
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = ["${var.artifact_bucket_arn}/*"]
      },
      {
        # ECSサービス更新要求
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService"]
        Resource = var.ecs_service_arn != "" ? var.ecs_service_arn : "arn:aws:ecs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
      },
      {
        # タスク定義登録
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        # 実行ロールの委譲
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "iam:PassedToService" = ["ecs-tasks.amazonaws.com"]
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CodeBuildプロジェクト: イメージビルド・デプロイパイプラインの実行コア
# -----------------------------------------------------------------------------
resource "aws_codebuild_project" "main" {
  name          = "${var.project_name}-${var.environment}-${var.service_name}-build"
  description   = "Build and deploy Docker image for ${var.service_name}"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # Dockerビルドに必須の特権モード

    # buildspecで使用する動的パラメータ
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.id
    }
    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.service_name
    }
    environment_variable {
      name  = "ECS_CLUSTER_NAME"
      value = var.ecs_cluster_name
    }
    environment_variable {
      name  = "ECS_SERVICE_NAME"
      value = var.ecs_service_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-build"
  }
}

# -----------------------------------------------------------------------------
# CodePipeline IAMロール: パイプライン全体のリソース連携権限
# -----------------------------------------------------------------------------
resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-pipeline-role"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-pipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # アーティファクト保存
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObject"]
        Resource = [var.artifact_bucket_arn, "${var.artifact_bucket_arn}/*"]
      },
      {
        # CodeBuild起動
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.main.arn
      },
      {
        # ECSのデプロイステータス等を確認するための権限（広めに付与）
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        # IAMパスロール権限
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEqualsIfExists = {
            "iam:PassedToService" = [
              "ecs-tasks.amazonaws.com"
            ]
          }
        }
      },
      {
        # GitHub接続利用
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CodeStar Connection: GitHubリポジトリとのセキュアな連携ベース
# -----------------------------------------------------------------------------
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-${var.environment}-${var.service_name}-conn"
  provider_type = "GitHub"
}

# -----------------------------------------------------------------------------
# CodePipeline: ソース取得からビルド・デプロイ開始までの流れを定義
# -----------------------------------------------------------------------------
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-${var.environment}-${var.service_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
  }

  # ステージ構成
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_repository
        BranchName       = var.github_branch
        DetectChanges    = var.trigger_on_push
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  # 【補足】Deployステージが存在しない理由
  # 一般的なパイプラインでは「Deployステージ」を追加するが、本プロジェクトでは
  # CodeBuild内の buildspec.yml にて `aws ecs update-service` を直接実行する。
  # これにより、ECS組み込みの「Blue/Greenデプロイメント」プロセスが
  # AWS内部で自動的に開始されるため、パイプラインとしてのDeployステージは不要となる。
  # 技術的背景: ECSサービス更新時に新しいタスク定義が指定されると、ECSは自動的に
  # 新旧タスクの入れ替え（Blue/Greenデプロイメント）を開始する。このプロセスは
  # CodeDeployを介さず、ECSサービスコントローラーが直接管理するため、
  # CodePipeline側で明示的なDeployステージを設ける必要がない。
  # -----------------------------------------------------------------------------

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-pipeline"
  }
}

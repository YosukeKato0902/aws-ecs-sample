# Terraform 環境構成詳細リファレンス (`environments/dev`)

このドキュメントでは、`environments/dev` （開発環境）配下にある各Terraformファイルの役割と内容について解説する。
これらのファイルは、`modules/` 配下の部品（モジュール）を組み合わせて、実際のインフラ環境を構築するための「設計図の完成形」である。

---

## 目次

1. [ファイル構成と役割分担](#ファイル構成と役割分担)
2. [1. main.tf（共通設定）](#1-maintf共通設定)
3. [2. backend.tf（状態管理）](#2-backendtf状態管理)
4. [3. network.tf（ネットワーク層）](#3-networktfネットワーク層)
5. [4. database.tf（データ層）](#4-databasetfデータ層)
6. [5. compute.tf（コンピュート層）](#5-computetfコンピュート層)
7. [6. cicd_monitoring.tf（運用・監視層）](#6-cicd_monitoringtf運用監視層)
8. [7. variables.tf（変数定義）](#7-variablestf変数定義)
9. [8. outputs.tf（出力定義）](#8-outputstf出力定義)
10. [9. security.tf（セキュリティ監視層）](#9-securitytfセキュリティ監視層)
11. [まとめ](#まとめ)

---

## ファイル構成と役割分担

Terraformのベストプラクティスに基づき、一つの巨大なファイルにするのではなく、リソースの役割ごとに分割。

| ファイル名 | 役割 | 主な内容 |
|------------|------|----------|
| **`main.tf`** | 共通設定・ローカル変数 | プロバイダー設定、ローカル変数定義 |
| **`backend.tf`** | 状態管理設定 | tfstateファイルの保存場所設定 |
| **`network.tf`** | ネットワーク | VPC, Subnet, SG, ALB, WAFの定義 |
| **`database.tf`** | データストア | RDS, S3の定義 |
| **`compute.tf`** | コンピュート | ECS Cluster, ECS Service, ECRの定義 |
| **`cicd_monitoring.tf`** | CI/CD・監視 | CodePipeline, CloudWatch, AWS Backupの定義 |
| **`security.tf`** | セキュリティ監視 | Security Hub, GuardDuty, Config, CloudTrailの定義 |
| **`variables.tf`** | 変数定義 | 外部から注入するパラメータの定義 |
| **`outputs.tf`** | 出力定義 | 構築後に表示する重要情報（URLなど） |
| **`terraform.tfvars`** | 変数値ファイル | 環境固有の変数値を設定 |

---

## 1. `main.tf`（共通設定）

Terraformの実行に必要な基本的な設定を行う。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# プロバイダー設定
# ========================================
# 「provider」ブロックは、Terraformがどのクラウドサービス（AWS, Azure, GCPなど）を
# 操作するかを宣言。ここでは "aws" を指定。
provider "aws" {

  # region: AWSのどのリージョン（地域）にリソースを作成するかを指定。
  # var.region は variables.tf で定義された変数で、通常 "ap-northeast-1"（東京）が適用。
  # 変数を使うことで、異なるリージョンへの展開も柔軟に対応可能。
  region = var.region

  # ----------------------------------------
  # デフォルトタグ設定
  # ----------------------------------------
  # default_tags ブロックを使うと、このプロバイダー経由で作成する「すべてのリソース」に
  # 自動的にタグが付与される。手動で各リソースにタグを書く手間が省け、
  # タグの付け忘れを防ぎ、コスト管理やリソース検索を容易。
  default_tags {

    # tags ブロック内にキー:値のペアを定義。
    tags = {
      # Project: どのプロジェクトに属するリソースかを識別するためのタグ。
      # AWS Cost Explorer でこのタグを使ってコストを分析可能。
      Project = var.project_name

      # Environment: どの環境（dev, stg, prd）のリソースかを識別するためのタグ。
      # 誤って本番リソースを削除するなどの事故防止にも有用。
      Environment = var.environment

      # ManagedBy: このリソースがTerraformで管理されていることを明示するタグ。
      # 手動で作成したリソースとの区別がつきやすくなり、運用時の混乱を防止。
      ManagedBy = "Terraform"

      # CostCenter: コスト配分用のタグ。
      # 環境ごとにコストを追跡するために使用。
      CostCenter = "development"  # stg: "staging", prd: "production"

      # Owner: リソースの所有者/管理チームを識別するタグ。
      Owner = "platform-team"
    }
  }
}
# ここで provider ブロックが終了。

# ========================================
# ローカル変数の定義
# ========================================
# 「locals」ブロックは、このファイル（およびモジュール）内で使い回す定数を定義する。
# 変数 (var.xxx) と違い、外部から上書きできない「このモジュール内だけの値」。
# 長い式を何度も書くのを避けたり、計算結果を一度だけ定義して再利用するのに好適。
locals {
  # project_name: var.project_name の値をそのまま格納。
  # ローカル変数にすることで local.project_name として参照でき、
  # 将来的にプレフィックスを付けるなどの加工が必要になった場合に一箇所の変更で完了。
  project_name = var.project_name

  # environment: var.environment の値をそのまま格納。
  # 例: "dev", "stg", "prd" などが設定。
  environment = var.environment
}
# ここで locals ブロックが終了。
```

---

## 2. `backend.tf`（状態管理）

Terraformが作成したリソースの状態（今の設定）を記録する `tfstate` ファイルの保存場所を指定する。

### なぜ backend が重要なのか？

Terraformは「現在AWSにどんなリソースがあるか」を `terraform.tfstate` というファイルに記録。
- **ローカル保存（デフォルト）**: 自分のPCにファイルが保存される。チーム開発では使えない。
- **S3保存（推奨）**: チーム全員が同じ状態を共有でき、DynamoDBで排他制御もできる。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# Terraform設定ブロック
# ========================================
# 「terraform」ブロックは、Terraform自体の動作設定を行う。
# backend（状態管理）、required_version（Terraformバージョン指定）、
# required_providers（使用するプロバイダー）などを設定可能。
terraform {

  # ----------------------------------------
  # バックエンド設定
  # ----------------------------------------
  # 「backend」ブロックは、tfstateファイルをどこに保存するかを指定。
  # "s3" はAWS S3バケットに保存することを意味する。
  # 他には "local"（ローカルファイル）、"gcs"（Google Cloud Storage）などがある。
  backend "s3" {

    # bucket: tfstateを保存するS3バケット名。
    # このバケットは事前に「bootstrap」という初期セットアップで作成済み。
    # 環境ごとに同じバケット内で「key」を分けて管理するのが一般的。
    bucket = "ecs-web-app-tfstate-123456789012"

    # key: バケット内でのファイルパス（オブジェクトキー）。
    # "dev/terraform.tfstate" のように環境名をプレフィックスにすることで、
    # 1つのバケット内で複数環境のstateを安全に分離可能。
    # これにより、dev環境の操作がprd環境のstateに影響することを防止。
    key = "dev/terraform.tfstate"

    # region: S3バケットが存在するリージョン。
    # tfstateの読み書き先を明示。
    region = "ap-northeast-1"

    # encrypt: S3に保存する際に暗号化するかどうか。
    # true にすると、S3のサーバーサイド暗号化 (SSE-S3) が適用され、
    # 保存データが暗号化される。セキュリティのため必ず true に設定。
    encrypt = true

    # dynamodb_table: 排他制御（ロック）に使用するDynamoDBテーブル名。
    # 複数人が同時に terraform apply を実行すると、stateが壊れる可能性がある。
    # DynamoDBテーブルを指定すると、一人が操作中は他の人が待たされる「ロック」機能が有効。
    # これにより、チーム開発でも安全にTerraformを運用可能。
    dynamodb_table = "ecs-web-app-tfstate-lock"
  }
}
# ここで terraform ブロックが終了。
```

---

## 3. `network.tf`（ネットワーク層）

すべての基盤となるネットワークとロードバランサーを構築。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# VPCモジュールの呼び出し
# ========================================
# 「module」ブロックは、modules/ ディレクトリに定義した再利用可能な部品を呼び出し。
# "vpc" はこのモジュール呼び出しの識別名（ラベル）。
# module.vpc.xxx の形式で、このモジュールの出力値を他の場所から参照可能。
module "vpc" {

  # source: 呼び出すモジュールのパス。
  # "../../modules/vpc" は2階層上がってからmodules/vpcを指す。
  # environments/dev/ から見た相対パス。
  source = "../../modules/vpc"

  # ----------------------------------------
  # モジュールに渡す引数（Input Variables）
  # ----------------------------------------
  # 以下の値が、modules/vpc/variables.tf で定義された変数に渡される。

  # project_name: リソース名のプレフィックスに使用。
  # 例: "ecs-web-app" → VPC名が "ecs-web-app-dev-vpc" のようになる。
  project_name = local.project_name

  # environment: 環境識別子。リソース名に含まれる。
  environment = local.environment

  # cidr_block: VPC全体のIPアドレス範囲。
  # "10.0.0.0/16" は 10.0.0.0 ～ 10.0.255.255 の範囲（約65,000個のIPアドレス）を意味。
  # この中からサブネットに小さな範囲を切り出して使用。
  cidr_block = "10.0.0.0/16"

  # nat_gateway_count: NAT Gatewayの数。
  # NAT Gatewayは1つあたり約45ドル/月かかるため、開発環境では1つに抑えてコスト削減。
  # 本番環境では可用性のため、2つ（各AZに1つ）作成することを推奨。
  nat_gateway_count = 1
}

# ========================================
# Security Groupモジュールの呼び出し
# ========================================
module "security_group" {
  source = "../../modules/security_group"

  project_name = local.project_name
  environment  = local.environment

  # vpc_id: セキュリティグループを作成するVPCのID。
  # module.vpc.vpc_id は、上で呼び出したVPCモジュールの「出力値」を参照。
  # VPCが先に作成され、その ID が SG モジュールに渡される（依存関係の自動解決）。
  vpc_id = module.vpc.vpc_id
}

# ========================================
# ALBモジュールの呼び出し
# ========================================
module "alb" {
  source = "../../modules/alb"

  project_name = local.project_name
  environment  = local.environment

  # vpc_id: ALBを配置するVPCのID。
  vpc_id = module.vpc.vpc_id

  # public_subnet_ids: ALBを配置するパブリックサブネットのIDリスト。
  # ALBはインターネットからのトラフィックを受けるため、パブリックサブネットに配置。
  # module.vpc.public_subnet_ids はVPCモジュールが出力するサブネットIDのリスト。
  public_subnet_ids = module.vpc.public_subnet_ids

  # security_group_id: ALBに適用するセキュリティグループのID。
  security_group_id = module.security_group.alb_security_group_id

  # enable_access_logs: ALBのアクセスログをS3に保存するかどうか。
  # true の場合、誰がいつアクセスしたかの記録が残り、トラブルシューティングに有用。
  enable_access_logs = true

  # access_logs_bucket: アクセスログの保存先S3バケット名。
  # 事前に作成したログ用バケットを指定。
  access_logs_bucket = module.s3_logs.bucket_name
}
```

---

## 4. `database.tf`（データ層）

データの保存場所（ステートフルなリソース）を構築。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# アプリケーション用S3バケット
# ========================================
# アプリケーションが使用するファイル（静的アセット、ユーザーアップロードなど）を保存するバケット。
module "s3_app" {
  source = "../../modules/s3"

  project_name = local.project_name
  environment  = local.environment

  # bucket_name: バケットの用途を示す名前。
  # 実際のバケット名は「{project_name}-{environment}-{bucket_name}-{account_id}」形式。
  bucket_name = "app-storage"

  # enable_versioning: ファイルの変更履歴を保持するか。
  # true = 上書き/削除時に旧バージョンを保持。誤操作からの復元が可能。
  enable_versioning = true
}

# ========================================
# CI/CDアーティファクト用S3バケット
# ========================================
module "s3_artifacts" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "cicd-artifacts"
  enable_versioning = true
}

# ========================================
# 監査ログ用S3バケット (CloudTrail/Config用)
# ========================================
# セキュリティ監視サービス（CloudTrail、AWS Config）のログを保存するバケット。
# コンプライアンス要件やセキュリティ監査で必要。
module "s3_audit_logs" {
  source = "../../modules/s3"

  project_name      = local.project_name
  environment       = local.environment
  bucket_name       = "audit-logs"
  enable_versioning = true

  # allow_cloudtrail: CloudTrailからの書き込みを許可するバケットポリシーを追加。
  # CloudTrailがこのバケットにログを書き込めるよう許可。
  allow_cloudtrail = true

  # allow_config: AWS Configからの書き込みを許可するバケットポリシーを追加。
  # AWS Configが設定スナップショットをこのバケットに保存できるよう許可。
  allow_config = true

  # force_destroy: 開発環境ではバケット削除を容易にするため true。
  # 本番環境では false にして誤削除を防止。
  force_destroy = true  # prd: false
}

# ========================================
# RDSモジュール呼び出し（App1用）
# ========================================
module "rds_app1" {
  source = "../../modules/rds"

  project_name = local.project_name
  environment  = local.environment

  # db_name: 作成するデータベースの論理名。
  # PostgreSQL内に作成される実際のデータベース名。
  db_name = "app1db"

  # private_subnet_ids: DBを配置するプライベートサブネットのIDリスト。
  # DBはインターネットから直接アクセスさせないため、プライベートサブネットに配置。
  private_subnet_ids = module.vpc.private_subnet_ids

  # rds_security_group_id: DBに適用するセキュリティグループのID。
  # これにより、ECSからの通信のみを許可する設定が適用される。
  rds_security_group_id = module.security_group.rds_security_group_id

  # instance_class: DBインスタンスのスペック（サイズ）。
  # "db.t4g.micro" は最小構成で、ARMベース（Graviton2）の安価なインスタンス。
  # 開発・テスト環境向け。本番では "db.t4g.small" 以上を推奨。
  instance_class = "db.t4g.micro"  # コスト削減: Graviton2推奨

  # allocated_storage: 初期ストレージ容量（GB）。
  # 最小限から開始し、必要に応じて自動拡張させる設定が一般的。
  allocated_storage = 20

  # max_allocated_storage: ストレージ自動拡張の上限（GB）。
  # この値まで自動的にストレージが拡張される（手動介入不要）。
  max_allocated_storage = 50

  # multi_az: 複数のアベイラビリティゾーンにDBを配置して冗長化するか。
  # true = 障害時に自動フェイルオーバー（高可用性）。コストは約2倍。
  # false = 単一AZ。障害時はダウンタイムが発生。開発環境ではfalseでコスト削減。
  multi_az = false  # コスト削減: シングルAZ

  # backup_retention_period: 自動バックアップの保持期間（日数）。
  # 0 = バックアップ無効。開発環境では短めに設定してコスト削減。
  # 本番環境では 7〜35日を推奨。
  backup_retention_period = 3  # コスト削減: バックアップ保持期間短縮
}

# ========================================
# RDSモジュール呼び出し（App2用）
# ========================================
# App1とほぼ同じ設定で、App2専用のDBを作成。
module "rds_app2" {
  source = "../../modules/rds"

  project_name          = local.project_name
  environment           = local.environment
  db_name               = "app2db"
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_group.rds_security_group_id
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 50

  multi_az                = false
  backup_retention_period = 3
}
```

---

## 5. `compute.tf`（コンピュート層）

アプリケーションが動作するECS環境を構築。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# 外部データソース: ECRリポジトリの参照
# ========================================
# 「data」ブロックは、既存のAWSリソースの情報を「読み取る」ための宣言。
# resource と違い、新しいリソースを「作成」するのではなく、
# 既に存在するリソースの属性（ARN, URLなど）を取得。
data "aws_ecr_repository" "app1" {
  # name: 取得したいECRリポジトリの名前。
  # このリポジトリは別途（bootstrapや手動で）作成済みである必要がある。
  name = "ecs-web-app/app1"
}

data "aws_ecr_repository" "app2" {
  name = "ecs-web-app/app2"
}

# ========================================
# ECS Clusterモジュールの呼び出し
# ========================================
module "ecs_cluster" {
  source = "../../modules/ecs_cluster"

  project_name = local.project_name
  environment  = local.environment

  # enable_container_insights: CloudWatch Container Insightsを有効にするか。
  # true = ECSタスクの詳細なメトリクス（CPU, メモリ, ネットワークなど）を収集。
  # トラブルシューティングやパフォーマンス分析に有用。
  enable_container_insights = true

  # use_fargate_spot: Fargate Spotを使用するか。
  # true = 通常のFargateより最大70%安価だが、AWSの都合で中断される可能性がある。
  # 開発環境では積極的に使ってコスト削減。本番環境では通常Fargateを推奨。
  use_fargate_spot = true
}

# ========================================
# ECS Serviceモジュールの呼び出し（App1）
# ========================================
module "ecs_service_app1" {
  source = "../../modules/ecs_service"

  project_name = local.project_name
  environment  = local.environment
  service_name = "app1"

  # cluster_arn: タスクを動かすECSクラスターのARN。
  # 上で作成したクラスターモジュールの出力値を参照。
  cluster_arn = module.ecs_cluster.cluster_arn

  # ----------------------------------------
  # コンテナ設定
  # ----------------------------------------
  # container_image: 使用するDockerイメージのURL。
  # data.aws_ecr_repository.app1.repository_url でECRリポジトリのURLを取得し、
  # ":latest" タグを付けて最新イメージを指定。
  # 本番では ":v1.2.3" のような固定バージョンタグを推奨。
  container_image = "${data.aws_ecr_repository.app1.repository_url}:latest"

  # container_port: コンテナが待ち受けるポート番号。
  container_port = 80

  # cpu / memory: タスクに割り当てるリソース量。
  # 256 CPU units = 0.25 vCPU, 512 MB メモリ。
  # Fargateの最小構成で、軽量なWebアプリに適している。
  cpu    = 256
  memory = 512

  # desired_count: 常時稼働させるタスク（コンテナ）の数。
  # この数を維持するようにECSが自動的にタスクを管理。
  desired_count = 1

  # ----------------------------------------
  # ネットワーク設定
  # ----------------------------------------
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_group.ecs_security_group_id

  # ----------------------------------------
  # ロードバランサー連携（Blue/Green用）
  # ----------------------------------------
  # target_group_arn: 現在のトラフィックを受けるターゲットグループ（Blue）。
  target_group_arn = module.alb.app1_target_group_arn

  # alternate_target_group_arn: 新バージョン用のターゲットグループ（Green）。
  # デプロイ時に新しいタスクはこちらに登録され、検証後にトラフィックが切り替わる。
  alternate_target_group_arn = module.alb.app1_green_target_group_arn

  # production_listener_rule_arn: 本番トラフィック（ポート80/443）のリスナールール。
  production_listener_rule_arn = module.alb.app1_listener_rule_arn

  # test_listener_rule_arn: テストトラフィック（ポート10080）のリスナールール。
  # デプロイ中、このポート経由で新バージョンを検証可能。
  test_listener_rule_arn = module.alb.app1_test_listener_rule_arn

  # ----------------------------------------
  # Blue/Greenデプロイメント設定
  # ----------------------------------------
  # validation_url: ヘルスチェック用のURL。
  # テストポート(10080)経由でこのURLにアクセスし、200 OKが返れば成功と判定。
  validation_url = "http://${module.alb.alb_dns_name}:10080/app1/health"

  # bake_time_in_minutes: 検証成功後の「様子見時間」（分）。
  # この時間内に問題が発生すれば自動ロールバック。
  # 開発環境では短め(5分)、本番環境では長め(10分以上)を推奨。
  bake_time_in_minutes = 5

  # ----------------------------------------
  # 環境変数（コンテナに渡す設定）
  # ----------------------------------------
  # environment_variables: コンテナ内で参照できる環境変数のマップ。
  # アプリケーションはこれらの値を使ってDBに接続したり、設定を読み込んだりする。
  environment_variables = {
    # DB_HOST: RDSのエンドポイント（接続先アドレス）。
    # module.rds_app1.db_endpoint は RDSモジュールの出力値。
    DB_HOST = module.rds_app1.db_endpoint

    # DB_NAME: 接続するデータベース名。
    DB_NAME = "app1db"

    # ENVIRONMENT: 現在の環境名。アプリ内でdev/prdの判定などに使用可能。
    ENVIRONMENT = local.environment
  }

  # secrets: Secrets Managerから取得する機密情報のマップ。
  # 環境変数とは異なり、値が暗号化されて安全に管理される。
  secrets = {
    # DB_PASSWORD: RDSモジュールが作成したSecrets ManagerのARNを参照。
    DB_PASSWORD = module.rds_app1.db_secret_arn
  }
}

# ========================================
# ECS Serviceモジュールの呼び出し（App2）
# ========================================
# App1とほぼ同じ構成で、App2専用のサービスを作成。
module "ecs_service_app2" {
  source = "../../modules/ecs_service"

  project_name = local.project_name
  environment  = local.environment
  service_name = "app2"

  cluster_arn     = module.ecs_cluster.cluster_arn
  container_image = "${data.aws_ecr_repository.app2.repository_url}:latest"
  container_port  = 80
  cpu             = 256
  memory          = 512
  desired_count   = 1

  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_group.ecs_security_group_id

  target_group_arn           = module.alb.app2_target_group_arn
  alternate_target_group_arn = module.alb.app2_green_target_group_arn
  production_listener_rule_arn = module.alb.app2_listener_rule_arn
  test_listener_rule_arn       = module.alb.app2_test_listener_rule_arn

  validation_url       = "http://${module.alb.alb_dns_name}:10080/app2/health"
  bake_time_in_minutes = 5

  environment_variables = {
    DB_HOST     = module.rds_app2.db_endpoint
    DB_NAME     = "app2db"
    ENVIRONMENT = local.environment
  }

  secrets = {
    DB_PASSWORD = module.rds_app2.db_secret_arn
  }
}
```

---

## 6. `cicd_monitoring.tf`（運用・監視層）

デプロイ自動化と監視設定を集約。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# CI/CDモジュールの呼び出し（App1）
# ========================================
module "cicd_app1" {
  source = "../../modules/cicd"

  project_name = local.project_name
  environment  = local.environment
  service_name = "app1"

  # ----------------------------------------
  # GitHubリポジトリ設定
  # ----------------------------------------
  # github_repository: 監視対象のGitHubリポジトリ（"ユーザー名/リポジトリ名" 形式）。
  github_repository = "your-github-user/aws-ecs-portfolio"

  # github_branch: 監視対象のブランチ名。
  # このブランチへのプッシュでパイプラインが開始。
  github_branch = "develop"

  # buildspec_path: CodeBuildが実行する手順書ファイルのパス。
  # リポジトリのルートから見た相対パス。
  buildspec_path = "app1/buildspec.yml"

  # trigger_on_push: GitHubへのプッシュで自動的にパイプラインを開始するか。
  # true (デフォルト) = 自動開始。dev/stg環境向け。
  # false = 手動実行のみ。prd環境での安全策として使用。
  trigger_on_push = true

  # ----------------------------------------
  # アーティファクト設定
  # ----------------------------------------
  # artifact_bucket_name: パイプラインの中間生成物を保存するS3バケット名。
  artifact_bucket_name = module.s3_artifacts.bucket_name

  # ----------------------------------------
  # ECS設定（デプロイ先）
  # ----------------------------------------
  ecs_cluster_name = module.ecs_cluster.cluster_name
  ecs_service_name = module.ecs_service_app1.service_name
  ecr_repository_url = data.aws_ecr_repository.app1.repository_url
}

# ========================================
# CI/CDモジュールの呼び出し（App2）
# ========================================
module "cicd_app2" {
  source = "../../modules/cicd"

  project_name = local.project_name
  environment  = local.environment
  service_name = "app2"

  github_repository  = "your-github-user/aws-ecs-portfolio"
  github_branch      = "develop"
  buildspec_path     = "app2/buildspec.yml"
  trigger_on_push    = true

  artifact_bucket_name = module.s3_artifacts.bucket_name
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  ecs_service_name     = module.ecs_service_app2.service_name
  ecr_repository_url   = data.aws_ecr_repository.app2.repository_url
}

# ========================================
# CloudWatchモジュールの呼び出し
# ========================================
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = local.project_name
  environment  = local.environment

  # ----------------------------------------
  # 監視対象リソースの情報
  # ----------------------------------------
  # ecs_cluster_name: 監視対象のECSクラスター名。
  # CloudWatchダッシュボードやアラームでこのクラスターのメトリクスを表示。
  ecs_cluster_name = module.ecs_cluster.cluster_name

  # ecs_service_names: 監視対象のECSサービス名のリスト。
  # 各サービスのCPU/メモリ使用率などを監視。
  ecs_service_names = [
    module.ecs_service_app1.service_name,
    module.ecs_service_app2.service_name
  ]

  # alb_arn_suffix: ALBのARNサフィックス（メトリクス取得に必要）。
  alb_arn_suffix = module.alb.alb_arn_suffix

  # rds_instance_ids: 監視対象のRDSインスタンスIDのリスト。
  rds_instance_ids = [
    module.rds_app1.db_instance_id,
    module.rds_app2.db_instance_id
  ]

  # alert_email: アラート通知先のメールアドレス。
  # CPUやメモリの使用率がしきい値を超えた時に通知。
  alert_email = var.alert_email
}

# ========================================
# WAFモジュールの呼び出し
# ========================================
module "waf" {
  source = "../../modules/waf"

  project_name = local.project_name
  environment  = local.environment

  # alb_arn: WAFを関連付けるALBのARN。
  # WAFはこのALBを経由するすべてのリクエストをフィルタリング。
  alb_arn = module.alb.alb_arn
}
```

---

## 7. `variables.tf`（変数定義）

外部（`terraform.tfvars` やコマンドライン引数）から受け取る変数を定義。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# 変数定義
# ========================================
# 「variable」ブロックは、外部から値を受け取るための「入力口」を定義。
# terraform apply 時に -var="xxx=yyy" で渡したり、
# terraform.tfvars ファイルに書いたりして値を設定可能。

variable "project_name" {
  # description: この変数の説明文。terraform plan 時に表示や、
  # ドキュメント自動生成ツール（terraform-docs）で使用。
  description = "プロジェクト名。リソース名のプレフィックスとして使用。"

  # type: 変数のデータ型。
  # string = 文字列, number = 数値, bool = 真偽値, list(...) = リスト, map(...) = マップ
  type = string

  # default: デフォルト値。指定がない場合にこの値が使用される。
  # default がない変数は「必須」となり、値を渡さないとエラーになる。
  default = "ecs-web-app"
}

variable "environment" {
  description = "環境名（dev, stg, prd）。リソース名やタグに使用。"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWSリージョン。リソースを作成する地域を指定。"
  type        = string
  default     = "ap-northeast-1"
}

variable "db_password_app1" {
  # description: この変数の説明。
  # 実際にはSecrets Managerで自動生成されるため、この変数は参照されないが、
  # GitHub Actionsでのterraform planに必要なため定義。
  description = "App1のDBパスワード（Secrets Manager利用のため実際には未使用だがCI/CDで必要）"

  type = string

  # sensitive: true にすると、この変数の値がterraformのログや出力に非表示。
  # パスワードなどの機密情報には必ず設定。
  sensitive = true

  # default: 空文字をデフォルト値として設定。
  # GitHub ActionsでSecretsが未設定の場合でもplanが通るようにする。
  default = ""
}

variable "db_password_app2" {
  description = "App2のDBパスワード（Secrets Manager利用のため実際には未使用だがCI/CDで必要）"
  type        = string
  sensitive   = true
  default     = ""
}

variable "alert_email" {
  description = "CloudWatchアラートの通知先メールアドレス"
  type        = string
  default     = ""
}
```

---

## 8. `outputs.tf`（出力定義）

terraform apply 完了後にコンソールに表示したい情報を定義。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# 出力定義
# ========================================
# 「output」ブロックは、terraform apply 完了後にコンソールに表示する値を定義。
# また、他のTerraformプロジェクトやスクリプトから terraform output コマンドで
# これらの値を取得可能。

output "alb_dns_name" {
  # description: この出力値の説明。
  description = "ALBのDNS名（ブラウザでアクセスするURL）"

  # value: 出力する値。
  # module.alb.alb_dns_name は ALBモジュールの出力値。
  # ブラウザでこのURLにアクセスするとアプリが表示される。
  value = module.alb.alb_dns_name
}

output "rds_app1_endpoint" {
  description = "App1用RDSのエンドポイント（DB接続用アドレス）"

  # RDSのエンドポイントは "mydb.xxxx.ap-northeast-1.rds.amazonaws.com" のような形式。
  # アプリケーションはこのアドレスに対してDB接続を行う。
  value = module.rds_app1.db_endpoint
}

output "rds_app2_endpoint" {
  description = "App2用RDSのエンドポイント（DB接続用アドレス）"
  value       = module.rds_app2.db_endpoint
}

output "ecs_cluster_name" {
  description = "ECSクラスター名（AWS CLIやConsoleでの確認用）"
  value       = module.ecs_cluster.cluster_name
}

output "ecr_app1_repository_url" {
  description = "App1用ECRリポジトリURL（Dockerイメージのプッシュ先）"
  # 例: "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app1"
  value = data.aws_ecr_repository.app1.repository_url
}

output "ecr_app2_repository_url" {
  description = "App2用ECRリポジトリURL（Dockerイメージのプッシュ先）"
  value       = data.aws_ecr_repository.app2.repository_url
}
```

---

## まとめ

各ファイルの役割は以下の通り：

```
environments/dev/
├── main.tf          # 「どのクラウド（AWS）を使うか」「共通のタグや変数」を設定
├── backend.tf       # 「Terraformの状態をどこに保存するか」を設定
├── network.tf       # 「通信の土台（VPC, サブネット, ALB, WAF）」を構築
├── database.tf      # 「データの保存場所（RDS, S3）」を構築
├── compute.tf       # 「アプリが動く場所（ECSクラスター, ECSサービス, ECR）」を構築
├── cicd_monitoring.tf # 「自動デプロイと監視（CodePipeline, CloudWatch, AWS Backup）」を構築
├── security.tf      # 「セキュリティ監視（Security Hub, GuardDuty, Config, CloudTrail）」を構築
├── variables.tf     # 「外部から受け取る値」を定義
├── outputs.tf       # 「構築後に知りたい情報」を出力
└── terraform.tfvars # 「変数の実際の値」を設定
```

この構成により、各ファイルが単一の責任を持ち、可読性・保守性の高いTerraformコードになっている。

---

## 9. `security.tf`（セキュリティ監視層）

AWSのセキュリティサービスを統合し、脅威検知・コンプライアンス監査・API操作の監査ログを有効化する。

### 詳細解説 (全行コメント付き)

```hcl
# ========================================
# Security Hubモジュールの呼び出し
# ========================================
# Security Hubは、AWSのセキュリティ状態を一元的に可視化するサービス。
# 各種AWSサービスのセキュリティ所見を集約し、ベストプラクティスへの準拠状況を確認可能。
module "security_hub" {
  source = "../../modules/security_hub"

  project_name = local.project_name
  environment  = local.environment

  # enable_cis_standard: CIS AWS Foundations Benchmarkを有効化するか。
  # true = 業界標準のセキュリティベンチマークに基づくチェックを有効化。
  # 本番環境では true を推奨。開発環境ではコスト削減のため false も可。
  enable_cis_standard = false  # prd: true
}

# ========================================
# GuardDutyモジュールの呼び出し
# ========================================
# GuardDutyは、AWS環境の脅威を自動検知するマネージドサービス。
# 不審なAPIコール、マルウェア、不正アクセスなどを機械学習で検出。
module "guardduty" {
  source = "../../modules/guardduty"

  project_name = local.project_name
  environment  = local.environment
}

# ========================================
# AWS Configモジュールの呼び出し
# ========================================
# AWS Configは、AWSリソースの設定変更を記録・監査するサービス。
# 「誰が、いつ、どのリソースの設定を変更したか」を追跡可能。
module "config" {
  source = "../../modules/config"

  project_name = local.project_name
  environment  = local.environment

  # config_bucket_name: 設定履歴の保存先S3バケット名。
  # 監査ログ用のS3バケットを指定。
  config_bucket_name = module.s3_audit_logs.bucket_id
}

# ========================================
# CloudWatch Logsグループ (CloudTrail用)
# ========================================
# CloudTrailのログをリアルタイムで監視するためのロググループ。
# 異常なAPI操作があった場合にアラートを設定可能。
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name = "/aws/cloudtrail/${local.project_name}-${local.environment}"

  # retention_in_days: ログの保持期間（日数）。
  # 開発環境では7日、本番環境では365日などを設定。
  retention_in_days = 7  # prd: 365

  tags = {
    Name = "${local.project_name}-${local.environment}-cloudtrail-logs"
  }
}

# ========================================
# CloudTrailモジュールの呼び出し
# ========================================
# CloudTrailは、AWSアカウント内のAPI操作を監査ログとして記録するサービス。
# セキュリティ調査やコンプライアンス対応に必須のサービスである。
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name = local.project_name
  environment  = local.environment

  # trail_bucket_name: 監査ログの保存先S3バケット名。
  trail_bucket_name = module.s3_audit_logs.bucket_id

  # enable_s3_logging: S3データイベントのログ記録を有効化するか。
  # true = S3バケットへのアクセスも記録（ログ量が多くなる）。
  # false = 管理イベントのみ記録。開発環境ではfalseでコスト削減。
  enable_s3_logging = false  # prd: true

  # cloudwatch_log_group_arn: CloudWatch Logs連携用のロググループARN。
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.cloudtrail.arn

  # enable_cloudwatch_logs: CloudWatch Logsへの転送を有効化するか。
  enable_cloudwatch_logs = true
}
```

### 環境別の推奨設定

| 設定項目 | dev | stg | prd |
|----------|-----|-----|-----|
| CIS Standard | false | true | true |
| S3 Logging | false | false | true |
| Log Retention | 7日 | 90日 | 365日 |

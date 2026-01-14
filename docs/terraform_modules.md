# Terraform モジュール詳細リファレンス

本プロジェクトで使用している各Terraformモジュールの役割、作成リソース、および主要パラメータを技術的な観点から詳説。

---

## 目次

1. [全体の構成概念](#1-全体の構成概念)
2. [VPCモジュール (ネットワーク)](#2-vpcモジュール-modulesvpc)
3. [Security Groupモジュール (ファイアウォール)](#3-security-groupモジュール-modulessecurity_group)
4. [ECRモジュール (コンテナレジストリ)](#4-ecrモジュール-modulesecr)
5. [S3モジュール (ストレージ)](#5-s3モジュール-moduless3)
6. [RDSモジュール (データベース)](#6-rdsモジュール-modulesrds)
7. [ALBモジュール (ロードバランサー)](#7-albモジュール-modulesalb)
8. [ECS Clusterモジュール (コンテナ基盤)](#8-ecs-clusterモジュール-modulesecs_cluster)
9. [ECS Serviceモジュール (アプリケーション)](#9-ecs-serviceモジュール-modulesecs_service)
10. [CI/CDモジュール (自動デプロイ)](#10-cicdモジュール-modulescicd)
11. [CloudWatchモジュール (監視)](#11-cloudwatchモジュール-modulescloudwatch)
12. [WAFモジュール (Webセキュリティ)](#12-wafモジュール-moduleswaf)
13. [AWS Backupモジュール (バックアップ)](#13-aws-backupモジュール-modulesbackup)
14. [Security Hubモジュール (セキュリティ統合管理)](#14-security-hubモジュール-modulessecurity_hub)
15. [GuardDutyモジュール (脅威検知)](#15-guarddutyモジュール-modulesguardduty)
16. [AWS Configモジュール (設定監査)](#16-aws-configモジュール-modulesconfig)
17. [CloudTrailモジュール (API監査ログ)](#17-cloudtrailモジュール-modulescloudtrail)
18. [ACMモジュール (SSL/TLS証明書)](#18-acmモジュール-modulesacm)

---

## 1. 全体の構成概念

Terraformにおける「モジュール」は、関連するリソースを一つのパッケージとしてカプセル化した単位。入力（変数）を受け取り、抽象化されたプロビジョニングを実行し、結果（出力）を上位層へ返す役割を担う。

本プロジェクトでは機能単位でモジュールを疎結合に定義し、`environments/` 配下の各環境用設定から呼び出すことで、構成の再利用性とメンテナンス性を確保。

---

## 2. VPCモジュール (`modules/vpc`)

ネットワークの基盤となるAmazon VPC（Virtual Private Cloud）環境を構築。サブネット、ゲートウェイ、ルーティング設定を含み、リソース間の通信分離を実現。

### 作成リソース

| リソース名 | Terraformリソース型 | 役割 |
|------------|-------------------|------|
| **VPC** | `aws_vpc` | ネットワークの論理的境界。IPアドレス範囲（CIDR）を定義。 |
| **Internet Gateway** | `aws_internet_gateway` | パブリックサブネットとインターネットを仲介するゲートウェイ。 |
| **Public Subnet** | `aws_subnet` | インターネットからの直接到達性が可能な領域（ALB、NAT GWの配置先）。 |
| **Private Subnet** | `aws_subnet` | インターネットから直接アクセスできない安全な領域（ECS、RDSの配置先）。 |
| **NAT Gateway** | `aws_nat_gateway` | プライベートサブネットから外部へのアウトバウンド通信を許可する片方向ゲートウェイ。 |
| **Route Table** | `aws_route_table` | パケットの転送先（IGW、NAT GW、VPC Endpoint等）を制御する経路表。 |

---

## 3. Security Groupモジュール (`modules/security_group`)

インスタンス単位のステートフルな仮想ファイアウォールを定義。最小権限の原則（Principle of Least Privilege）に基づき、各レイヤー間の通信を厳格に制御。

### セキュリティ設計

| リソース名 | 制御仕様 |
|------------|------|
| **ALB SG** | インターネットからのHTTP(80)/HTTPS(443)トラフィックを許可。 |
| **ECS SG** | **ALB SG からの通信のみ**をインバウンドで許可し、ECSタスクを保護。 |
| **RDS SG** | **ECS SG からのDBポート(5432)通信のみ**を許可。内部ネットワークからの直接アクセスも遮断。 |

---

## 4. ECRモジュール (`modules/ecr`)

Dockerイメージを管理するためのコンテナレジストリを構築。イメージの保存、脆弱性スキャン、およびライフサイクル管理を自動化。

### 詳細解説 (コードと役割)

```hcl
# -----------------------------------------------------------------------------
# ECRリポジトリ本体
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "main" {
  name                 = "${var.project_name}/${var.repository_name}" # リポジトリ名の一意識別
  image_tag_mutability = var.image_tag_mutability                     # タグの不変性（MUTABLE/IMMUTABLE）設定

  # イメージのプッシュ時に自動的に脆弱性診断（スキャン）を実行
  image_scanning_configuration {
    scan_on_push = true
  }

  # 保存データの暗号化方式（標準のAES256を指定）
  encryption_configuration {
    encryption_type = "AES256"
  }
}
```

---

## 5. S3モジュール (`modules/s3`)

スケーラブルなオブジェクトストレージサービス。データの永続化、バックアップ、およびログ集計に使用。

### 用途
1. **CI/CDアーティファクト**: ビルド成果物やデプロイ用パッケージの中間保存。
2. **監査ログ集約**: CloudTrail、AWS Configなどの証跡情報を一元管理。
3. **アプリケーション利用**: 静的なコンテンツやユーザー生成データの保存。

### 主要機能
- **バージョニング**: 意図しない削除や上書きから復旧可能な履歴管理。
- **サーバーサイド暗号化**: AES256による透過的なデータの暗号化保護。
- **パブリックアクセス遮断**: バケットレベルで全公開アクセスを拒否する安全策。

### 詳細解説 (全行コメント付き)

```hcl
# ----------------------------------------
# S3バケット本体の作成
# ----------------------------------------
resource "aws_s3_bucket" "main" {
  # バケット名はグローバルで一意である必要があるため、アカウントIDを付与
  bucket        = "${var.project_name}-${var.environment}-${var.bucket_name}-${data.aws_caller_identity.current.account_id}"
  
  # force_destroy: バケット内にオブジェクトがあっても削除を許可（開発環境用）
  force_destroy = var.force_destroy

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.bucket_name}"
  }
}

# ----------------------------------------
# バージョニング設定
# ----------------------------------------
# ファイルの変更履歴を保持し、誤削除からの復元を可能にする
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    # var.enable_versioning が true なら "Enabled"、false なら "Suspended"
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ----------------------------------------
# サーバーサイド暗号化（保存時暗号化）
# ----------------------------------------
# 保存データを自動的に暗号化し、セキュリティを向上
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      # AES256: AWS管理のサーバーサイド暗号化（SSE-S3）
      sse_algorithm = "AES256"
    }
  }
}

# ----------------------------------------
# パブリックアクセスブロック
# ----------------------------------------
# 4つの設定すべてをtrueにして、パブリックアクセスを完全にブロック
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true  # パブリックACLのブロック
  block_public_policy     = true  # パブリックポリシーのブロック
  ignore_public_acls      = true  # 既存のパブリックACLを無視
  restrict_public_buckets = true  # パブリックバケットへのアクセス制限
}
```

### 確認コマンド

```bash
# バケット一覧
aws s3 ls | grep ecs-web-app

# バケットのバージョニング設定確認
aws s3api get-bucket-versioning --bucket <BUCKET_NAME>

# 暗号化設定確認
aws s3api get-bucket-encryption --bucket <BUCKET_NAME>
```

---

## 6. RDSモジュール (`modules/rds`)

マネージド型リレーショナルデータベース。高可用性構成、自動スナップショット、および認証情報のセキュアな隔離を実装。

### 構成要素詳細

#### 6-1. DBインスタンス設定

```hcl
# -----------------------------------------------------------------------------
# RDS PostgreSQL インスタンス本体
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-${var.db_name}"

  # 基本スペック設定: ARM(Graviton)ベースのインスタンスを選択しコスト性能比を最適化
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class # db.t4g.micro 等を指定

  # ストレージ設定: 汎用SSD(gp3)によるバースト不要な性能確保と容量割り当て
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # 自動スケーリングの上限
  storage_type          = "gp3"
  storage_encrypted     = true

  # ネットワーク・セキュリティ: プライベートサブネットへの配置と専用SGによる保護
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false # インターネットからの直接到達性を完全に排除

  # 認証管理: ランダム生成されたパスワードによりセキュリティを担保
  username = var.db_username
  password = random_password.db_password.result
}
```

#### 6-2. Secrets Manager への保存

```hcl
# ----------------------------------------
# Secrets Managerにパスワードなどの機密情報を保存
# ----------------------------------------
# aws_secretsmanager_secret_version は「シークレットの中身（バージョン）」を作成する。
# シークレット自体（箱）は aws_secretsmanager_secret で別途作成されている。
resource "aws_secretsmanager_secret_version" "db_password" {

  # --- 引数1: secret_id ---
  # どのシークレット（箱）に値を保存するかを指定する。
  # 「aws_secretsmanager_secret.db_password.id」は、
  # 同モジュール内で作成したシークレットリソースの「ID」を参照。
  # 「.」でリソースの属性（id, arn など）にアクセス可能。
  secret_id = aws_secretsmanager_secret.db_password.id

  # --- 引数2: secret_string ---
  # シークレットに保存する「中身」を定義する。
  # jsonencode() は Terraform の組み込み関数。
  # {} で囲まれたマップ（キー:値のペア）をJSON形式の文字列に変換。
  # Secrets ManagerはJSON形式で複数の値をまとめて保存するのが一般的。
  secret_string = jsonencode({

    # username: データベースのログインユーザー名。
    # var.db_username はモジュール呼び出し時に指定される変数。
    username = var.db_username

    # password: データベースのパスワード。
    # random_password リソースは Terraform の「random」プロバイダが提供し、
    # ランダムな文字列を自動生成する。result でその値を取得。
    password = random_password.db_password.result

    # engine: 使用しているDBエンジンの種類。アプリが接続先を識別するのに使用。
    engine = "postgres"

    # host: DBの接続先アドレス（エンドポイント）。
    # aws_db_instance.main.address で、作成されたRDSのDNS名を参照。
    # 例: "mydb.xxxx.ap-northeast-1.rds.amazonaws.com"
    host = aws_db_instance.main.address

    # port: PostgreSQLの標準ポート番号は 5432。
    port = 5432

    # dbname: 接続するデータベース名。
    dbname = var.db_name

  })
  # jsonencode の結果、以下のようなJSON文字列が Secrets Manager に保存される:
  # {"username":"admin","password":"xyzabc123...","engine":"postgres","host":"mydb....","port":5432,"dbname":"appdb"}
}
```

> **ポイント**: パスワードはTerraformコードに直接書かず、`random_password` で生成し、`aws_secretsmanager_secret` (Secrets Manager) に保存して安全に管理。アプリケーションはこのSecrets Managerから認証情報を取得する。

---

## 7. ALBモジュール (`modules/alb`)

トラフィックの単一進入点として、負荷分散、パスベースルーティング、およびSSL終端を実行。

### 詳細解説 (コードと役割)

```hcl
# -----------------------------------------------------------------------------
# Application Load Balancer 本体
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false # 外部公開用
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  # 削除保護: 本番環境のみ有効化（誤操作防止）
  enable_deletion_protection = var.environment == "prd" ? true : false
}

# -----------------------------------------------------------------------------
# ターゲットグループ: トラフィックの配布先
# (Blue/Greenデプロイのため、新旧2つのセットを用意)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "app1" {
  name        = "${var.project_name}-${var.environment}-app1-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate利用のためIPターゲット

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}
```

---

## 8. ECS Clusterモジュール (`modules/ecs_cluster`)

コンテナを実行するための論理的なクラスター基盤。Fargateを用いたサーバーレス構成を採用。

### 作成リソース

| リソース名 | Terraformリソース型 | 役割 |
|------------|-------------------|------|
| **ECS Cluster** | `aws_ecs_cluster` | コンテナ実行環境の管理単位。 |
| **Capacity Providers** | `aws_ecs_cluster_capacity_providers` | 実行リソースの種別（Fargate/Fargate Spot）を定義。 |

### 設定のポイント
- **Fargate Spot**: AWSの余剰リソースを利用することで、通常より大幅なコスト削減（最大70%）を実現。開発環境等での利用を推奨。

---

## 9. ECS Serviceモジュール (`modules/ecs_service`)

アプリケーション本体（コンテナ）の実行維持、スケーリング、およびデプロイプロセスを司る中心的なモジュール。

### 主要構成要素

1. **タスク定義 (Task Definition)**: 使用イメージ、CPU/メモリ、環境変数、ログ設定等のコンテナ設計図。
2. **ECSサービス (ECS Service)**: 指定したタスク数の維持と、ALBとの紐付け。
3. **IAMロール**: タスク実行用（Execution Role）とアプリケーション用（Task Role）の分離。

### 詳細解説 (Blue/Greenデプロイ対応)

```hcl
resource "aws_ecs_service" "main" {
  # ...基本設定...

  # Blue/Greenデプロイメント（CodeDeploy連携）に対応する構成
  deployment_controller {
    type = "CODE_DEPLOY" # 外部サービスによる高度なデプロイ制御
  }

  # ----------------------------------------
  # デプロイ設定（Blue/Green）
  # ----------------------------------------
  deployment_configuration {
    # strategy = "BLUE_GREEN" は、ローリングアップデート（少しずつ入れ替え）ではなく、
    # Blue/Green（新旧2つの環境を用意して一気に切り替え）を使う設定。
    strategy = "BLUE_GREEN"

    # ライフサイクルフック: デプロイの特定のタイミングで追加処理（Lambda）を実行可能。
    lifecycle_hook {
      # POST_TEST_TRAFFIC_SHIFT = テストポートへのトラフィック切り替え後
      lifecycle_stages = ["POST_TEST_TRAFFIC_SHIFT"]
      # ここで指定したLambdaがヘルスチェックなどの検証を行う。
    }

    # bake_time_in_minutes: トラフィック切り替え後、しばらく様子を見る時間（分）。
    # この間に問題が起きれば自動でロールバック。
    bake_time_in_minutes = var.bake_time
  }

  # ----------------------------------------
  # ロードバランサーとの接続設定
  # ----------------------------------------
  load_balancer {
    # 現在トラフィックを受けているターゲットグループ（Blue）。
    target_group_arn = var.target_group_arn

    # コンテナ内で公開しているポート名（タスク定義内で指定）。
    container_name = var.container_name

    # コンテナが待ち受けるポート番号。
    container_port = var.container_port

    # ----------------------------------------
    # Blue/Green 用の高度な設定
    # ----------------------------------------
    advanced_configuration {
      # 新バージョン用のターゲットグループ（Green）。
      alternate_target_group_arn = var.alternate_target_group_arn

      # 本番トラフィック用のリスナールール（ポート80/443）。
      production_listener_rule_arn = var.production_listener_rule_arn

      # テストトラフィック用のリスナールール（ポート10080）。
      test_listener_rule_arn = var.test_listener_rule_arn
    }
  }
}
```

---

## 10. CI/CDモジュール (`modules/cicd`)

GitHubへのプッシュをトリガーとしたビルド・デプロイ自動化パイプライン。

### 作成リソース
- **CodePipeline**: ソース取得からデプロイまでの実行フローを管理。
- **CodeBuild**: DockerイメージビルドおよびECRへのプッシュを実行（特権モード利用）。
- **CodeStar Connection**: GitHubとのセキュアな認証連携。

### デプロイ方式の補足
本構成ではCodeBuild内で `aws ecs update-service` を実行し、ECS標準のBlue/Greenデプロイ（またはローリングアップデート）をトリガーする。そのため、パイプライン上に独立した「Deployステージ」は設けていない。

---

## 11. CloudWatchモジュール (`modules/cloudwatch`)

システム監視、アラート通知、および可視化ダッシュボードを提供。

### 主要機能
- **メトリクスアラーム**: CPU/メモリ使用率、ALBエラー率、RDS接続数等を監視しSNS通知。
- **ダッシュボード**: 主要指標を1画面に集約。異常時の迅速な状況把握を支援。
- **SNSトピック**: アラート通知の共通エンドポイント。

---

## 12. WAFモジュール (`modules/waf`)

Web Application Firewall。SQLインジェクション、XSS、DDoS等の攻撃からALBを保護。

### 防御ルールセット
- **AWSManagedRulesCommonRuleSet**: AWS提供の標準的な防御ルール。
- **RateBasedRule**: 特定IPからの過剰なリクエスト（DDoS/ブルートフォース）を制限。

---

## 13. AWS Backupモジュール (`modules/backup`)

RDSおよびS3データの自動バックアップ。スケジュール管理と保持ポリシーの一元化。

### 構成
- **Backup Plan**: バックアップ頻度（毎日/毎週）と保持期間の定義。
- **Backup Vault**: バックアップデータの安全な格納先。

---

## 14. Security Hub / GuardDuty / AWS Config / CloudTrail

セキュリティ・コンプライアンス基盤。

- **Security Hub**: AWSセキュリティベストプラクティスへの準拠状況を可視化。
- **GuardDuty**: 機械学習による脅威検知（不審な通信やAPI操作を自動検知）。
- **AWS Config**: リソース設定の変更履歴を記録。コンプライアンス監査に利用。
- **CloudTrail**: 全てのAPI操作をログとして記録。「誰が・いつ・何をしたか」を追跡。

---

## 15. ACMモジュール (`modules/acm`)

SSL/TLS証明書の管理。ALBでのHTTPS通信に必須。

### 検証方式
- **DNS検証**: Route53と連携し、証明書の有効期限を自動更新。推奨方式。

### 構成
1. **ACM Certificate**: 証明書本体のリクエスト。
2. **Route53 Record**: ドメイン所有権証明用のCNAMEレコード。
3. **Certificate Validation**: DNS検証の完了待機リソース。

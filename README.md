# AWS ECS Fargate Web Application Portfolio

> **Note:** これはポートフォリオ用に公開しているインフラストラクチャコードです。
> セキュリティ保護のため、AWSアカウントIDやリポジトリ名などの機密情報はダミー値（`123456789012` 等）に置換しています。
> 実際の商用環境で使用しているコードを元に、ベストプラクティスを示すために構成されています。

# AWS ECS Fargate Webアプリケーション基盤


Terraformを使用したAWS ECS Fargate基盤のインフラストラクチャコード

---

## 目次

1. [概要](#概要)
2. [ドキュメント一覧](#ドキュメント一覧)
3. [ディレクトリ構成](#ディレクトリ構成)
4. [初回セットアップ](#初回セットアップ)
5. [環境別設定](#環境別設定)
6. [CI/CD](#cicd)
7. [アプリケーションアクセス](#アプリケーションアクセス)
8. [注意事項](#注意事項)

---

## 概要

- **3環境対応**: dev / stg / prd
- **2アプリケーション**: app1, app2 (パスベースルーティング)
- **Blue/Greenデプロイメント**: ECS組み込み機能 (AWS Provider v6.x)
- **自動検証**: Lambdaライフサイクルフックによるテストトラフィック検証
- **CI/CD**: GitHub Actions + CodeBuild + CodePipeline

本プロジェクトは、デフォルトで **単一のAWSアカウント** 内に dev / stg / prd の全環境を構築する構成。

- **リソース分離**: 環境名 (`dev`, `stg`, `prd`) をリソース名に含めることで名前衝突を回避。
- **State分離**: S3バケット内のパス (`dev/terraform.tfstate` 等) で環境ごとにStateファイルを分割。
- **マルチアカウント対応**: 環境ごとにAWSアカウントを分離したい場合、コード変更は不要。各環境ディレクトリで操作する際に、適切なAWSプロファイル (`export AWS_PROFILE=...`) を切り替えるだけで対応可能。

## 設計・構成のポイント

- **アーキテクチャ**: Terraformモジュールによる3環境の統一管理と、ECS Fargate × CodePipelineによるBlue/Greenデプロイメントを採用し、安全かつ高速なリリースサイクルを実現。
- **セキュリティ**: Security Hub、GuardDuty、WAFによる多層防御に加え、Secrets Managerでの機密情報管理やS3/RDSの暗号化・プライベート配置を徹底し、AWSベストプラクティスに準拠。
- **運用・コスト**: CloudWatchによる可観測性の確保とAWS Backupによる自動データ保護、さらに開発環境でのFargate Spot活用により、高い信頼性とコストパフォーマンスを両立。


---

## ドキュメント一覧

各設計書、手順書、リファレンスは `docs/` ディレクトリに集約。

### 📋 設計・仕様
- [基本設計書](docs/basic_design.md): システム全体像、機能/非機能要件、ネットワーク設計。
- [詳細設計書](docs/detailed_design.md): 各リソースの詳細パラメータ、セキュリティグループ、ルーティング詳細。
- [アーキテクチャ図 (PlantUML)](docs/architecture_plantuml.md): PlantUML形式による構成図と表示方法。
- [アーキテクチャ図 (Images)](docs/architecture.md): 生成済み構成図の一覧と再生成方法。

### 🚀 手順・運用
- [デプロイ手順書](docs/release_guide.md): Step-by-Step による環境構築・更新手順。
- [運用ポリシー](docs/operation_policy.md): GitHubを信頼の唯一のソースとする管理指針。
- [開発ガイド](docs/application_development.md): アプリケーションコードの修正、ビルド、デプロイの流れ。
- [実装ウォークスルー](docs/walkthrough.md): AWS Provider v6.x 刷新時の変更内容解説。

### 🛠 技術リファレンス
- [Terraform モジュール詳細](docs/terraform_modules.md): `modules/` 配下の各部品の役割と詳細解説。
- [Terraform 環境構成詳細](docs/terraform_environments.md): `environments/dev` におけるファイル分割と構成。
- [Terraform コマンド集](docs/terraform_commands.md): 日常的に使用する主要コマンドとトラブルシューティング。
- [GitHub Actions 設計](docs/github_actions.md): インフラCI/CDのワークフロー構成とOIDC連携。

### 🔍 特定テーマ・履歴
- [Blue/Green デプロイ詳細](docs/ecs_blue_green_deployment.md): ローリングアップデートではない、ECS標準のBGデプロイの仕組み。
- [セキュリティ・改善提案](docs/improvement_recommendations.md): AWSベストプラクティスに基づく将来的な拡張案。
- [Cognito 導入検討](docs/cognito_reference.md): 認証基盤導入に向けた参考実装例（将来用）。
- [デプロイ履歴 (dev)](docs/deployment_log_dev.md): 初期構築時のログおよびトラブルシューティング記録。

---

## ディレクトリ構成

```
aws_ecs/
├── bootstrap/          # tfstate用S3/DynamoDB初期構築
├── modules/            # 共通モジュール
│   ├── vpc/           # VPC、サブネット、NAT Gateway
│   ├── security_group/# セキュリティグループ
│   ├── alb/           # ALB、ターゲットグループ
│   ├── ecs_cluster/   # ECSクラスター
│   ├── ecs_service/   # ECSサービス、タスク定義
│   ├── rds/           # RDS PostgreSQL
│   ├── ecr/           # ECRリポジトリ
│   ├── waf/           # AWS WAF
│   ├── s3/            # S3バケット
│   ├── acm/           # SSL証明書
│   ├── backup/        # AWS Backup (RDS/S3バックアップ)
│   ├── cicd/          # CodeBuild、CodePipeline
│   ├── cloudwatch/    # CloudWatch監視
│   ├── security_hub/  # AWS Security Hub
│   ├── guardduty/     # Amazon GuardDuty
│   ├── config/        # AWS Config
│   └── cloudtrail/    # AWS CloudTrail
├── environments/       # 環境別設定
│   ├── dev/            # 開発環境
│   │   ├── main.tf             # Terraform基本設定
│   │   ├── network.tf          # 足回り (VPC, ALB, WAF)
│   │   ├── compute.tf          # コンピュート (ECS, ECR)
│   │   ├── database.tf         # データストア (RDS, S3)
│   │   ├── cicd_monitoring.tf  # パイプライン・監視
│   │   └── security.tf         # セキュリティ (Security Hub, GuardDuty, Config, CloudTrail)
│   ├── stg/            # ステージング環境 (ファイル構成はdevと同様)
│   └── prd/            # 本番環境 (ファイル構成はdevと同様)
└── .github/workflows/  # GitHub Actions
```

## 初回セットアップ

### 1. tfstate用リソースの作成

```bash
cd bootstrap
terraform init
terraform apply
```

### 2. backend.tf の更新

各環境の `backend.tf` でアカウントIDを実際の値に置き換え:

```hcl
bucket = "ecs-web-app-tfstate-<アカウントID>"
```

### 3. 変数ファイルの作成

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集
```

### 4. ECRリポジトリの作成 (dev環境で)

```bash
cd environments/dev
terraform init
terraform apply -target=module.ecr_app1 -target=module.ecr_app2
```

### 5. 全リソースのデプロイ

```bash
terraform apply
```

## 環境別設定

| パラメータ | dev | stg | prd |
|-----------|-----|-----|-----|
| ECS タスク数 | 1 | 1 | 2 |
| RDS インスタンス | db.t4g.micro | db.t4g.micro | db.t4g.medium |
| NAT Gateway | 1 + VPC Endpoints | 1 + VPC Endpoints | 2 |
| マルチAZ RDS | No | No | Yes |
| Container Insights | Yes | Yes | Yes |
| Fargate Spot | Yes | Yes | No |

## CI/CD

本プロジェクトのCI/CDは、AWS CodePipelineとGitHubの直接連携（CodeStar Connections）により動作。

1. **Source (GitHub)**:
   - CodePipelineがGitHubリポジトリの指定ブランチ（`develop` / `staging`）の変更を常時監視。
   - プッシュ（またはマージ）が行われると、パイプラインが自動的にトリガーされる。

2. **Build (CodeBuild)**:
   - リポジトリからソースコードを取得し、`buildspec.yml` に従ってDockerイメージをビルド（`--platform linux/amd64`）。
   - ビルドしたイメージをECRへプッシュ。
   - `aws ecs update-service --force-new-deployment` を実行し、ECSのデプロイを開始。

3. **Deploy (ECS Built-in Blue/Green)**:
   - ECSが新しいタスクセット（Green環境）を起動。
   - **テスト稼働**: まずテスト用ポート（`10080`）がGreen環境に向けられ、動作確認が可能。
   - **Bake Time（待機時間）**: 設定された時間（stg: **5分**）、自動的に待機。この間にロールバックが必要なエラーがないか監視。
   - **本番切り替え**: 待機時間が経過すると、本番ポート（`80`/`443`）がGreen環境へ切り替わる。旧バージョン（Blue）はその後停止。
   - **詳細**: デプロイの流れや仕組みの詳細は [ECS Blue/Green デプロイメント詳細](docs/ecs_blue_green_deployment.md) を参照。

### GitHub Secrets (必須)

```
AWS_ROLE_ARN_DEV     # dev環境用IAMロールARN
AWS_ROLE_ARN_STG     # stg環境用IAMロールARN
AWS_ROLE_ARN_PRD     # prd環境用IAMロールARN
```

### ブランチ戦略

- `production`: 安定版（本番リリースのベース） -> prd環境 (手動実行: 自動トリガーOFF)
- `develop`  : 開発ブランチ → dev環境 (自動デプロイ)
- `staging`  : 検証ブランチ → stg環境 (自動デプロイ)
- `main`/`master`: (使用停止・削除済み)

## アプリケーションアクセス

- App1: `https://<ドメイン>/app1/*`
- App2: `https://<ドメイン>/app2/*`

## 注意事項

- 本番環境のRDSは削除保護が有効
- DBパスワードはSecrets Managerで自動生成・管理（tfvarsでの設定不要）
- **ドメイン・通知設定**: デプロイ後にSSL証明書やSNSサブスクリプションの設定が必要。詳細は [リリースガイド](docs/release_guide.md#step-7-構築後の設定-post-deployment) を参照。

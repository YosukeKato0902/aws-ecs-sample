# AWS ECS Fargate Webアプリケーション基盤 詳細設計書

---

## 目次

1. [ドキュメント概要](#1-ドキュメント概要)
2. [ネットワーク詳細設計](#2-ネットワーク詳細設計)
3. [セキュリティグループ詳細設計](#3-セキュリティグループ詳細設計)
4. [ALB詳細設計](#4-alb詳細設計)
5. [ECS詳細設計](#5-ecs詳細設計)
6. [RDS詳細設計](#6-rds詳細設計)
7. [ECR詳細設計](#7-ecr詳細設計)
8. [WAF詳細設計](#8-waf詳細設計)
9. [S3詳細設計](#9-s3詳細設計)
10. [AWS Backup詳細設計](#10-aws-backup詳細設計)
11. [CI/CD詳細設計](#11-cicd詳細設計)
12. [IAMロール一覧](#11-iamロール一覧)
13. [環境変数設計](#12-環境変数設計)
14. [命名規則](#13-命名規則)
15. [実装メモ（トラブルシューティング）](#14-実装メモトラブルシューティング)
16. [セキュリティサービス詳細設計](#15-セキュリティサービス詳細設計)

---

## 1. ドキュメント概要

| 項目 | 内容 |
|-----|------|
| プロジェクト名 | ECS Web Application |
| 作成日 | 2026-01-05 |
| 更新日 | 2026-01-05 |
| バージョン | 1.0 |
| 関連ドキュメント | 基本設計書 |

---

## 2. ネットワーク詳細設計

### 2.1 VPC設計

| 項目 | dev | stg | prd |
|-----|-----|-----|-----|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| DNSホスト名 | 有効 | 有効 | 有効 |
| DNSサポート | 有効 | 有効 | 有効 |

### 2.2 サブネット設計

#### パブリックサブネット

| 環境 | AZ | CIDR | 用途 |
|-----|-----|------|------|
| dev | ap-northeast-1a | 10.0.0.0/20 | ALB, NAT Gateway |
| dev | ap-northeast-1c | 10.0.16.0/20 | ALB, NAT Gateway |
| stg | ap-northeast-1a | 10.1.0.0/20 | ALB, NAT Gateway |
| stg | ap-northeast-1c | 10.1.16.0/20 | ALB, NAT Gateway |
| prd | ap-northeast-1a | 10.2.0.0/20 | ALB, NAT Gateway |
| prd | ap-northeast-1c | 10.2.16.0/20 | ALB, NAT Gateway |

#### プライベートサブネット

| 環境 | AZ | CIDR | 用途 |
|-----|-----|------|------|
| dev | ap-northeast-1a | 10.0.32.0/20 | ECS, RDS |
| dev | ap-northeast-1c | 10.0.48.0/20 | ECS, RDS |
| stg | ap-northeast-1a | 10.1.32.0/20 | ECS, RDS |
| stg | ap-northeast-1c | 10.1.48.0/20 | ECS, RDS |
| prd | ap-northeast-1a | 10.2.32.0/20 | ECS, RDS |
| prd | ap-northeast-1c | 10.2.48.0/20 | ECS, RDS |

### 2.3 NAT Gateway設計

| 環境 | 数量 | 配置 | 理由 |
|-----|------|------|------|
| dev | 1 | ap-northeast-1a | コスト削減 |
| stg | 1 | ap-northeast-1a | コスト削減 |
| prd | 2 | 各AZに1つ | 高可用性 |

### 2.4 VPC Endpoints (dev/stg環境)

| エンドポイント | タイプ | 用途 |
|--------------|-------|------|
| com.amazonaws.ap-northeast-1.ecr.api | Interface | ECR API通信 |
| com.amazonaws.ap-northeast-1.ecr.dkr | Interface | ECR Docker通信 |
| com.amazonaws.ap-northeast-1.s3 | Gateway | S3通信 |
| com.amazonaws.ap-northeast-1.logs | Interface | CloudWatch Logs |

---

## 3. セキュリティグループ詳細設計

### 3.1 ALB用セキュリティグループ

| ルール | ポート | プロトコル | ソース | 説明 |
|-------|-------|----------|-------|------|
| Ingress | 443 | TCP | 0.0.0.0/0 | HTTPS |
| Ingress | 80 | TCP | 0.0.0.0/0 | HTTP (リダイレクト用) |
| Ingress | 10080 | TCP | 0.0.0.0/0 | HTTP (検証用テストリスナー) |
| Egress | All | All | 0.0.0.0/0 | 全送信許可 |

### 3.2 ECS用セキュリティグループ

| ルール | ポート | プロトコル | ソース | 説明 |
|-------|-------|----------|-------|------|
| Ingress | 8080 | TCP | ALB SG | ALBからのみ許可 |
| Egress | All | All | 0.0.0.0/0 | 全送信許可 |

### 3.3 RDS用セキュリティグループ

| ルール | ポート | プロトコル | ソース | 説明 |
|-------|-------|----------|-------|------|
| Ingress | 5432 | TCP | ECS SG | PostgreSQL接続 |
| Egress | All | All | 0.0.0.0/0 | 全送信許可 |

---

## 4. ALB詳細設計

### 4.1 ALB設定

| 項目 | 値 |
|-----|-----|
| スキーム | internet-facing |
| IPアドレスタイプ | IPv4 |
| 削除保護 | prd: 有効, dev/stg: 無効 |

### 4.2 リスナー設定

| リスナー | ポート | プロトコル | アクション |
|---------|-------|----------|----------|
| HTTPS | 443 | HTTPS | ルールベースルーティング |
| HTTP | 80 | HTTP | HTTPSへリダイレクト |
| HTTP | 10080 | HTTP | テストリスナー（Blue/Green検証） |

### 4.3 ターゲットグループ

| ターゲットグループ | ポート | ヘルスチェック | 用途 |
|------------------|-------|--------------|------|
| app1-tg | 8080 | /health | App1 Blue |
| app1-tg-green | 8080 | /health | App1 Green |
| app2-tg | 8080 | /health | App2 Blue |
| app2-tg-green | 8080 | /health | App2 Green |

### 4.4 ルーティングルール

| 優先度 | 条件 | ターゲット |
|-------|------|----------|
| 100 | path-pattern: /app1/* | app1-tg |
| 200 | path-pattern: /app2/* | app2-tg |
| Default | - | 404 Fixed Response |

---

## 5. ECS詳細設計

### 5.1 クラスター設定

| 項目 | dev | stg | prd |
|-----|-----|-----|-----|
| Container Insights | 有効 | 有効 | 有効 |
| キャパシティプロバイダー | FARGATE_SPOT | FARGATE_SPOT | FARGATE |

### 5.2 タスク定義

#### App1/App2共通

| 項目 | dev/stg | prd |
|-----|---------|-----|
| CPU | 256 | 512 |
| Memory | 512 | 1024 |
| ネットワークモード | awsvpc | awsvpc |
| 起動タイプ | FARGATE | FARGATE |

#### コンテナ定義

| 項目 | 値 |
|-----|-----|
| ポート | 8080 |
| ログドライバー | awslogs |
| ヘルスチェック | curl -f http://localhost:8080/health |

### 5.3 サービス設定

| 項目 | dev/stg | prd |
|-----|---------|-----|
| 希望タスク数 | 1 | 2 |
| 最小タスク数 | 1 | 2 |
| 最大タスク数 | 2 | 10 |
| デプロイタイプ | ECS (Built-in Blue/Green) | ECS (Built-in Blue/Green) |
| ベイク時間 | 5分 | 10分 |
| 検証フック | Lambda (POST_TEST_TRAFFIC_SHIFT) | Lambda (POST_TEST_TRAFFIC_SHIFT) |

### 5.4 Auto Scaling

| 項目 | 値 |
|-----|-----|
| CPU目標値 | 70% |
| Memory目標値 | 80% |
| スケールアウトクールダウン | 60秒 |
| スケールインクールダウン | 300秒 |

---

## 6. RDS詳細設計

### 6.1 インスタンス設定

| 項目 | dev | stg | prd |
|-----|-----|-----|-----|
| エンジン | PostgreSQL 15.4 | PostgreSQL 15.4 | PostgreSQL 15.4 |
| インスタンスクラス | db.t4g.micro | db.t4g.micro | db.t4g.medium |
| ストレージ | 20GB gp3 | 20GB gp3 | 50GB gp3 |
| 最大ストレージ | 50GB | 100GB | 200GB |
| マルチAZ | No | No | Yes |

### 6.2 バックアップ設定

| 項目 | dev | stg | prd |
|-----|-----|-----|-----|
| 自動バックアップ | 有効 | 有効 | 有効 |
| 保持期間 | 3日 | 7日 | 14日 |
| バックアップ時間 | 03:00-04:00 JST | 03:00-04:00 JST | 03:00-04:00 JST |
| メンテナンス時間 | Mon 04:00-05:00 | Mon 04:00-05:00 | Mon 04:00-05:00 |

### 6.3 セキュリティ設定

| 項目 | 値 |
|-----|-----|
| 暗号化 | 有効 (AES-256) |
| パブリックアクセス | 無効 |
| 削除保護 | prd: 有効 |
| 最終スナップショット | prd: 必須 |

---

## 7. ECR詳細設計

### 7.1 リポジトリ設定

| リポジトリ | 用途 |
|-----------|------|
| ecs-web-app/app1 | App1イメージ |
| ecs-web-app/app2 | App2イメージ |

### 7.2 ライフサイクルポリシー

| ルール | 条件 | アクション |
|-------|------|----------|
| 1 | タグなし、1日経過 | 削除 |
| 2 | dev-* タグ、10個超過 | 古いもの削除 |
| 3 | stg-* タグ、10個超過 | 古いもの削除 |
| 4 | prd-* タグ、30個超過 | 古いもの削除 |

---

## 8. WAF詳細設計

### 8.1 マネージドルール

| ルール名 | 優先度 | 説明 |
|---------|-------|------|
| AWSManagedRulesCommonRuleSet | 1 | 一般的な攻撃防御 |
| AWSManagedRulesKnownBadInputsRuleSet | 2 | 既知の悪意ある入力 |
| AWSManagedRulesSQLiRuleSet | 3 | SQLインジェクション |

### 8.2 カスタムルール

| ルール名 | 優先度 | 条件 | アクション |
|---------|-------|------|----------|
| RateBasedRule | 4 | dev/stg: 2000, prd: 3000リクエスト/5分 | Block |

---

## 9. S3詳細設計

### 9.1 バケット設計

| バケット名パターン | 用途 |
|------------------|------|
| {project}-{env}-app-storage-{account} | アプリデータ |
| {project}-{env}-cicd-artifacts-{account} | CI/CDアーティファクト |
| {project}-{env}-audit-logs-{account} | 監査ログ (CloudTrail/Config) |
| {project}-{env}-alb-logs-{account} | ALBアクセスログ (prdのみ) |
| {project}-tfstate-{account} | Terraform state |

### 9.2 セキュリティ設定

| 項目 | 値 |
|-----|-----|
| バージョニング | 有効 |
| 暗号化 | AES-256 |
| パブリックアクセス | 全ブロック |

---

## 10. AWS Backup詳細設計

### 10.1 概要

AWS Backupを使用してRDSおよびS3の定期バックアップを自動化。

### 10.2 バックアップボルト

| 項目 | 値 |
|-----|-----|
| ボルト名 | {project}-{env}-backup-vault |
| 暗号化 | AWS管理キー (デフォルト) |

### 10.3 RDSバックアップ設定

| バックアップタイプ | スケジュール (JST) | 保持期間 | 対象 |
|------------------|------------------|---------|------|
| 日次バックアップ | 毎日 02:00 | 7日間 | app1, app2 RDSインスタンス |
| 週次バックアップ | 毎週日曜 02:00 | 35日間 (5週間) | app1, app2 RDSインスタンス |

### 10.4 S3バックアップ設定

| バックアップタイプ | スケジュール (JST) | 保持期間 | 対象 |
|------------------|------------------|---------|------|
| 日次バックアップ | 毎日 03:00 | 30日間 | app-storage バケット |

### 10.5 IAMロール

| ロール名 | 用途 | 付与ポリシー |
|---------|------|-------------|
| {project}-{env}-backup-role | AWS Backupがリソースにアクセス | AWSBackupServiceRolePolicyForBackup, AWSBackupServiceRolePolicyForRestores, AWSBackupServiceRolePolicyForS3Backup, AWSBackupServiceRolePolicyForS3Restore |

### 10.6 リストア手順

```bash
# バックアップリカバリポイント一覧
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name ecs-web-app-${ENV}-backup-vault \
  --query 'RecoveryPoints[*].[RecoveryPointArn,ResourceType,CreationDate]' \
  --output table

# RDSリストアジョブ開始
aws backup start-restore-job \
  --recovery-point-arn <RECOVERY_POINT_ARN> \
  --metadata '{"DBInstanceIdentifier":"restored-db-instance"}' \
  --iam-role-arn <BACKUP_ROLE_ARN>
```

---

## 11. CI/CD詳細設計

### 10.1 CodeBuild設定

| 項目 | 値 |
|-----|-----|
| コンピュート | BUILD_GENERAL1_SMALL |
| イメージ | aws/codebuild/amazonlinux2-x86_64-standard:5.0 |
| 特権モード | 有効 (Docker使用) |
| タイムアウト | 30分 |

### 10.2 ECS組み込みBlue/Greenデプロイ詳細

| 項目 | 値 |
|-----|-----|
| 戦略 | BLUE_GREEN |
### 10.3 CodePipeline設定

| ステージ | アクション | 詳細 |
|---------|-----------|------|
| Source | CodeStarSourceConnection | GitHubリポジトリの特定ブランチ (`develop`/`staging`) を監視 |
| Build | CodeBuild | ビルド、ECRプッシュ、ECSサービス更新を実行 |

※ GitHub Actionsは使用せず、AWS CodePipelineが直接GitHubリポジトリと連携する構成。

---

## 11. IAMロール一覧

| ロール名パターン | 用途 |
|----------------|------|
| {project}-{env}-{service}-execution-role | ECSタスク実行 |
| {project}-{env}-{service}-task-role | ECSタスク |
| {project}-{env}-{service}-codebuild-role | CodeBuild |
| {project}-{env}-{service}-codedeploy-role | CodeDeploy |
| {project}-{env}-{service}-pipeline-role | CodePipeline |

---

## 12. 環境変数設計

### 12.1 ECSタスク環境変数

| 変数名 | 説明 | 設定元 |
|-------|------|-------|
| DB_HOST | RDSエンドポイント | Terraform output |
| DB_NAME | データベース名 | Terraform変数 |
| DB_PASSWORD | DBパスワード | Secrets Manager (注入) |
| ENVIRONMENT | 環境名 | Terraform変数 |

### 12.2 GitHub Secrets

| Secret名 | 用途 |
|---------|------|
| AWS_ROLE_ARN_{ENV} | OIDC認証用IAMロール |


---

## 13. 命名規則

### 13.1 リソース命名

```
{project_name}-{environment}-{resource_type}[-{identifier}]
```

例:
- `ecs-web-app-dev-vpc`
- `ecs-web-app-prd-app1-tg`
- `ecs-web-app-stg-rds-app2`

### 13.2 タグ規則

| タグ | 値 |
|-----|-----|
| Project | ecs-web-app |
| Environment | dev / stg / prd |
| ManagedBy | terraform |
| CostCenter | development / staging / production |
| Owner | platform-team |

### 13.3 VPC Flow Logs

| 環境 | 有効化 | ログ保存先 |
|-----|--------|-----------|
| dev | オプション | CloudWatch Logs |
| stg | オプション | CloudWatch Logs |
| prd | 推奨 | CloudWatch Logs |

---

## 14. 実装メモ（トラブルシューティング）

### 14.1 セキュリティグループのDescription制限
AWS Providerの仕様により、Security Group Ruleの `description` フィールドには日本語（マルチバイト文字）を使用できない場合がある（`^[0-9A-Za-z_ .:/()#,@\[\]+=&;{}!$*-]*$`）。
そのため、Descriptionはすべて英語（ASCII文字）で記述すること。

### 14.2 Terraform `count` と `computed` 値の制約
ECSタスクIAMロールへのS3ポリシー付与において、`count = var.s3_bucket_arn != "" ? 1 : 0` のように `apply` 後に確定する値（ARNなど）を条件に使用すると、`Invalid count argument` エラーが発生する。
対策として、明示的なフラグ変数 `enable_s3_access` (bool) を導入し、これに基づいて `count` を制御する設計としている。

---

## 15. セキュリティサービス詳細設計

### 15.1 Security Hub

| 項目 | dev | stg | prd |
|-----|-----|-----|-----|
| 有効化 | ✅ | ✅ | ✅ |
| AWS Foundational標準 | ✅ | ✅ | ✅ |
| CIS Benchmark | ❌ | ✅ | ✅ |

### 15.2 GuardDuty

| 保護機能 | 説明 | 全環境 |
|---------|------|--------|
| S3_DATA_EVENTS | S3への不審なアクセス検知 | ✅ |
| EBS_MALWARE_PROTECTION | マルウェアスキャン | ✅ |
| RDS_LOGIN_EVENTS | 不審なDBログイン検知 | ✅ |

### 15.3 AWS Config

| 項目 | 値 |
|-----|-----|
| 記録対象 | 全サポートリソース |
| 配信先 | S3バケット (監査ログ用) |
| 通知先 | SNS (オプション) |

### 15.4 CloudTrail

| 項目 | dev | stg | prd |
|-----|-----|-----|-----|
| マルチリージョン | ✅ | ✅ | ✅ |
| グローバルサービス | ✅ | ✅ | ✅ |
| S3データイベント | ❌ | ❌ | ✅ |
| CloudWatch連携 | ✅ | ✅ | ✅ |
| ログ保持期間 | 7日 | 90日 | 365日 |

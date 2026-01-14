# セキュリティ・可用性改善提案 (Improvement Recommendations)

本ドキュメントでは、AWS ECS Fargate Webアプリケーション基盤に対する、AWSベストプラクティスおよびセキュリティ・可用性の観点からの改善提案を記載する。

---

## 目次

1. [実装ステータス](#実装ステータス2026-01-08-更新)
2. [概要](#1-概要)
3. [優先度: 高（セキュリティ上の懸念）](#2-優先度-高セキュリティ上の懸念)
4. [優先度: 中（可用性・運用上の改善）](#3-優先度-中可用性運用上の改善)
5. [優先度: 低（ベストプラクティス準拠）](#4-優先度-低ベストプラクティス準拠)
6. [環境別推奨設定サマリー](#5-環境別推奨設定サマリー)
7. [その他の推奨事項](#6-その他の推奨事項)
8. [参考リンク](#7-参考リンク)

---

## 実装ステータス（2026-01-08 更新）

> [!NOTE]
> 以下の項目は実装済み。詳細は各セクションを参照。

| 項目 | ステータス | 実装箇所 |
|------|----------|---------|
| 2.2 Secrets Manager recovery_window | ✅ 実装済み | `modules/rds` 変数化、prd: 30日 |
| 2.3 IAM ポリシー最小権限化 | ✅ 実装済み | `modules/cicd` 特定ARN指定 |
| 2.5 ECR イメージタグ不変性 | ✅ 実装済み | `modules/ecr` 変数化 |
| 3.1 NAT Gateway 冗長化 | ✅ 実装済み | 環境別設定済み |
| 3.2 RDS Multi-AZ | ✅ 実装済み | 環境別設定済み |
| 3.3 ALB アクセスログ | ✅ 実装済み | prd環境でS3バケット設定 |
| 3.4 RDS Performance Insights | ✅ 実装済み | 変数化、prd: 有効 |
| 3.5 ECS タスク最小稼働数 | ✅ 実装済み | 環境別設定済み |
| 4.3 VPC Flow Logs | ✅ 実装済み | `modules/vpc` 追加 |
| 4.6 VPC Endpoints | ✅ 実装済み | prd環境で有効化 |
| 6. コスト管理タグ | ✅ 実装済み | default_tagsにCostCenter/Owner追加 |
| 6. Security Hub | ✅ 実装済み | `modules/security_hub`, `prd`で有効化 |
| 6. GuardDuty | ✅ 実装済み | `modules/guardduty`, `prd`で有効化 |
| 6. AWS Config | ✅ 実装済み | `modules/config`, `prd`で有効化 |
| 6. CloudTrail | ✅ 実装済み | `modules/cloudtrail`, `prd`で有効化 |
| 7. AWS Backup (prd) | ✅ 実装済み | `prd/cicd_monitoring.tf` で適用 |
| 8. WAF ロギング (prd) | ✅ 実装済み | `prd/network.tf` で有効化 |

### 除外/未実装の項目
| 項目 | 理由 |
|------|------|
| 2.1 テストリスナーIP制限 | 環境固有設定のため要検討 |
| 2.4 ECS インフラロール権限限定 | 複雑性のため今後検討 |
| 4.5 readonlyRootFilesystem | 既存アプリへの影響要検証 |
| 3.6 Secrets Manager 自動ローテーション | 今後検討 |

---

## 1. 概要

現在の構成は dev 環境向けにコスト最適化されているが、stg/prd 環境への展開時には以下の改善を検討されたい。

---

## 2. 優先度: 高（セキュリティ上の懸念）

### 2.1 テストリスナー（ポート 10080）のIP制限

**対象ファイル**: `modules/security_group/main.tf` (L33-40)

**現状**:
```hcl
ingress {
  description = "Allow Test HTTP traffic"
  from_port   = 10080
  to_port     = 10080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**問題点**:
- テスト用リスナーが全世界に公開されている
- Blue/Green デプロイメント検証中の新バージョンに誰でもアクセス可能
- 未検証の機能やバグが外部に露出するリスク

**推奨される対応**:
- 本番環境では会社のIPアドレス範囲に制限
- または VPN 経由のみにアクセスを限定

```hcl
cidr_blocks = ["203.0.113.0/24"]  # 会社のグローバルIPに制限
```

---

### 2.2 Secrets Manager の recovery_window 設定

**対象ファイル**: `modules/rds/main.tf` (L64)

**現状**:
```hcl
recovery_window_in_days = 0
```

**問題点**:
- シークレット削除時に即時削除される
- 誤操作時にパスワードを復旧できない
- DBへのアクセスが完全に不可能になるリスク

**推奨される対応**:

| 環境 | 推奨値 |
|------|--------|
| dev | 0（現状維持可） |
| stg | 7 |
| prd | 30 |

> **メモ**: この値は変数化して `var.recovery_window_in_days` として環境ごとに設定することを推奨。

---

### 2.3 IAM ポリシーの最小権限化

**対象ファイル**: `modules/cicd/main.tf`, `modules/ecs_service/main.tf`

**現状**:
```hcl
Resource = "*"
```

**問題点**:
- 最小権限の原則に違反
- CodeBuild ロールが全 ECR リポジトリ・全 ECS サービスを操作可能
- 万が一の侵害時に影響範囲が広大

**推奨される対応**:
リソース ARN を限定する。

```hcl
# ECR の例
Resource = [
  "arn:aws:ecr:ap-northeast-1:${data.aws_caller_identity.current.account_id}:repository/ecs-web-app/*"
]

# ECS の例
Resource = [
  "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:service/ecs-web-app-*-cluster/*"
]
```

---

### 2.4 ECS インフラロールの権限限定

**対象ファイル**: `modules/ecs_service/main.tf` (L159)

**現状**:
```hcl
Resource = "*"
```

**問題点**:
- 全ての ALB リソースを操作可能

**推奨される対応**:
対象の ALB / ターゲットグループのみに限定。

---

### 2.5 ECR イメージタグの不変性（本番環境必須）

**対象ファイル**: `modules/ecr/main.tf` (L12)

**現状**:
```hcl
image_tag_mutability = "MUTABLE"
```

**問題点**:
- 同じタグ（例: `v1.0.0`）で異なるイメージをプッシュ可能
- 本番環境で意図せず異なるイメージがデプロイされるリスク
- 監査・トレーサビリティの欠如

**推奨される対応**:

| 環境 | 推奨値 |
|------|--------|
| dev | MUTABLE（開発効率優先） |
| stg | IMMUTABLE |
| prd | IMMUTABLE（必須） |

```hcl
image_tag_mutability = var.environment == "dev" ? "MUTABLE" : "IMMUTABLE"
```

---

### 2.6 コンテナイメージの `:latest` タグ使用禁止

**対象**: アプリケーションデプロイ設定

**問題点**:
- `:latest` タグはどのバージョンがデプロイされているか特定困難
- ロールバック時にどのイメージに戻すべきか判断できない
- 本番障害時の原因調査が困難

**推奨される対応**:
- Git SHA ハッシュ（例: `abc1234`）またはセマンティックバージョン（例: `v1.2.3`）を使用
- buildspec.yml でタグを動的に設定

```yaml
# buildspec.yml の例
IMAGE_TAG: $(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
```

---

## 3. 優先度: 中（可用性・運用上の改善）

### 3.1 NAT Gateway の冗長化

**対象ファイル**: `modules/vpc/main.tf`

**現状**:
- dev 環境: `nat_gateway_count = 1`

**問題点**:
- NAT Gateway が単一障害点（SPOF）
- NAT Gateway 障害時にプライベートサブネットからの外部通信が不可

**推奨される対応**:

| 環境 | 推奨値 |
|------|--------|
| dev | 1（コスト優先） |
| stg | 2 |
| prd | 2（AZごとに配置） |

---

### 3.2 RDS Multi-AZ の有効化

**対象ファイル**: `modules/rds/main.tf`

**現状**:
- dev 環境: `multi_az = false`

**問題点**:
- DB がシングル AZ
- AZ 障害時にサービス完全停止

**推奨される対応**:

| 環境 | 推奨値 |
|------|--------|
| dev | false |
| stg | true |
| prd | true |

---

### 3.3 ALB アクセスログの有効化

**対象ファイル**: `modules/alb/main.tf` (L20-27)

**現状**:
- `access_logs_bucket` が空の場合、ログが取得されない

**問題点**:
- アクセス解析・セキュリティ監査ができない
- インシデント発生時のフォレンジック調査が困難

**推奨される対応**:
- 本番環境ではアクセスログを必須に
- S3 バケットを作成し、ALB アクセスログを保存

---

### 3.4 RDS Performance Insights の有効化

**対象ファイル**: `modules/rds/main.tf`

**現状**:
- dev/stg: `performance_insights_enabled = false`

**問題点**:
- パフォーマンス問題の診断が困難
- 本番障害の原因調査に時間がかかる

**推奨される対応**:
- stg 環境でも有効化（問題の早期発見のため）

---

### 3.5 ECS タスクの最小稼働数

**対象**: 環境ごとの `desired_count` 設定

**現状**:
- dev 環境: `desired_count = 1`

**問題点**:
- タスクが1つのみの場合、デプロイ中やタスク障害時にサービス停止
- Blue/Green デプロイ中のダウンタイム発生リスク

**推奨される対応**:

| 環境 | 推奨値 |
|------|--------|
| dev | 1 |
| stg | 2 |
| prd | 2以上（Auto Scaling と併用） |

---

### 3.6 Secrets Manager の自動ローテーション

**対象ファイル**: `modules/rds/main.tf`

**現状**:
- パスワードは初回作成時のみ生成、以後変更なし

**問題点**:
- 長期間同じパスワードを使用し続けるセキュリティリスク
- コンプライアンス要件（90日ごとのローテーション等）を満たせない可能性

**推奨される対応**:
- Lambda を使用した自動ローテーションの設定を検討
- `aws_secretsmanager_secret_rotation` リソースの追加

---

## 4. 優先度: 低（ベストプラクティス準拠）

### 4.1 S3 暗号化の強化

**対象ファイル**: `modules/s3/main.tf`

**現状**:
```hcl
sse_algorithm = "AES256"  # SSE-S3
```

**推奨される対応**:
- 機密データを扱う場合は SSE-KMS（CMK）を検討
- キーのローテーションや監査ログが可能になる

---

### 4.2 CloudWatch Logs の暗号化

**対象ファイル**: `modules/ecs_cluster/main.tf`

**現状**:
- ログの暗号化なし

**推奨される対応**:
- KMS 暗号化を有効化（`kms_key_id` を指定）

---

### 4.3 VPC Flow Logs の有効化

**対象ファイル**: `modules/vpc/main.tf`

**現状**:
- VPC Flow Logs なし

**問題点**:
- ネットワークトラフィックの監査ができない
- セキュリティインシデント時の調査が困難

**推奨される対応**:
- VPC Flow Logs を有効化
- CloudWatch Logs または S3 に出力

---

### 4.4 HTTPS の必須化

**対象ファイル**: `modules/alb/main.tf`

**現状**:
- 証明書がない場合、HTTP のまま運用される

**推奨される対応**:
- 本番環境では HTTPS を必須に
- 証明書なしでのデプロイを禁止するバリデーション追加を検討

---

### 4.5 コンテナのセキュリティ強化

**対象ファイル**: `modules/ecs_service/main.tf`

**推奨される対応**:
- `readonlyRootFilesystem = true` の設定
- コンテナ内でのファイル書き込みを制限
- `/tmp` などの書き込み可能なボリュームのみマウント

---

### 4.6 VPC Endpoints の活用

**対象ファイル**: `modules/vpc/main.tf`

**現状**:
- `enable_vpc_endpoints = false` がデフォルト

**問題点**:
- NAT Gateway 経由で AWS サービス（ECR, S3, CloudWatch）にアクセス
- NAT Gateway のデータ処理コストが発生
- トラフィックがインターネットを経由する

**推奨される対応**:
- 本番環境では VPC Endpoints を有効化
- セキュリティ向上（AWS 内部ネットワークで完結）とコスト削減

```hcl
enable_vpc_endpoints = true  # prd 環境で推奨
```

---

### 4.7 ECR 暗号化の強化

**対象ファイル**: `modules/ecr/main.tf` (L18-20)

**現状**:
```hcl
encryption_configuration {
  encryption_type = "AES256"
}
```

**推奨される対応**:
- 機密性の高いアプリケーションでは KMS CMK を使用
- 監査ログの取得やキーローテーションが可能に

---

### 4.8 CodeBuild ログの暗号化

**対象ファイル**: `modules/cicd/main.tf`

**現状**:
- CloudWatch Logs への出力時に暗号化なし

**推奨される対応**:
- KMS 暗号化を有効化
- ビルドログに機密情報が含まれる可能性があるため

---

## 5. 環境別推奨設定サマリー

| 設定項目 | dev | stg | prd |
|---------|-----|-----|-----|
| NAT Gateway 数 | 1 | 2 | 2 |
| RDS Multi-AZ | false | true | true |
| RDS 削除保護 | false | true | true |
| RDS Performance Insights | false | true | true |
| Secrets Manager recovery_window | 0 | 7 | 30 |
| Secrets Manager 自動ローテーション | 任意 | 推奨 | 必須 |
| Fargate Spot | true | false | false |
| ECS desired_count | 1 | 2 | 2以上 |
| ALB アクセスログ | 任意 | 必須 | 必須 |
| VPC Flow Logs | 任意 | 任意 | 必須 |
| VPC Endpoints | false | 任意 | true |
| テストリスナー IP 制限 | 任意 | 推奨 | 必須 |
| CloudWatch Logs 暗号化 | 任意 | 推奨 | 必須 |
| ECR イメージタグ不変性 | MUTABLE | IMMUTABLE | IMMUTABLE |
| コンテナイメージタグ | :latest 可 | バージョン指定 | バージョン指定必須 |

---

## 6. その他の推奨事項

| カテゴリ | 推奨される対応 |
|---------|---------------|
| コスト管理 | コストアロケーションタグ（`CostCenter`, `Owner`）の追加 |
| バックアップ | AWS Backup による一元管理（クロスリージョンバックアップ等） |
| 監視 | AWS Health イベントの通知設定 |
| セキュリティ監視 | **AWS Security Hub** の有効化（セキュリティ基準への準拠状況を可視化） |
| 脅威検知 | **Amazon GuardDuty** の有効化（悪意のあるアクティビティの検出） |
| セキュリティ | AWS Shield Advanced（DDoS 保護）の検討 |
| コンプライアンス | AWS Config ルールによる設定監査 |
| ログ集約 | **AWS CloudTrail** の全リージョン有効化と S3 への保存 |

---

## 7. 参考リンク

- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [ECR Best Practices](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html)
- [Security Hub Getting Started](https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html)
- [GuardDuty Getting Started](https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html)

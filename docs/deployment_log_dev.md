# Dev環境 デプロイ実行履歴

---

## 目次

1. [概要](#概要)
2. [Phase 1: ECRリポジトリ作成](#phase-1-ecrリポジトリ作成)
3. [Phase 2: VPC・セキュリティグループ作成](#phase-2-vpcセキュリティグループ作成)
4. [Phase 3: ALB・WAF作成](#phase-3-albwaf作成)
5. [Phase 4: S3バケット作成](#phase-4-s3バケット作成)
6. [Phase 5: RDS作成](#phase-5-rds作成)
7. [Phase 6: ECSクラスター作成](#phase-6-ecsクラスター作成)
8. [Phase 6.5: ECRへ初期イメージPush](#phase-65-ecrへ初期イメージpush)
9. [Phase 7: ECSサービス作成](#phase-7-ecsサービス作成)
10. [Phase 8: CI/CD・監視リソース作成](#phase-8-cicd監視リソース作成)
11. [デプロイ完了サマリー](#デプロイ完了サマリー)
12. [トラブルシューティング: 503 Service Temporarily Unavailable](#トラブルシューティング-503-service-temporarily-unavailable)
13. [最終デプロイステータス](#最終デプロイステータス)

---

## 概要
- **環境**: dev
- **開始日時**: 2026-01-06 10:14
- **総リソース数**: 140

---

## Phase 1: ECRリポジトリ作成

### 実行コマンド
```bash
terraform apply -target=module.ecr_app1 -target=module.ecr_app2
```

### 実行結果
- **ステータス**: ✅ 成功
- **作成リソース数**: 4
- **所要時間**: 約30秒
- **出力**:
  - `ecr_app1_repository_url`: `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app1`
  - `ecr_app2_repository_url`: `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app2`

---

## Phase 2: VPC・セキュリティグループ作成

### 実行コマンド
```bash
terraform apply -target=module.vpc -target=module.security_group
```

### 実行結果
- **ステータス**: ✅ 成功
- **作成リソース数**: 23
- **所要時間**: 約2分
- **主な作成リソース**:
  - VPC (`vpc-0376a5400f1f77cb6`)
  - パブリック/プライベートサブネット (各2)
  - NAT Gateway (1)
  - VPC Endpoints (ECR API, ECR DKR, Logs, S3)
  - セキュリティグループ (ALB, ECS, RDS, VPC Endpoints用)

---

## Phase 3: ALB・WAF作成

### 実行コマンド
```bash
terraform apply -target=module.alb -target=module.waf
```

### 実行結果 (1回目)
- **ステータス**: ❌ 一部失敗
- **作成リソース数**: ALB関連は成功、WAF作成失敗
- **エラー内容**:
  ```
  Error: creating WAFv2 WebACL: ValidationException: Value 'ALB用WAF WebACL' at 'description' 
  failed to satisfy constraint: Member must satisfy regular expression pattern
  ```
- **原因**: WAFのdescriptionに日本語が使用できない
- **対応**: `modules/waf/main.tf` のdescriptionを英語に修正

### 再実行
- **ステータス**: ✅ 成功
- **作成リソース数**: 2 (WAF WebACL + ALB関連付け)
- **出力**:
  - `alb_dns_name`: `ecs-web-app-dev-alb-819741429.ap-northeast-1.elb.amazonaws.com`

---

## Phase 4: S3バケット作成

### 実行コマンド
```bash
terraform apply -target=module.s3_app -target=module.s3_artifacts
```

### 実行結果
- **ステータス**: ✅ 成功
- **作成リソース数**: 8
- **出力**:
  - `s3_app_bucket`: `ecs-web-app-dev-app-storage-123456789012`

---

## Phase 5: RDS作成

### 実行コマンド
```bash
terraform apply -target=module.rds_app1 -target=module.rds_app2
```

### 実行結果 (1回目)
- **ステータス**: ❌ 失敗
- **エラー内容**:
  ```
  Error: creating RDS DB Parameter Group: api error InvalidParameterValue: 
  The parameter Description must not contain non-printable control characters.
  ```
- **原因**: RDSのサブネットグループおよびパラメータグループのdescriptionに日本語が使用できない
- **対応**: `modules/rds/main.tf` のdescriptionを英語に修正

### 再実行
- **ステータス**: ✅ 成功
- **作成リソース数**: 8
- **所要時間**: 約8分
- **出力**:
  - `rds_app1_endpoint`: `ecs-web-app-dev-app1db.cpx06u0iwnyh.ap-northeast-1.rds.amazonaws.com:5432`
  - `rds_app2_endpoint`: `ecs-web-app-dev-app2db.cpx06u0iwnyh.ap-northeast-1.rds.amazonaws.com:5432`

---

## Phase 6: ECSクラスター作成

### 実行コマンド
```bash
terraform apply -target=module.ecs_cluster
```

### 実行結果
- **ステータス**: ✅ 成功
- **作成リソース数**: 3
- **所要時間**: 約15秒
- **出力**:
  - `ecs_cluster_name`: `ecs-web-app-dev-cluster`

---

## Phase 6.5: ECRへ初期イメージPush

> ⚠️ ECSサービス作成前に、コンテナイメージがECRに存在する必要がある。

### 実行コマンド
```bash
# ECRログイン
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com

# 初期イメージをPull & Tag & Push
docker pull nginx:alpine
docker tag nginx:alpine 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app1:latest
docker tag nginx:alpine 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app2:latest
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app1:latest
docker push 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app2:latest
```

### 実行結果
- **ステータス**: ✅ 成功（ユーザー手動実行）
- **操作内容**:
  - ECRログイン成功
  - `nginx:alpine` イメージPull成功
  - app1, app2 へのイメージPush成功
  - digest: `sha256:7cf0c9cc3c6b7ce30b46fa0fe53d95bee9d7803900edb965d3995ddf9ae12d03`

---

## Phase 7: ECSサービス作成

### 実行コマンド
```bash
terraform apply -target=module.ecs_service_app1 -target=module.ecs_service_app2
```

### 実行結果
- **ステータス**: ✅ 成功
- **作成リソース数**: 36
- **所要時間**: 約3分
- **主な作成リソース**:
  - ECSサービス (app1, app2)
  - タスク定義
  - IAMロール (実行、タスク、インフラ、ライフサイクル)
  - Lambda関数 (検証フック)
  - Auto Scalingポリシー

---

## Phase 8: CI/CD・監視リソース作成

### 実行コマンド
```bash
terraform apply  # 残り全リソース
```

### 実行結果
- **ステータス**: ⚠️ 一部エラー（想定内）
- **成功リソース数**: CloudWatch 11, CodeBuild準備系
- **エラー内容**:
  ```
  InvalidECSServiceException: Deployment group's ECS service must be configured 
  for a CODE_DEPLOY deployment controller.
  ```
- **原因**: ECSサービスは `ECS` コントローラ（AWS Provider v6.x の組み込みBlue/Green）を使用。`CODE_DEPLOY` コントローラではないため、CodeDeploy Deployment Groupは作成不可。
- **影響**: **問題なし** - ECS組み込みBlue/Greenデプロイを使用する設計のため、CodeDeployは不要。

---

## デプロイ完了サマリー

### 作成リソース総数
| Phase | 内容 | リソース数 | ステータス |
|-------|------|-----------|------------|
| 1 | ECR | 4 | ✅ |
| 2 | VPC, Security Group | 23 | ✅ |
| 3 | ALB, WAF | 16 | ✅ (修正後) |
| 4 | S3 | 8 | ✅ |
| 5 | RDS | 8 | ✅ (修正後) |
| 6 | ECS Cluster | 3 | ✅ |
| 6.5 | ECR Image Push | - | ✅ (手動) |
| 7 | ECS Service | 36 | ✅ |
| 8 | CI/CD, Monitoring | 11+ | ⚠️ (一部スキップ) |
| **合計** | - | **~109** | - |

### 修正したエラー (計2件)
1. **WAF description**: 日本語 → 英語
2. **RDS description**: 日本語 → 英語

### スキップしたリソース
- **CodeDeploy Deployment Group**: ECS組み込みBlue/Greenを使用するため不要

### 主要Output
| Key | Value |
|-----|-------|
| `alb_dns_name` | `ecs-web-app-dev-alb-819741429.ap-northeast-1.elb.amazonaws.com` |
| `ecs_cluster_name` | `ecs-web-app-dev-cluster` |
| `vpc_id` | `vpc-0376a5400f1f77cb6` |
| `rds_app1_endpoint` | `ecs-web-app-dev-app1db.cpx06u0iwnyh.ap-northeast-1.rds.amazonaws.com:5432` |
| `rds_app2_endpoint` | `ecs-web-app-dev-app2db.cpx06u0iwnyh.ap-northeast-1.rds.amazonaws.com:5432` |
| `s3_app_bucket` | `ecs-web-app-dev-app-storage-123456789012` |

### 完了日時
- **開始**: 2026-01-06 10:14
- **完了**: 2026-01-06 10:47

## トラブルシューティング: 503 Service Temporarily Unavailable

デプロイ後にALBへのアクセスで503エラーが発生。以下の手順で原因を特定し解決した。

### 1. 原因分析
- **現象**: ブラウザ・curlで503エラー。ALBターゲットグループのヘルスチェックがALL失敗。
- **調査**:
    - `aws ecs describe-services`: タスクが起動しては消える (running: 0, pending: 1) を繰り返す。
    - `aws logs get-log-events`: CloudWatch Logsを確認。

### 2. 特定された問題と対応

#### 問題A: ポートとヘルスチェックパスの不一致
- **原因**: 
    - `terraform.tfvars` で `app_port = 8080`, `health_check_path = "/health"` が指定されていた。
    - 実際のNginxコンテナはポート `80` でリッスンし、ルートパス `/` を返す設定だった。
- **対応**: 
    - `terraform.tfvars` を修正し、`app_port = 80`, `health_check_path = "/"` に変更。
    - `terraform apply` でALBターゲットグループとECSタスク定義を更新。
    - （ECSサービスの再作成が必要となり、`terraform taint` を使用して再作成実施）

#### 問題B: アーキテクチャの不一致 (exec format error)
- **原因**: 
    - ポート修正後もタスクが起動しない。ログに `exec format error` を確認。
    - Mac (M1/M2) 上で `docker pull nginx:alpine` を実行したため、`linux/arm64` イメージが取得されていた。
    - Fargate (x86_64) 上でARM64イメージを実行しようとしてクラッシュしていた。
- **対応**:
    - ローカルイメージを削除 (`docker rmi`)。
    - `docker pull --platform linux/amd64 nginx:alpine` で明示的にAMD64イメージを取得。
    - 再度 `docker tag` & `docker push` を実施。
    - `aws ecs update-service --force-new-deployment` でタスクを再起動。

### 3. トラブルシューティング結果
- **ステータス**: ✅ 解決
- **動作確認**:
    - `curl -I http://.../app1/` -> **404 Not Found**
    - **Header**: `Server: nginx/1.29.4`
    - **解説**: 404エラーだが、Nginxのバージョンが返ってきているため、ALBからコンテナへの通信は成功している。アプリケーションコンテンツが存在しないため404となるのは正常な挙動。

---

## 最終デプロイステータス

### 完了済みリソース
| Phase | モジュール | リソース数 | ステータス |
|-------|-----------|-----------|------------|
| 1 | ECR | 4 | ✅ |
| 2 | VPC, Security Group | 23 | ✅ |
| 3 | ALB, WAF | 16 | ✅ |
| 4 | S3 | 8 | ✅ |
| 5 | RDS | 8 | ✅ |
| 6 | ECS Cluster | 3 | ✅ |
| 6.5 | ECR Image Push | - | ✅ (AMD64再Push) |
| 7 | ECS Service | 36 | ✅ (再作成・修正) |
| 8 | CI/CD, Monitoring | 11+ | ⚠️ (一部スキップ) |
| **合計** | - | **~109** | - |

### 成果物
- **ALB DNS**: `ecs-web-app-dev-alb-819741429.ap-northeast-1.elb.amazonaws.com`
- **ECR Repo**: `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-web-app/app1`
- **RDS Endpoint**: `ecs-web-app-dev-app1db...`

### 今後の課題
1. **アプリコンテンツ配置**: 404を解消するために、適切な `nginx.conf` またはアプリケーションコードをデプロイする。
2. **CI/CDパイプライン稼働確認**: CodeBuild/CodePipeline経由での自動デプロイをテストする。


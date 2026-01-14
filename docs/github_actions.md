# GitHub Actions ワークフロー設計書

本ドキュメントでは、AWS ECS Fargate Web アプリケーション基盤における GitHub Actions ワークフローの設計と運用方法を解説する。

---

## 目次

1. [概要](#1-概要)
2. [認証方式: OIDC (OpenID Connect)](#2-認証方式-oidc-openid-connect)
3. [ワークフロー詳細](#3-ワークフロー詳細)
4. [同時実行制御 (Concurrency)](#4-同時実行制御-concurrency)
5. [必要な GitHub Secrets](#5-必要な-github-secrets)
6. [トラブルシューティング](#6-トラブルシューティング)
7. [ワークフローの手動実行方法](#7-ワークフローの手動実行方法)
8. [ワークフローファイル構成](#8-ワークフローファイル構成)
9. [運用ルール](#9-運用ルール)
10. [参考リンク](#10-参考リンク)

---

## 1. 概要

### 1.1 目的

GitHub Actions は以下の目的で使用：

- **Terraform Plan の自動実行**: ブランチへのプッシュ時に `terraform plan` を自動実行し、インフラ変更の影響を事前に確認
- **安全なデプロイ承認フロー**: Production 環境へのデプロイは手動発火かつ承認キーワード必須
- **セキュアな AWS 認証**: OIDC（OpenID Connect）による一時認証情報を使用し、長期的なアクセスキーを不要に

### 1.2 ワークフロー一覧

| ワークフロー | ファイル | トリガー | 対象環境 |
|-------------|---------|---------|---------|
| Terraform Dev | `.github/workflows/terraform-dev.yml` | `develop` ブランチへの push | dev |
| Terraform Staging | `.github/workflows/terraform-stg.yml` | `staging` ブランチへの push | stg |
| Terraform Production | `.github/workflows/terraform-prd.yml` | 手動発火 (workflow_dispatch) | prd |

---

## 1.3 CI/CD の分離設計

本プロジェクトでは、**インフラ変更**と**アプリケーション変更**で異なる CI/CD パイプラインを使用している。

### パイプライン構成

| パイプライン | ツール | トリガー | 対象 |
|-------------|--------|---------|------|
| **インフラ変更** | GitHub Actions + Terraform | ブランチ push | VPC, ALB, RDS, ECS定義 等 |
| **アプリケーション変更** | AWS CodePipeline + CodeBuild | GitHub push (CodeStar連携) | Docker イメージ、ECS タスク更新 |

### 分離した理由

#### 1. 変更頻度の違い

- **インフラ**: 月に数回程度（構成変更時のみ）
- **アプリ**: 日に数回～数十回（コード修正のたび）

頻繁なアプリ変更のたびに Terraform が走ると、時間もコストも無駄になる。

#### 2. リスクレベルの違い

- **インフラ変更**: VPC削除やRDS再作成など、破壊的変更のリスクがある → **慎重な承認フロー**が必要
- **アプリ変更**: コンテナ入れ替えのみ → **自動化して高速デプロイ**が望ましい

#### 3. デプロイ方式の違い

- **Terraform**: 宣言的（差分適用）
- **ECS Blue/Green**: 新しいタスクセットを作成し、段階的にトラフィックを移行

Terraform で ECS サービスを更新すると `lifecycle.ignore_changes` を設定していても意図しない動作が起きる可能性がある。

#### 4. ロールバックの仕組み

- **アプリ**: ECS Blue/Green で即座にロールバック可能（旧タスクセットに戻すだけ）
- **インフラ**: Terraform state を操作する必要があり、複雑

### 構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub リポジトリ                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  environments/    modules/         app1/         app2/         │
│  (Terraform)      (Terraform)      (アプリコード)  (アプリコード) │
│       │               │                │              │        │
│       └───────┬───────┘                └──────┬───────┘        │
│               │                               │                 │
│               ▼                               ▼                 │
│     ┌─────────────────┐             ┌─────────────────┐        │
│     │ GitHub Actions  │             │ AWS CodePipeline│        │
│     │ (terraform plan)│             │ + CodeBuild     │        │
│     └────────┬────────┘             └────────┬────────┘        │
│              │                               │                  │
│              ▼                               ▼                  │
│     ┌─────────────────┐             ┌─────────────────┐        │
│     │ 手動 Apply      │             │ ECS Blue/Green  │        │
│     │ (ローカル実行)   │             │ 自動デプロイ    │        │
│     └─────────────────┘             └─────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 比較表

| 観点 | インフラCI/CD | アプリCI/CD |
|-----|-------------|------------|
| 速度 | 慎重（承認必要） | 高速（自動） |
| リスク | 高（破壊的変更あり） | 低（コンテナ入替のみ） |
| ロールバック | 複雑 | 簡単（Blue/Green） |
| 頻度 | 低 | 高 |
| ツール | GitHub Actions + Terraform | CodePipeline + CodeBuild |

このように**責務を分離**することで、安全性と開発スピードの両立を実現している。

---

## 2. 認証方式: OIDC (OpenID Connect)

### 2.1 仕組み

従来の方式（IAM ユーザーのアクセスキー）ではなく、**OIDC による一時認証**を採用している。

```
┌─────────────────┐     ①トークン要求     ┌─────────────────┐
│  GitHub Actions │ ───────────────────► │ GitHub OIDC     │
│  (ワークフロー)  │                       │ プロバイダー      │
└────────┬────────┘ ◄────────────────────┘                 │
         │              ②IDトークン発行                     │
         │                                                  │
         │ ③AssumeRoleWithWebIdentity                       │
         ▼                                                  │
┌─────────────────┐                                         │
│   AWS IAM       │ ◄── 信頼関係で検証 ────────────────────┘
│  (OIDCプロバイダー)│
└────────┬────────┘
         │ ④一時クレデンシャル発行
         ▼
┌─────────────────┐
│  AWS リソース    │
│  (S3, DynamoDB等)│
└─────────────────┘
```

### 2.2 メリット

- **セキュリティ向上**: 長期的なアクセスキーが不要
- **認証情報の自動ローテーション**: 一時認証情報は自動的に期限切れ
- **最小権限の原則**: 特定のブランチからのみ認証を許可

### 2.3 IAM ロールの Trust Policy

各環境のIAMロールは、特定のブランチからのアクセスのみを許可する。

```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:your-github-user/aws-ecs-portfolio:ref:refs/heads/develop"
    }
  }
}
```

- `develop` ブランチ → `github-actions-ecs-web-app-dev` ロール
- `staging` ブランチ → `github-actions-ecs-web-app-stg` ロール
- `production` ブランチ → `github-actions-ecs-web-app-prd` ロール

---

## 3. ワークフロー詳細

### 3.1 Dev環境 (`terraform-dev.yml`)

#### トリガー条件

```yaml
on:
  push:
    branches:
      - develop
    paths:
      - 'environments/dev/**'
      - 'modules/**'
      - '.github/workflows/terraform-dev.yml'
  workflow_dispatch:  # 手動実行も可能
```

- `develop` ブランチへのプッシュで自動実行
- 変更があった場合のみ（パスフィルタ）
- 手動実行も可能（Actions 画面から "Run workflow"）

#### 実行ステップ

1. **Checkout**: ソースコード取得
2. **Configure AWS Credentials**: OIDC で AWS 認証
3. **Setup Terraform**: Terraform CLI インストール
4. **Terraform Format Check**: コードフォーマット確認（エラーでも続行）
5. **Terraform Init**: プロバイダー・モジュール初期化
6. **Terraform Validate**: 構文検証
7. **Terraform Plan**: 変更内容のプレビュー（`tfplan` ファイル出力）

#### Apply について

**Apply は自動実行しない**。セキュリティと安全性のため、Apply はローカル環境から手動で実行する運用とする。

```bash
# ローカルでの Apply 実行
cd environments/dev
terraform apply
```

---

### 3.2 Staging環境 (`terraform-stg.yml`)

Dev環境と同様の構成。`staging` ブランチへのプッシュで自動実行される。

---

### 3.3 Production環境 (`terraform-prd.yml`)

#### トリガー条件

```yaml
on:
  workflow_dispatch:
    inputs:
      action:
        description: '実行するアクション'
        type: choice
        options:
          - plan
          - apply
      confirm_apply:
        description: '本番適用を確認しましたか？ (applyの場合は "yes" を入力)'
        type: string
```

- **手動発火のみ**: プッシュによる自動実行はなし
- **選択式アクション**: `plan` または `apply` を選択
- **承認キーワード必須**: Apply 実行時は `yes` の入力が必要

#### 実行フロー

```
手動発火
    ↓
┌─ action: plan ─┐       ┌─ action: apply ─┐
│                │       │                  │
│ Plan 実行      │       │ confirm = "yes"? │
│       ↓        │       │   YES → Apply    │
│ 結果表示       │       │   NO  → スキップ │
└────────────────┘       └──────────────────┘
```

---

## 4. 同時実行制御 (Concurrency)

### 4.1 設定内容

各ワークフローに `concurrency` 設定を追加し、同一環境への同時実行を防止している。

```yaml
concurrency:
  group: terraform-dev    # 環境ごとにグループ化
  cancel-in-progress: false  # 後続ジョブは待機
```

### 4.2 動作

| 状況 | 動作 |
|------|------|
| ジョブA 実行中にユーザーB がプッシュ | ジョブB は**待機**（ジョブA 完了まで） |
| ジョブA 完了 | ジョブB が開始 |

### 4.3 なぜ必要か

Terraform は DynamoDB を使用して State Lock を管理している。複数のワークフローが同時に実行されると、ロック競合が発生し、以下のエラーとなる。

```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Path:      ecs-web-app-tfstate-123456789012/dev/terraform.tfstate
```

`concurrency` 設定により、このような競合を事前に防止する。

---

## 5. 必要な GitHub Secrets

リポジトリの **Settings** → **Secrets and variables** → **Actions** で設定する。

| シークレット名 | 説明 | 必須 |
|--------------|------|------|
| `AWS_ROLE_ARN_DEV` | dev環境用 IAM ロール ARN | ✅ |
| `AWS_ROLE_ARN_STG` | stg環境用 IAM ロール ARN | ✅ |
| `AWS_ROLE_ARN_PRD` | prd環境用 IAM ロール ARN | ✅ |
| `DB_PASSWORD_APP1_DEV` | App1 DB パスワード（dev） | ❌ (Secrets Manager使用時は空可) |
| `DB_PASSWORD_APP2_DEV` | App2 DB パスワード（dev） | ❌ |
| `DB_PASSWORD_APP1_STG` | App1 DB パスワード（stg） | ❌ |
| `DB_PASSWORD_APP2_STG` | App2 DB パスワード（stg） | ❌ |

> [!NOTE]
> DB パスワードは RDS モジュールが Secrets Manager で自動生成するため、GitHub Secrets での設定は任意。空文字でも plan は成功する。

---

## 6. トラブルシューティング

### 6.1 OIDC 認証エラー

**症状**:
```
Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**原因**: IAM ロールの Trust Policy と実際のリポジトリ名が一致していない

**対処法**:
1. `bootstrap/main.tf` の `github_repository` 変数を確認
2. 正しいリポジトリ名に修正
3. `terraform apply` で IAM ロールを更新

---

### 6.2 State Lock エラー

**症状**:
```
Error: Error acquiring the state lock
```

**原因**: 前回の実行が異常終了し、DynamoDB にロックが残存

**対処法**:

```bash
# Terraform コマンドで解除
terraform force-unlock <LOCK_ID>

# または AWS CLI で直接削除
aws dynamodb delete-item \
  --table-name ecs-web-app-tfstate-lock \
  --key '{"LockID": {"S": "ecs-web-app-tfstate-123456789012/dev/terraform.tfstate"}}' \
  --region ap-northeast-1
```

---

### 6.3 変数未定義エラー

**症状**:
```
Error: Value for undeclared variable
A variable named "db_password_app1" was assigned on the command line...
```

**原因**: 環境の `variables.tf` に変数定義がない

**対処法**: 該当環境の `variables.tf` に変数を追加

```hcl
variable "db_password_app1" {
  description = "App1のDBパスワード"
  type        = string
  sensitive   = true
  default     = ""
}
```

---

### 6.4 Format Check エラー

**症状**: "Terraform Format Check" ステップで失敗

**原因**: コードのインデントやフォーマットが Terraform 標準に準拠していない

**対処法**:
```bash
# ローカルでフォーマットを適用
terraform fmt -recursive

# 変更をコミット・プッシュ
git add .
git commit -m "style: terraform fmt"
git push
```

---

## 7. ワークフローの手動実行方法

### 7.1 Actions 画面からの実行

1. GitHub リポジトリの **Actions** タブを開く
2. 左側のワークフロー一覧から対象を選択
3. **Run workflow** ボタンをクリック
4. ブランチを選択（通常はデフォルトのまま）
5. **Run workflow** で実行開始

### 7.2 Production 環境の Apply

1. Actions タブから **Terraform Production** を選択
2. **Run workflow** をクリック
3. `action` で **apply** を選択
4. `confirm_apply` に **yes** を入力
5. **Run workflow** で実行

> [!WARNING]
> Production への Apply は慎重に実行すること。事前に Plan 結果を十分に確認する。

---

## 8. ワークフローファイル構成

```
.github/workflows/
├── terraform-dev.yml     # dev環境: develop ブランチ push で自動実行
├── terraform-stg.yml     # stg環境: staging ブランチ push で自動実行
├── terraform-prd.yml     # prd環境: 手動発火のみ（Apply は承認必須）
├── deploy-app1-dev.yml   # App1 デプロイ（参考用）
└── deploy-app2-dev.yml   # App2 デプロイ（参考用）
```

---

## 9. 運用ルール

### 9.1 ブランチ戦略

| ブランチ | 対象環境 | ワークフロー動作 |
|---------|---------|-----------------|
| `develop` | dev | push で自動 plan |
| `staging` | stg | push で自動 plan |
| `production` | prd | 手動発火のみ |

### 9.2 デプロイフロー

```
develop で開発・テスト
    ↓ (マージ)
staging で検証
    ↓ (マージ)
production で本番リリース（手動 Apply）
```

### 9.3 Apply の実行ポリシー

- **dev/stg**: ローカルから手動で `terraform apply` を実行
- **prd**: GitHub Actions の手動発火で承認付き Apply、またはローカルから実行

### 9.4 現状の承認フロー

現状の設計では、**プルリクエストのレビュー・マージは必須ではない**。以下が「承認」にあたる。

| 環境 | 承認の仕組み |
|------|------------|
| **dev/stg** | push で自動 `plan` → **Plan 結果を目視確認してから手動 Apply** |
| **prd** | **手動発火のみ** + Apply には `"yes"` 入力が必要（二重チェック） |

### 9.5 プルリクエスト（PR）ベースの運用（推奨拡張）

チーム開発や本番環境への厳格な管理が必要な場合は、以下の設定を追加することを推奨する。

#### GitHub ブランチ保護ルールの設定

リポジトリの **Settings** → **Branches** → **Add branch protection rule** で設定。

| 設定項目 | 推奨値 | 効果 |
|---------|-------|------|
| `Require a pull request before merging` | ✅ ON | 直接 push を禁止し、PR 必須に |
| `Require approvals` | ✅ ON (1人以上) | レビューなしでマージ不可 |
| `Require status checks to pass` | ✅ ON | Plan が成功しないとマージ不可 |
| `Require branches to be up to date` | ✅ ON | 最新の状態でないとマージ不可 |

#### 設定例

```
Branch name pattern: develop
├── ✅ Require a pull request before merging
│   └── ✅ Require approvals: 1
├── ✅ Require status checks to pass before merging
│   └── Status checks: "Terraform Plan (Dev)"
└── ✅ Require branches to be up to date before merging
```

#### 運用フロー（PR 必須の場合）

```
feature ブランチで作業
    ↓
develop への PR 作成
    ↓
GitHub Actions が自動で Plan 実行
    ↓
レビュアーが Plan 結果を確認
    ↓
Approve → マージ
    ↓
ローカルから terraform apply
```

### 9.6 運用スタイルの選択

| 運用スタイル | 向いているケース | メリット | デメリット |
|-------------|----------------|---------|-----------|
| **現状（直接 push）** | 個人開発、小規模チーム | シンプル、高速 | レビューなしでミス発生リスク |
| **PR 必須 + レビュー** | チーム開発、本番環境 | 変更履歴が明確、ミス防止 | マージまでの時間増加 |

---


## 10. 参考リンク

- [GitHub Actions ドキュメント](https://docs.github.com/ja/actions)
- [AWS OIDC 認証](https://docs.github.com/ja/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform Backend (S3 + DynamoDB)](https://developer.hashicorp.com/terraform/language/settings/backends/s3)

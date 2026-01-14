# Terraform コマンドリファレンス

本プロジェクトの開発・運用で使用する主要な Terraform コマンドおよび、一般的に多用されるコマンドの解説。

---

## 目次

1. [基本操作コマンド](#1-基本操作コマンド)
2. [リソース操作・詳細確認](#2-リソース操作詳細確認)
3. [ステート（状態）管理](#3-ステート状態管理)
4. [トラブルシューティング・高度な操作](#4-トラブルシューティング高度な操作)
5. [本プロジェクト独自の運用コマンド](#5-本プロジェクト独自の運用コマンド)

---

## 1. 基本操作コマンド

日常的な開発サイクルで使用する最も基本的なコマンド。

| コマンド | 説明 | 主なオプション |
|:---|:---|:---|
| `terraform init` | 実行環境の初期化。プロバイダーのダウンロードやバックエンド（S3等）の設定を行う。 | `-reconfigure`: 設定変更時に強制再初期化<br>`-upgrade`: プロバイダーを最新に更新 |
| `terraform validate` | 設定ファイルの構文チェックを行い、論理的な整合性を検証する。 | - |
| `terraform fmt` | コードのインデントや整形を Terraform 標準のスタイルに自動修正する。 | `-recursive`: サブディレクトリも含めて整形 |
| `terraform plan` | 変更内容のプレビューを表示する。実際のリソース操作は行わない。 | `-out=FILE`: 実行計画を保存<br>`-var-file=FILE`: 変数ファイルを指定 |
| `terraform apply` | 設定を実際のインフラに適用する。 | `-auto-approve`: 確認プロンプトをスキップ<br>`-replace=ADDR`: 特定リソースを強制再作成 |
| `terraform destroy` | 管理下にあるすべてのリソースを削除する。 | `-target=ADDR`: 特定リソースのみ削除 |

---

## 2. リソース操作・詳細確認

特定のリソースに絞った操作や、現在の構成を確認するためのコマンド。

| コマンド | 説明 | 使用例 |
|:---|:---|:---|
| `terraform state list` | 現在のステート（tfstateファイル）に記録されているリソース一覧を表示。 | `terraform state list` |
| `terraform state show` | 指定したリソースの現在の属性値（IPアドレス、ARN等）を詳細表示。 | `terraform state show module.vpc.aws_vpc.main` |
| `terraform output` | `outputs.tf` で定義された出力値を表示。 | `terraform output alb_dns_name` |
| `terraform graph` | リソース間の依存関係を可視化（DOT形式）。通常は外部ツールへパイプして画像化する。 | `terraform graph | dot -Tpng > graph.png` |

---

## 3. ステート（状態）管理

ステートファイルの整合性を修正したり、既存リソースを管理下に入れるためのコマンド。

| コマンド | 説明 | 使用例 |
|:---|:---|:---|
| `terraform import` | Terraform管理外の既存リソースをステートに取り込む。 | `terraform import module.s3.aws_s3_bucket.main my-bucket-name` |
| `terraform state rm` | リソースを物理削除せず、Terraformの管理対象（ステート）からのみ除外。 | `terraform state rm module.vpc.aws_vpc.old` |
| `terraform state mv` | リソースのアドレスを変更（名称変更やモジュール移動時）。 | `terraform state mv module.A module.B` |
| `terraform force-unlock` | 他のプロセスや異常終了によってロックされたステートを強制解除する。 | `terraform force-unlock <LOCK_ID>` |

---

## 4. トラブルシューティング・高度な操作

デバッグや特定の不具合対応で使用するコマンド。

| コマンド | 説明 | 備考 |
|:---|:---|:---|
| `terraform console` | 対話型のREPL環境。変数の値や関数の動作をテストできる。 | 変数、組み込み関数の検証に便利 |
| `terraform taint` | 特定のリソースに「破損」マークを付け、次回の `apply` で強制的に再作成させる。 | **非推奨**: 現在は `apply -replace` の使用が推奨 |
| `terraform refresh` | 実際のインフラ状態とステートファイルの同期（差分のみ更新）。 | 通常 `plan` 時に自動で行われる |

---

## 5. 本プロジェクト独自の運用コマンド

本プロジェクトの `release_guide.md` 等で使用されている、段階的デプロイメントのための手法。

### ターゲット指定デプロイ (`-target`)
リソース間の依存関係が複雑な場合や、特定のモジュールのみを先に作成したい場合に使用。

```bash
# ECRリポジトリのみを優先して作成
terraform apply -target=module.ecr_app1 -target=module.ecr_app2
```

### 強制再作成 (`-replace`)
ECSのタスク定義やターゲットグループの設定変更が、Terraform側で「変更」ではなく「再作成」が必要な際、明示的に指定する場合に使用。

```bash
# ターゲットグループを強制的に作り直す
terraform apply -replace="module.alb.aws_lb_target_group.app1"
```

### ステートロックの強制解除 (Backend S3 + DynamoDB用)
GitHub Actions が異常終了し、DynamoDB にロックが残った場合に実行。

```bash
# ロックIDを確認して手動解除
aws dynamodb delete-item \
  --table-name ecs-web-app-tfstate-lock \
  --key '{"LockID": {"S": "<tfstate_path>"}}' \
  --region ap-northeast-1
```

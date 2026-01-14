# アプリケーション開発ガイド

本ドキュメントでは、本インフラストラクチャ上で動作するアプリケーションの開発フロー、ディレクトリ構成、およびデプロイ手順について解説する。

---

## 目次

1. [ディレクトリ構成](#1-ディレクトリ構成)
2. [開発からデプロイまでの流れ](#2-開発からデプロイまでの流れ)
3. [Dockerfile の記述について](#3-dockerfile-の記述について)
4. [buildspec.yml について](#4-buildspecyml-について)
5. [データベース接続について](#5-データベース接続について)

---

## 1. ディレクトリ構成

本リポジトリは「モノレポ（Monorepo）」構成を採用しており、インフラコード（Terraform）とアプリケーションコードを同一リポジトリで管理している。

### 構成概要

```
.
├── app1/                  # アプリケーション1 (サービスA) のソースコード
│   ├── Dockerfile         # コンテナ定義
│   ├── buildspec.yml      # ビルド・デプロイ手順書
│   ├── src/               # ソースコード (例)
│   └── ...
├── app2/                  # アプリケーション2 (サービスB) のソースコード
│   ├── Dockerfile
│   ├── buildspec.yml
│   └── ...
├── environments/          # インフラ定義 (環境ごと)
├── modules/               # インフラ部品 (Terraformモジュール)
└── docs/                  # ドキュメント
```

**開発ルール**:
- `app1` の機能開発は `app1/` ディレクトリ内で行う。
- `app2` の機能開発は `app2/` ディレクトリ内で行う。
- アプリケーション固有の `Dockerfile` や設定ファイルも各ディレクトリ内に配置する。

---

## 2. 開発からデプロイまでの流れ

### Step 1: ローカル開発

1. **コードの編集**:
   各アプリケーションディレクトリ（`app1` 等）内でコードを編集する。

2. **Dockerでの動作確認 (推奨)**:
   ローカルでコンテナをビルド・起動し、動作を確認する。

   ```bash
   cd app1
   
   # ビルド
   docker build -t app1-local .
   
   # 起動 (ポート8080で確認する場合)
   docker run -p 8080:80 app1-local
   ```

### Step 2: 変更のコミットとプッシュ

動作確認完了後、変更をGitにコミットしてプッシュする。

```bash
# app1 の変更のみをコミットする例
git add app1/
git commit -m "feat(app1): 新機能を追加"
git push origin develop
```

### Step 3: 自動ビルド・デプロイ

### Step 3: 自動ビルド・デプロイ

`develop` ブランチへのプッシュ（またはプルリクエストのマージ）をトリガーに、AWS CodePipeline が自動デプロイを行う。

1. **AWS CodePipeline**: GitHubリポジトリへのプッシュを検知してパイプラインを起動。
   - **Source**: CodeStar Connections経由で最新のソースコードを取得。
   - **Build**: `CodeBuild` が `Dockerfile` を基にイメージをビルドし、ECRへプッシュ。その後 `aws ecs update-service` を実行。
   - **Deploy**: ECSがBlue/Greenデプロイメントを開始。
     - 新しいタスク（Green）を起動
     - テストポートでヘルスチェック
     - 本番トラフィックを切り替え

---

## 3. Dockerfile の記述について

各アプリケーションディレクトリ直下の `Dockerfile` で、アプリケーションの実行環境を定義する。

### 基本的な構成例 (Python Flask)

```dockerfile
# ベースイメージ
FROM python:3.9-slim

# 作業ディレクトリ
WORKDIR /app

# 依存ライブラリのインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ソースコードのコピー
COPY . .

# ポートの公開 (Terraformで設定したコンテナポートと合わせる)
EXPOSE 80

# 起動コマンド
CMD ["python", "app.py"]
```

### 注意点

- **プラットフォーム**: 本番環境（Fargate）は `linux/amd64` で動作する。M1/M2 Macで開発する場合は、ビルド時に `--platform linux/amd64` を指定するか、CodeBuildでビルドすることで互換性の問題を回避できる。
- **環境変数**: DB接続情報などの環境変数は、Terraform側 (`modules/ecs_service`) で定義され、コンテナ起動時に注入される。Dockerfile内にハードコードしないこと。

---

## 4. `buildspec.yml` について

各ディレクトリに含まれる `buildspec.yml` は、AWS CodeBuild がビルドを行うための手順書である。
**基本的には編集不要**だが、特殊なビルド手順（npm install や テスト実行など）を追加したい場合はここを編集する。

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "ECRログイン..."
      # ...
  build:
    commands:
      - echo "Dockerビルド..."
      - docker build --platform linux/amd64 -t $REPOSITORY_URI:latest .
      # ここにユニットテストなどを追加可能
  post_build:
    commands:
      - echo "Dockerプッシュ..."
      - docker push $REPOSITORY_URI:latest
      - echo "デプロイ開始..."
      - aws ecs update-service ...
```

---

## 5. データベース接続について

アプリケーションからデータベース（RDS）へ接続する際は、環境変数を使用する。

### 利用可能な環境変数

Terraform (`modules/ecs_service/main.tf`) で以下の環境変数が自動的にコンテナに渡される。

| 環境変数名 | 説明 | 例 |
|------------|------|----|
| `DB_HOST` | RDSのエンドポイント | `ecs-web-app-dev-app1.xxxx.ap-northeast-1.rds.amazonaws.com` |
| `DB_NAME` | データベース名 | `app1` |
| `ENVIRONMENT` | 環境名 | `dev` |

### DBパスワードの取得

DBパスワードはセキュリティのため環境変数には渡されない。
AWS Secrets Manager から取得する必要がある。

**Python (boto3) での取得例**:

```python
import boto3
import json
import os

def get_db_password():
    secret_name = f"ecs-web-app-{os.environ['ENVIRONMENT']}-app1-password"
    region_name = "ap-northeast-1"

    # Secrets Manager クライアント
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except Exception as e:
        raise e

    # シークレット文字列をパース
    secret = json.loads(get_secret_value_response['SecretString'])
    return secret['password']
```

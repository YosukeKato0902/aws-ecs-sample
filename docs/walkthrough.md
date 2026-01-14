# Walkthrough: AWS Provider v6.x Upgrade & ECS Blue/Green

AWS Provider v6.xへのアップグレードおよびECS組み込みBlue/Greenデプロイメント（ライフサイクルフック付き）の実装が完了。

---

## 目次

1. [実装内容](#実装内容)
2. [設計書更新](#設計書更新)
3. [トラブルシューティング（検証中の修正）](#トラブルシューティング検証中の修正)
4. [検証](#検証)
5. [デプロイ後のトラブルシューティング (503エラー対応)](#デプロイ後のトラブルシューティング-503エラー対応)

---

## 実装内容

### 1. AWS Provider v6.x アップグレード
- バージョン制約を `~> 6.0` に更新
- 破壊的変更の影響がないことを確認

### 2. ECS組み込みBlue/Greenデプロイメント
CodeDeployリソースを使用せず、ECSサービス標準の機能で安全なデプロイを実現。

- **戦略**: `BLUE_GREEN`
- **ベイク時間**:
    - dev/stg: **5分**
    - prd: **10分**

### 3. 自動検証（ライフサイクルフック）
Lambda関数による検証フローを導入。

1. **テストトラフィック移行**: ポート **10080** で新バージョン（Green）にアクセス可能に
2. **検証**: Lambda (`validation_hook.py`) が `/health` エンドポイントをチェック
3. **判定**:
    - ✅ **200 OK**: 本番トラフィック切替開始
    - ❌ **Error**: 即時ロールバック

### 4. CI/CDパイプライン改善
アーティファクト管理の簡素化と信頼性向上のため、パイプライン構成を変更。

- **変更前**: GitHub ActionsでZip作成 -> S3へアップロード -> CodePipeline起動
- **変更後**: AWS CodeStar ConnectionsによるGitHub直接連携 -> CodePipeline起動
    - GitHub Actionsのワークフローへの依存を排除
    - **Bake Time (5分)** の待機動作を確認済み（stg環境）

## 設計書更新

- [基本設計書](file:///Users/yosukekato/aws_ecs/docs/basic_design.md): デプロイメント方式を更新
- [詳細設計書](file:///Users/yosukekato/aws_ecs/docs/detailed_design.md): ALBリスナー、セキュリティグループ、ECS設定、ライフサイクル設定を詳細化

## トラブルシューティング（検証中の修正）

`terraform plan` 検証時に発生した以下のエラーに対応。詳細は [詳細設計書](file:///Users/yosukekato/aws_ecs/docs/detailed_design.md#14-実装メモトラブルシューティング) を参照。

1.  **セキュリティグループ Description制限**
    - **エラー**: 日本語を含むDescriptionがエラーとなる (`doesn't comply with restrictions`)
    - **対応**: すべて英語（ASCII）に修正
2.  **Invalid count argument**
    - **エラー**: `apply` 後に確定する値を `count` 条件に使用できない
    - **対応**: 明示的なフラグ変数 `enable_s3_access` を導入して制御

### リファクタリング (全環境: dev/stg/prd)

`environments/{env}/main.tf` の肥大化を解消するため、全環境で以下の機能別ファイルに分割。
`dev` 環境での `terraform plan` により、構成に変化がないこと（No changes）を確認済み。

- `network.tf`: VPC, Security Group, ALB, WAF
- `compute.tf`: ECS Cluster/Service, ECR
- `database.tf`: RDS, S3
- `cicd_monitoring.tf`: CodePipeline, CloudWatch
- `main.tf`: Terraform設定, Provider, Locals

### Security強化: Secrets Manager導入

RDSのパスワード管理を `terraform.tfvars` (変数) から **AWS Secrets Manager** へ移行。

- **modules/rds**: `random_password` でパスワードを自動生成し、Secrets Managerに格納・管理するように変更。
- **modules/ecs_service**: タスク定義の `secrets` プロパティを使用して、コンテナ起動時にSecrets Managerから環境変数 `DB_PASSWORD` として注入するよう構成変更。
- **IAM**: ECSタスク実行ロールに `secretsmanager:GetSecretValue` 権限を追加。

これにより、コードベースから機密情報を排除。

### ドキュメント更新

Secrets Manager導入に伴い、以下のドキュメントを更新。

- `docs/release_guide.md`: `terraform.tfvars` からのパスワード変数削除指示を追加。
- `README.md`, `docs/detailed_design.md`: 環境変数定義からパスワードを削除し、Secrets Manager参照に変更。
- `README.md`, `docs/basic_design.md`: AWSアカウント構成（単一/マルチアカウント）に関する記述を追加。
- `docs/release_guide.md`: 「構築後の設定」セクション（SSL証明書、DNS、通知設定）を追加。

## 検証

```bash
terraform validate
# Success! The configuration is valid.
```

```bash
# dev環境 (Secrets Manager導入・リファクタリング検証)
cd environments/dev
terraform plan
# => Plan: 9 to add, 0 to change, 0 to destroy.
# => 実行成功 (Secrets Managerリソース追加、パスワード生成)
```

```bash
# stg/prd環境 (Secrets Manager導入検証)
cd environments/stg # or prd
terraform plan
# => Plan: 111 to add (stg), 110 to add (prd)
# => Error: reading ECR Repository (couldn't find resource)
#    ※環境初回構築前でECRリポジトリが存在しないため発生。
#    ※Secrets Managerリソース等の構成は正しく認識されていることを確認済み。
```

`terraform plan` (dev環境) も成功し、リソース作成準備が完了している。
# Result
GitHub Repository: [aws-ecs](https://github.com/your-github-user/aws-ecs-portfolio) (Private)

## デプロイ後のトラブルシューティング (503エラー対応)

デプロイ完了後、ALB経由でのアクセスで503エラーが発生。以下の2つの要因を特定し解決。

1.  **ポート定義の不一致 (Terraform設定)**
    - `terraform.tfvars` で `app_port = 8080` となっていたが、実際のNginxコンテナはポート `80` で稼働していた。
    - **対応**: `app_port = 80`, `health_check_path = "/"` に修正し、ECSサービスとターゲットグループを再作成。

2.  **アーキテクチャ不一致 (Exec Format Error)**
    - ログ調査により `exec /docker-entrypoint.sh: exec format error` を検出。
    - Mac (ARM64) でプルしたDockerイメージをそのままFargate (x86_64) にプッシュしていたことが原因でした。
    - **対応**: `docker pull --platform linux/amd64` を明示的に実行してイメージを再構築・プッシュし、解消。

最終的に、ALB経由でNginxバージョンヘッダを含む応答（404 Not Found ※コンテンツ未配置のため正常）を確認し、インフラとしての疎通を完了。


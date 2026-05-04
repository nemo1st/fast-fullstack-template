# Lambda + S3 + CloudFront テンプレート

安価に運用できる Web アプリ雛形。GitHub の `Use this template` で複製してすぐに動かせる。

## 構成

| レイヤ | 技術 | 役割 |
| :-- | :-- | :-- |
| CDN / 静的配信 | CloudFront + S3 | 静的フロント配信、`/api/*` を Lambda Function URL へリバプロ |
| API | AWS Lambda (Container, Python 3.12 + FastAPI + Mangum) | API |
| デプロイ | GitHub Actions OIDC + SAM | `main` push で自動デプロイ |

## 使い方

### 1. リポジトリを作成

GitHub の `Use this template` でリポジトリを作成し、ローカルに clone する。

### 2. プロジェクト名を設定

[infra/bootstrap.sh](infra/bootstrap.sh) 冒頭の以下を編集する（または環境変数で渡す）:

```bash
PROJECT_NAME="${PROJECT_NAME:-myapp}"
GITHUB_REPO="${GITHUB_REPO:-yourname/myapp}"
REGION="${REGION:-ap-northeast-1}"
```

### 3. AWS / GitHub をセットアップ

事前に AWS CLI と gh CLI を認証しておく:

```bash
brew install awscli gh
aws configure
gh auth login
```

その上で:

```bash
./infra/bootstrap.sh
```

これで以下が一括で作成される:

- GitHub OIDC Identity Provider
- IAM Role + 最小権限ポリシー
- ECR リポジトリ + ライフサイクル（最新2世代保持）
- GitHub Variables: `AWS_ROLE_ARN` / `PROJECT_NAME` / `AWS_REGION`

何度実行しても安全（idempotent）。

### 4. デプロイ

`main` に push、または GitHub Actions の `Deploy Lambda + Static Frontend` を手動実行。

### 5. 動作確認

```bash
DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}" \
  --region "${REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' \
  --output text)

curl "https://${DOMAIN}/api/health"
# {"status":"ok"}
```

ブラウザで `https://${DOMAIN}/` を開くと Hello ページが表示され、`/api/health` の結果がインラインで描画される。

## カスタムドメイン（任意）

CloudFront にカスタムドメインを紐付ける場合は、SAM の Parameter `CustomDomain` と `AcmCertificateArn`（**us-east-1** リージョンの ACM 証明書 ARN）を指定する。未指定の場合は CloudFront 既定ドメイン（`*.cloudfront.net`）でそのまま動く。

## ディレクトリ構成

```
api/                Lambda 用 FastAPI
  app/              FastAPI エントリポイント
  Dockerfile.lambda Lambda コンテナイメージ定義
frontend/           静的フロント (S3 配信)
infra/              SAM テンプレート + bootstrap スクリプト
.github/workflows/  GitHub Actions
```

## ローカル開発

API:

```bash
cd api/app
pip install -r requirements.txt
python main.py
# http://localhost:5000/api/health
```

フロント:

```bash
python3 -m http.server --directory frontend 8000
# http://localhost:8000/
```

## コスト目安

- Lambda: コールドスタート回避のため EventBridge で5分おきに warm-up 実行
- ECR: ライフサイクルで最新2世代のみ保持
- CloudFront: PriceClass_200（北米/欧州/アジア）
- S3: 静的アセットのみ

カスタムドメインを使わない場合、月数百円程度で運用可能。

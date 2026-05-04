# インフラ (Lambda + S3 + CloudFront)

CloudFormation スタック名・各リソース名は `PROJECT_NAME` を起点に決定される。

## 構成

| リソース | 名前 | 用途 |
| --- | --- | --- |
| ECR リポジトリ | `${PROJECT_NAME}` | Lambda コンテナイメージ (最新 2 世代保持) |
| Lambda 関数 | `${PROJECT_NAME}` | FastAPI を Mangum でラップして実行 |
| Lambda Function URL | (自動採番) | HTTP エンドポイント (AuthType: NONE) |
| EventBridge ルール | `${PROJECT_NAME}-warmup` | 5 分おきに warm-up |
| S3 バケット | `${PROJECT_NAME}-static-${AccountId}` | 静的フロント |
| CloudFront ディストリビューション | (自動採番) | `/api/*` → Lambda、それ以外 → S3 |
| CloudFormation スタック | `${PROJECT_NAME}` | 上記一式を管理 |

## 初回セットアップ

事前に **AWS CLI** と **gh CLI** をインストール & 認証:

```bash
brew install awscli gh
aws configure
gh auth login
```

[bootstrap.sh](bootstrap.sh) 冒頭の `PROJECT_NAME` / `GITHUB_REPO` / `REGION` を編集してから:

```bash
./infra/bootstrap.sh
```

これが自動で実行される:

| ステップ | 内容 |
| --- | --- |
| 1 | GitHub OIDC Identity Provider 作成 (既存ならスキップ) |
| 2 | IAM Role `${PROJECT_NAME}-github-actions` + 最小権限ポリシー |
| 3 | ECR リポジトリ + ライフサイクル |
| 4 | GitHub Variables: `AWS_ROLE_ARN` / `PROJECT_NAME` / `AWS_REGION` |

何度実行しても安全 (idempotent)。

## ローカルからのデプロイ

GitHub Actions と同等の処理を手元で実行する場合:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
SHA=$(git rev-parse --short HEAD)
IMAGE_URI="${ECR_REGISTRY}/${PROJECT_NAME}:${SHA}"

# 1. ECR ログイン
aws ecr get-login-password --region "${REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# 2. Lambda 用イメージ build & push
docker buildx build --platform linux/amd64 \
  --provenance=false --sbom=false \
  -f api/Dockerfile.lambda \
  -t "${IMAGE_URI}" \
  --push .

# 3. SAM デプロイ
sam deploy \
  --template-file infra/template.yaml \
  --config-file infra/samconfig.toml \
  --stack-name "${PROJECT_NAME}" \
  --image-repository "${ECR_REGISTRY}/${PROJECT_NAME}" \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    ImageUri="${IMAGE_URI}"

# 4. 静的アセット
BUCKET=$(aws cloudformation describe-stacks --stack-name "${PROJECT_NAME}" --region "${REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`StaticBucketName`].OutputValue' --output text)
aws s3 sync frontend/ "s3://${BUCKET}/" --delete
```

## カスタムドメイン

CloudFront にカスタムドメインを紐付ける場合、`sam deploy` 時に追加で渡す:

```bash
sam deploy ... \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    ImageUri="${IMAGE_URI}" \
    CustomDomain=app.example.com \
    AcmCertificateArn=arn:aws:acm:us-east-1:...:certificate/...
```

ACM 証明書は **us-east-1** リージョンに必要 (CloudFront の制約)。

## 動作確認

```bash
DOMAIN=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}" \
  --region "${REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' \
  --output text)

curl "https://${DOMAIN}/api/health"
```

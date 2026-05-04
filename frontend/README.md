# frontend - 静的サイト

S3 + CloudFront で配信される静的フロントエンド。

## 構成

| パス | 内容 |
| --- | --- |
| `index.html` | トップページ (`/api/health` を呼び出す Hello ページ) |
| `404.html` | 404 ページ |
| `manifest.json` | PWA マニフェスト |
| `robots.txt` | クローラ向け |

## ローカル開発

```bash
python3 -m http.server --directory frontend 8000
```

→ `http://localhost:8000/`

API は別途 `cd api/app && python main.py` で起動し、フロント側からは `/api/*` を直接叩く想定。CORS / プロキシは利用環境に応じて設定する。

## デプロイ

GitHub Actions (`.github/workflows/deploy-lambda.yml`) が `aws s3 sync frontend/ s3://...` で同期する。手元から動かす場合は [infra/README.md](../infra/README.md) を参照。

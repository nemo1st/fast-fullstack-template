"""
AWS Lambda エントリポイント。

EventBridge からの warm-up イベント (`{"warmup": true}`) はノーオペで早期応答し、
HTTP リクエストは Mangum 経由で FastAPI (`app.app`) に委譲する。
"""

from mangum import Mangum

from app import app

_asgi = Mangum(app, lifespan="off")


def handler(event, context):
    if isinstance(event, dict) and event.get("warmup"):
        return {"statusCode": 200, "body": "warm"}
    return _asgi(event, context)

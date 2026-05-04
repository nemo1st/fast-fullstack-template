"""FastAPI application entrypoint."""

from fastapi import FastAPI
from fastapi.responses import ORJSONResponse

app = FastAPI(
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)


@app.get("/api/health", response_class=ORJSONResponse)
async def health():
    return {"status": "ok"}

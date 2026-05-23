import asyncio
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from routes.anime_routes import router as anime_router
from routes.episodio_routes import router as episodio_router
from routes.servidor_routes import router as servidor_router
from routes.anime_detail_routes import router as anime_detail_router
from dashboard.routes import router as dashboard_router
from routes.auth_routes import router as auth_router
from routes.user_state_routes import router as user_state_router
from security import SQLiteRateLimiter
from db.database import DB_PATH, init_db
from db.redis_client import connect as redis_connect
from db import metrics
from utils import log_buffer, activity
from scheduler import start_scheduler

# â”€â”€ Lifespan (startup / shutdown) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@asynccontextmanager
async def lifespan(app: FastAPI):
    log_buffer.install()
    init_db()
    redis_connect()
    scheduler = start_scheduler()
    try:
        yield
    finally:
        if scheduler is not None:
            scheduler.shutdown(wait=False)


# â”€â”€ App â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

app = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None, max_request_body_size=64 * 1024)

_allowed_origins_env = os.environ.get("ALLOWED_ORIGINS", "").strip()
if _allowed_origins_env:
    _allowed_origins = [o.strip() for o in _allowed_origins_env.split(",") if o.strip()]
else:
    import warnings
    warnings.warn(
        "ALLOWED_ORIGINS is not set â€” CORS is open to all origins (*). "
        "Set ALLOWED_ORIGINS in your .env for production.",
        stacklevel=1,
    )
    _allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

_limiter = SQLiteRateLimiter(DB_PATH, default_limit=200, window=60)


# â”€â”€ Rate limit + timing middleware â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@app.middleware("http")
async def _rate_limit_and_timing(request: Request, call_next):
    t0 = time.perf_counter()

    remote_addr = (request.client.host if request.client else "unknown")
    allowed = await asyncio.to_thread(
        _limiter._check, f"global:{remote_addr}", _limiter.default_limit
    )
    if not allowed:
        return JSONResponse({"error": "Too Many Requests"}, status_code=429)

    response = await call_next(request)

    elapsed = (time.perf_counter() - t0) * 1000
    metrics.record_time(request.url.path, elapsed)
    # Skip dashboard polling from activity log to reduce noise
    path = request.url.path
    if not path.startswith("/dashboard/api/"):
        activity.record(
            method=request.method,
            path=path,
            status=response.status_code,
            elapsed_ms=elapsed,
            client_ip=remote_addr,
        )
        import logging
        req_logger = logging.getLogger("api.request")
        msg = f"{request.method} {path} HTTP {response.status_code} ({elapsed:.1f}ms) IP: {remote_addr}"
        if response.status_code >= 500:
            req_logger.error(msg)
        elif response.status_code >= 400:
            req_logger.warning(msg)
        else:
            req_logger.info(msg)
    return response


# â”€â”€ Public routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@app.get("/")
async def root():
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/dashboard", status_code=302)


@app.get("/health")
async def health():
    from db.redis_client import is_available as redis_ok
    return {"status": "ok", "service": "anime-stream-backend", "redis": redis_ok()}


@app.get("/metrics")
async def get_metrics():
    return metrics.snapshot()


# â”€â”€ Routers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

app.include_router(anime_router)
app.include_router(episodio_router)
app.include_router(servidor_router)
app.include_router(anime_detail_router)
app.include_router(dashboard_router)
app.include_router(auth_router)
app.include_router(user_state_router)


# â”€â”€ Entry point â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5050)),
        reload=False,
    )


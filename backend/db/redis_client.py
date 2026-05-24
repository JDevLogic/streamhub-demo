"""Redis connection pool for the cache layer.

Reads REDIS_URL from environment (default: redis://redis:6379/0).
Exposes a module-level `redis` object that callers can use directly.

If Redis is unreachable, `redis` is set to None. All callers must
handle None gracefully (fall through to scraping).
"""

import logging
import os

import redis as _redis

_log = logging.getLogger(__name__)

REDIS_URL: str = os.environ.get("REDIS_URL", "redis://redis:6379/0")

_pool: _redis.ConnectionPool | None = None
redis: _redis.Redis | None = None


def connect() -> None:
    """Initialise the connection pool. Call once at startup."""
    global _pool, redis
    try:
        _pool = _redis.ConnectionPool.from_url(
            REDIS_URL,
            max_connections=20,
            decode_responses=True,
            socket_connect_timeout=3,
            socket_timeout=2,
            retry_on_timeout=True,
        )
        r = _redis.Redis(connection_pool=_pool)
        r.ping()
        redis = r
        _log.info("Redis connected: %s", REDIS_URL)
    except Exception as exc:
        _log.warning("Redis unavailable (%s) -- cache disabled, scraping only", exc)
        redis = None


def is_available() -> bool:
    """Quick health check -- returns False if Redis is down."""
    if redis is None:
        return False
    try:
        redis.ping()
        return True
    except Exception:
        return False

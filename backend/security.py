"""Autenticación por API Key, rate limiting SQLite y validación básica de URLs para demo pública."""

import os
import sqlite3
import time
from urllib.parse import urlparse

from dotenv import load_dotenv
from fastapi import Header, HTTPException


load_dotenv()


# -- API Key --------------------------------------------------------------------

API_KEY: str | None = os.environ.get("API_KEY")
if not API_KEY:
    raise RuntimeError(
        "La variable de entorno API_KEY no está definida. "
        "Configura API_KEY en backend/.env o en el entorno de ejecución."
    )


async def require_api_key(x_api_key: str = Header(...)):
    """FastAPI dependency — rechaza peticiones sin API Key válida."""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")


# -- Rate Limiter ---------------------------------------------------------------

class SQLiteRateLimiter:
    """Sliding-window rate limiter backed by SQLite."""

    def __init__(self, db_path, default_limit: int = 60, window: int = 60):
        self._db_path = str(db_path)
        self.default_limit = default_limit
        self.window = window

    def _check(self, key: str, limit: int) -> bool:
        """Return True if the request is allowed, False if rate limit exceeded."""
        now = time.time()
        cutoff = now - self.window

        with sqlite3.connect(self._db_path, timeout=5) as conn:
            conn.execute("BEGIN IMMEDIATE")
            conn.execute("DELETE FROM rate_limit_log WHERE ts < ?", (cutoff,))
            (count,) = conn.execute(
                "SELECT COUNT(*) FROM rate_limit_log WHERE key = ? AND ts >= ?",
                (key, cutoff),
            ).fetchone()

            if count >= limit:
                conn.execute("ROLLBACK")
                return False

            conn.execute(
                "INSERT INTO rate_limit_log (key, ts) VALUES (?, ?)",
                (key, now),
            )
            conn.execute("COMMIT")

        return True


# -- Demo URL validation --------------------------------------------------------

DEMO_ALLOWED_DOMAINS: set[str] = {
    "commondatastorage.googleapis.com",
    "picsum.photos",
}

SCRAPER_ALLOWED_DOMAINS: set[str] = DEMO_ALLOWED_DOMAINS
RESOLVER_ALLOWED_DOMAINS: set[str] = DEMO_ALLOWED_DOMAINS
PROXY_ALLOWED_DOMAINS: set[str] = DEMO_ALLOWED_DOMAINS


def validate_url(url: str, allowed_domains: set[str]) -> str | None:
    """Valida una URL contra un conjunto de dominios permitidos.

    Returns None si es válida, o un mensaje de error si no lo es.
    """
    try:
        parsed = urlparse(url)
    except Exception:
        return "URL inválida"

    if parsed.scheme not in ("http", "https", "demo"):
        return "Solo se permiten URLs HTTP/HTTPS o demo://"

    if parsed.scheme == "demo":
        return None

    hostname = (parsed.hostname or "").lower()
    if not hostname or hostname not in allowed_domains:
        return "Dominio no permitido"

    return None


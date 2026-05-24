"""Persistent log buffer backed by Redis.

Captures Python logging output and stores it in a Redis list so the
dashboard can display logs that survive container restarts.

Falls back to an in-memory deque if Redis is unavailable.

Redis key: log:entries  (list, newest at the right, trimmed to MAX_LINES)
"""

import json
import logging
import threading
import time
from collections import deque
from typing import Optional

from db import redis_client as _rc

MAX_LINES = 2000  # keep more history now that storage is cheap

# -- In-memory fallback ------------------------------------------------

_lock = threading.Lock()
_fallback: deque[dict] = deque(maxlen=MAX_LINES)

_REDIS_KEY = "log:entries"


class DashboardLogHandler(logging.Handler):
    """Logging handler that pushes formatted records into Redis or fallback."""

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = self.format(record)
            entry = {
                "ts": record.created,
                "level": record.levelname,
                "name": record.name,
                "message": msg,
            }

            if _rc.is_available():
                _rc.redis.rpush(_REDIS_KEY, json.dumps(entry))
                _rc.redis.ltrim(_REDIS_KEY, -MAX_LINES, -1)
            else:
                with _lock:
                    _fallback.append(entry)
        except Exception:
            pass  # never break the app because of dashboard logging


def install(level: int = logging.INFO) -> None:
    """Install the dashboard log handler on the root logger."""
    handler = DashboardLogHandler()
    handler.setLevel(level)
    handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s",
                          datefmt="%Y-%m-%d %H:%M:%S")
    )
    logging.getLogger().addHandler(handler)
    root = logging.getLogger()
    if root.level > level:
        root.setLevel(level)


def get_logs(
    limit: int = 200,
    level: Optional[str] = None,
    search: Optional[str] = None,
) -> list[dict]:
    """Return recent log entries, newest last."""
    if _rc.is_available():
        raw = _rc.redis.lrange(_REDIS_KEY, -MAX_LINES, -1)
        entries = [json.loads(r) for r in raw]
    else:
        with _lock:
            entries = list(_fallback)

    if level and level != "ALL":
        entries = [e for e in entries if e["level"] == level.upper()]

    if search:
        q = search.lower()
        entries = [e for e in entries if q in e["message"].lower()]

    return entries[-limit:]


def clear() -> None:
    """Clear all buffered logs."""
    if _rc.is_available():
        _rc.redis.delete(_REDIS_KEY)
    with _lock:
        _fallback.clear()


def count_by_level() -> dict[str, int]:
    """Return count of log entries per level."""
    if _rc.is_available():
        raw = _rc.redis.lrange(_REDIS_KEY, -MAX_LINES, -1)
        entries = [json.loads(r) for r in raw]
    else:
        with _lock:
            entries = list(_fallback)

    counts: dict[str, int] = {}
    for e in entries:
        lv = e["level"]
        counts[lv] = counts.get(lv, 0) + 1
    return counts

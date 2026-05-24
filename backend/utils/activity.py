"""Persistent request activity log backed by Redis.

Stores the last N HTTP requests and per-minute counters for RPM
calculation. Survives container restarts.

Falls back to in-memory storage if Redis is unavailable.

Redis keys:
  activity:requests   -- list of recent request dicts (trimmed to MAX)
  activity:rpm:{min}  -- counter per minute bucket (auto-expires after 10 min)
"""

import json
import threading
import time
from collections import deque

from db import redis_client as _rc

_MAX = 500

# -- In-memory fallback ------------------------------------------------

_lock = threading.Lock()
_fallback: deque[dict] = deque(maxlen=_MAX)
_fb_bucket_ts: float = 0.0
_fb_bucket_count: int = 0
_fb_buckets: deque[tuple[float, int]] = deque(maxlen=120)

_REQ_KEY = "activity:requests"
_RPM_PREFIX = "activity:rpm:"


def record(
    method: str,
    path: str,
    status: int,
    elapsed_ms: float,
    client_ip: str,
) -> None:
    """Record a completed request."""
    now = time.time()
    entry = {
        "ts": now,
        "method": method,
        "path": path,
        "status": status,
        "ms": round(elapsed_ms, 1),
        "ip": client_ip,
    }

    if _rc.is_available():
        pipe = _rc.redis.pipeline(transaction=False)
        pipe.rpush(_REQ_KEY, json.dumps(entry))
        pipe.ltrim(_REQ_KEY, -_MAX, -1)
        # Per-minute counter for RPM
        bucket = int(now / 60) * 60
        rpm_key = f"{_RPM_PREFIX}{bucket}"
        pipe.incr(rpm_key)
        pipe.expire(rpm_key, 600)  # keep 10 min of buckets
        pipe.execute()
    else:
        with _lock:
            _fallback.append(entry)
            global _fb_bucket_ts, _fb_bucket_count
            bucket = int(now / 60) * 60
            if bucket != _fb_bucket_ts:
                if _fb_bucket_ts > 0:
                    _fb_buckets.append((_fb_bucket_ts, _fb_bucket_count))
                _fb_bucket_ts = bucket
                _fb_bucket_count = 0
            _fb_bucket_count += 1


def recent(limit: int = 100, path_filter: str = "") -> list[dict]:
    """Return recent requests, newest first."""
    if _rc.is_available():
        raw = _rc.redis.lrange(_REQ_KEY, -_MAX, -1)
        entries = [json.loads(r) for r in raw]
    else:
        with _lock:
            entries = list(_fallback)

    entries.reverse()
    if path_filter:
        q = path_filter.lower()
        entries = [e for e in entries if q in e["path"].lower()]
    return entries[:limit]


def summary() -> dict:
    """Return aggregate stats: total requests, req/min, error count, etc."""
    now = time.time()

    if _rc.is_available():
        raw = _rc.redis.lrange(_REQ_KEY, -_MAX, -1)
        entries = [json.loads(r) for r in raw]

        # RPM from last 5 minutes
        rpm_total = 0
        rpm_count = 0
        for i in range(5):
            bucket = (int(now / 60) - i) * 60
            val = _rc.redis.get(f"{_RPM_PREFIX}{bucket}")
            if val:
                rpm_total += int(val)
                rpm_count += 1
        rpm = round(rpm_total / max(rpm_count, 1), 1)
    else:
        with _lock:
            entries = list(_fallback)
            buckets = list(_fb_buckets)
            if _fb_bucket_ts > 0:
                buckets.append((_fb_bucket_ts, _fb_bucket_count))

        cutoff = (int(now / 60) - 5) * 60
        recent_buckets = [c for ts, c in buckets if ts >= cutoff]
        rpm = round(sum(recent_buckets) / max(len(recent_buckets), 1), 1)

    total = len(entries)
    errors = sum(1 for e in entries if e["status"] >= 400)

    times = [e["ms"] for e in entries]
    avg_ms = round(sum(times) / len(times), 1) if times else 0

    path_counts: dict[str, int] = {}
    for e in entries:
        p = e["path"]
        path_counts[p] = path_counts.get(p, 0) + 1
    top_paths = sorted(path_counts.items(), key=lambda x: -x[1])[:10]

    return {
        "total": total,
        "errors": errors,
        "rpm": rpm,
        "avg_ms": avg_ms,
        "top_paths": [{"path": p, "count": c} for p, c in top_paths],
    }

"""Persistent metrics: cache hit/miss counts and response times per endpoint.

Backed by Redis hashes and lists. Survives container restarts.
Falls back to in-memory storage if Redis is unavailable.

Redis keys:
  metrics:hits     — hash  { endpoint: count }
  metrics:misses   — hash  { endpoint: count }
  metrics:times:{ep} — list of last 100 response times per endpoint
"""

import json
import threading
from collections import defaultdict, deque

from db import redis_client as _rc

# ── In-memory fallback ────────────────────────────────────────────────

_lock   = threading.Lock()
_fb_hits:   dict[str, int]          = defaultdict(int)
_fb_misses: dict[str, int]          = defaultdict(int)
_fb_times:  dict[str, deque[float]] = defaultdict(lambda: deque(maxlen=100))

_HITS_KEY   = "metrics:hits"
_MISSES_KEY = "metrics:misses"
_TIMES_PREFIX = "metrics:times:"
_TIMES_MAX = 100


def record_hit(endpoint: str) -> None:
    if _rc.is_available():
        _rc.redis.hincrby(_HITS_KEY, endpoint, 1)
    else:
        with _lock:
            _fb_hits[endpoint] += 1


def record_miss(endpoint: str) -> None:
    if _rc.is_available():
        _rc.redis.hincrby(_MISSES_KEY, endpoint, 1)
    else:
        with _lock:
            _fb_misses[endpoint] += 1


def record_time(endpoint: str, elapsed_ms: float) -> None:
    if _rc.is_available():
        key = f"{_TIMES_PREFIX}{endpoint}"
        pipe = _rc.redis.pipeline(transaction=False)
        pipe.rpush(key, round(elapsed_ms, 1))
        pipe.ltrim(key, -_TIMES_MAX, -1)
        pipe.execute()
    else:
        with _lock:
            _fb_times[endpoint].append(elapsed_ms)


def snapshot() -> dict:
    """Return a JSON-serialisable summary of all recorded metrics."""
    if _rc.is_available():
        hits_raw   = _rc.redis.hgetall(_HITS_KEY) or {}
        misses_raw = _rc.redis.hgetall(_MISSES_KEY) or {}

        all_endpoints = set(hits_raw) | set(misses_raw)

        # Also discover endpoints that have times but no hits/misses
        cursor = 0
        while True:
            cursor, keys = _rc.redis.scan(cursor, match=f"{_TIMES_PREFIX}*", count=100)
            for k in keys:
                ep = k.removeprefix(_TIMES_PREFIX)
                all_endpoints.add(ep)
            if cursor == 0:
                break

        result = {}
        for ep in sorted(all_endpoints):
            h = int(hits_raw.get(ep, 0))
            m = int(misses_raw.get(ep, 0))
            total = h + m

            times_raw = _rc.redis.lrange(f"{_TIMES_PREFIX}{ep}", 0, -1)
            ts = sorted(float(t) for t in times_raw) if times_raw else []

            result[ep] = {
                "hits":     h,
                "misses":   m,
                "requests": total,
                "hit_rate": round(h / total, 3) if total else None,
                "avg_ms":   round(sum(ts) / len(ts), 1) if ts else None,
                "p95_ms":   round(ts[int(len(ts) * 0.95)], 1) if ts else None,
            }
        return result
    else:
        with _lock:
            result = {}
            for ep in sorted(set(_fb_hits) | set(_fb_misses) | set(_fb_times)):
                h, m = _fb_hits[ep], _fb_misses[ep]
                total = h + m
                ts = sorted(_fb_times[ep])
                result[ep] = {
                    "hits":     h,
                    "misses":   m,
                    "requests": total,
                    "hit_rate": round(h / total, 3) if total else None,
                    "avg_ms":   round(sum(ts) / len(ts), 1) if ts else None,
                    "p95_ms":   round(ts[int(len(ts) * 0.95)], 1) if ts else None,
                }
            return result

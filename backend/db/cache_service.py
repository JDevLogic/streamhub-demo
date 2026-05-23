"""Cache service — Redis persistence layer.

Provides get/save helpers for anime detail, episode lists, and server links.
TTL validation and dynamic TTL calculation are centralised here.

All function signatures are unchanged from the SQLite version.
If Redis is unavailable, every get returns None (triggering a scrape)
and every save is silently skipped.

TTL hierarchy (RAM > Redis > Scraping):
  Anime detail : 6–24 h  (dynamic: shrinks as the anime gains new episodes)
  Episodios    : 30min–1h (dynamic: same logic)
  Servidores   : 1 h     (fixed — the embed list is stable; the short-lived
                          resolved MP4 is handled separately by /resolver)

Stale-while-revalidate (SWR):
  Entries past STALE_FACTOR of their effective TTL are served immediately
  but flagged so the caller can trigger a background refresh.

Redis key schema:
  anime:{url}        → JSON { "data": {...}, "change_count": N, "prev_ep_count": N }
  episodios:{url}    → JSON { "data": [...], "change_count": N, "prev_count": N }
  servidores:{url}   → JSON [...]
"""

import json
import logging

from db import redis_client as _rc
from db import metrics

_log = logging.getLogger(__name__)

# ── TTL constants (seconds) ────────────────────────────────────────────
ANIME_TTL      = 86_400   # 24 h base
EPISODIOS_TTL  =  3_600   #  1 h base
SERVIDORES_TTL =  3_600   #  1 h (fixed) — embed list is stable; only the
                          #  resolved MP4 expires fast, and that's handled
                          #  by /resolver (which isn't cached).

# Minimum TTL = floor_factor × base
_TTL_FLOOR_FACTOR = 0.25
# Reduction per change event = step_factor × base
_TTL_STEP_FACTOR  = 0.10
# Background refresh triggered once past this fraction of effective TTL
STALE_FACTOR = 0.75


# ── TTL helpers ────────────────────────────────────────────────────────

def get_dynamic_ttl(base_ttl: int, change_count: int) -> int:
    """Scale TTL down as an entry changes more often.

    Each change event reduces TTL by _TTL_STEP_FACTOR × base_ttl,
    floored at _TTL_FLOOR_FACTOR × base_ttl.

    Examples (base_ttl = 86400 s / 24 h):
      change_count=0  → 86400 s (24 h)
      change_count=5  → 43200 s (12 h)
      change_count=9+ →  21600 s ( 6 h, floor)
    """
    floor   = int(base_ttl * _TTL_FLOOR_FACTOR)
    step    = int(base_ttl * _TTL_STEP_FACTOR)
    reduced = base_ttl - change_count * step
    return max(floor, reduced)


# ── Private helpers ────────────────────────────────────────────────────

def _redis_get_raw(key: str, kind: str, *, log_url: str | None = None) -> str | None:
    """Fetch a raw Redis value, recording hit/miss metrics and optional logs.

    ``log_url`` is only used to emit human-readable MISS/HIT logs for the
    detail/episodios namespaces; ``servidores`` skips logging by passing None.
    """
    if _rc.redis is None:
        metrics.record_miss(kind)
        return None
    try:
        raw = _rc.redis.get(key)
    except Exception:
        metrics.record_miss(kind)
        return None

    if not raw or raw == "null":
        if log_url is not None:
            _log.info("MISS %-11s %s", kind, log_url.split('/')[-1])
        metrics.record_miss(kind)
        return None

    if log_url is not None:
        _log.info("HIT  %-11s %s", kind, log_url.split('/')[-1])
    metrics.record_hit(kind)
    return raw


def _save_tracked(
    key: str,
    base_ttl: int,
    data,
    *,
    count_now: int,
    prev_key: str,
    op_name: str,
) -> None:
    """Shared save path for anime_detail / episodios.

    Computes a dynamic TTL from a running change_count that bumps whenever
    ``count_now`` differs from the previously stored ``prev_key`` value.
    """
    if _rc.redis is None:
        return
    try:
        raw = _rc.redis.get(key)
        if raw:
            prev_entry   = json.loads(raw)
            prev         = prev_entry.get(prev_key) or 0
            change_count = (prev_entry.get("change_count") or 0) + (
                1 if prev and count_now and count_now != prev else 0
            )
        else:
            change_count = 0

        ttl = get_dynamic_ttl(base_ttl, change_count)
        entry = json.dumps({
            "data": data,
            "change_count": change_count,
            prev_key: count_now or None,
        }, ensure_ascii=False)
        _rc.redis.setex(key, ttl, entry)
    except Exception as exc:
        _log.debug("Redis %s failed: %s", op_name, exc)


# ── Anime detail ───────────────────────────────────────────────────────

def get_anime_from_cache(url: str) -> dict | None:
    """Return cached anime detail or None if missing / expired."""
    raw = _redis_get_raw(f"anime:{url}", "anime_detail", log_url=url)
    if raw is None:
        return None
    return json.loads(raw)["data"]


def get_anime_from_cache_swr(url: str) -> tuple[dict | None, bool]:
    """Return (data, is_stale) for stale-while-revalidate.

    is_stale=True when data is valid but past STALE_FACTOR of its TTL.
    The caller should serve data immediately and trigger a background refresh.
    """
    key = f"anime:{url}"
    if _rc.redis is None:
        metrics.record_miss("anime_detail")
        return None, False
    try:
        raw = _rc.redis.get(key)
    except Exception:
        metrics.record_miss("anime_detail")
        return None, False

    if not raw or raw == "null":
        _log.info("MISS %-11s %s", "anime_detail", url.split('/')[-1])
        metrics.record_miss("anime_detail")
        return None, False

    entry = json.loads(raw)
    ttl_effective = get_dynamic_ttl(ANIME_TTL, entry.get("change_count", 0))
    ttl_remaining = _rc.redis.ttl(key)

    # ttl_remaining can be -2 (key gone) or -1 (no expiry)
    if ttl_remaining is None or ttl_remaining < 0:
        metrics.record_miss("anime_detail")
        return None, False

    elapsed = ttl_effective - ttl_remaining
    is_stale = elapsed > (ttl_effective * STALE_FACTOR)
    if is_stale:
        _log.debug("stale anime_detail  url=%s", url)
    _log.info("HIT  %-11s %s", "anime_detail", url.split('/')[-1])
    metrics.record_hit("anime_detail")
    return entry["data"], is_stale


def save_anime_to_cache(url: str, data: dict) -> None:
    _save_tracked(
        key=f"anime:{url}",
        base_ttl=ANIME_TTL,
        data=data,
        count_now=int(data.get("episodios_count") or 0),
        prev_key="prev_ep_count",
        op_name="save_anime",
    )


# ── Episodios ──────────────────────────────────────────────────────────

def get_episodios_from_cache(anime_url: str) -> list | None:
    """Return cached episode list or None if missing / expired."""
    raw = _redis_get_raw(f"episodios:{anime_url}", "episodios", log_url=anime_url)
    if raw is None:
        return None
    return json.loads(raw)["data"]


def get_episodios_from_cache_swr(anime_url: str) -> tuple[list | None, bool]:
    """Return (data, is_stale) for stale-while-revalidate.

    is_stale=True when data is valid but past STALE_FACTOR of its TTL.
    The caller should serve data immediately and trigger a background refresh.
    """
    key = f"episodios:{anime_url}"
    if _rc.redis is None:
        metrics.record_miss("episodios")
        return None, False
    try:
        raw = _rc.redis.get(key)
    except Exception:
        metrics.record_miss("episodios")
        return None, False

    if not raw or raw == "null":
        _log.info("MISS %-11s %s", "episodios", anime_url.split('/')[-1])
        metrics.record_miss("episodios")
        return None, False

    entry = json.loads(raw)
    ttl_effective = get_dynamic_ttl(EPISODIOS_TTL, entry.get("change_count", 0))
    ttl_remaining = _rc.redis.ttl(key)

    if ttl_remaining is None or ttl_remaining < 0:
        metrics.record_miss("episodios")
        return None, False

    elapsed = ttl_effective - ttl_remaining
    is_stale = elapsed > (ttl_effective * STALE_FACTOR)
    if is_stale:
        _log.debug("stale episodios     url=%s", anime_url)
    _log.info("HIT  %-11s %s", "episodios", anime_url.split('/')[-1])
    metrics.record_hit("episodios")
    return entry["data"], is_stale


def save_episodios_to_cache(anime_url: str, data: list) -> None:
    _save_tracked(
        key=f"episodios:{anime_url}",
        base_ttl=EPISODIOS_TTL,
        data=data,
        count_now=len(data),
        prev_key="prev_count",
        op_name="save_episodios",
    )


# ── Servidores ─────────────────────────────────────────────────────────

def get_servidores_from_cache(episodio_url: str) -> list | None:
    """Return cached server list or None if missing / expired."""
    raw = _redis_get_raw(f"servidores:{episodio_url}", "servidores")
    if raw is None:
        return None
    return json.loads(raw)


def save_servidores_to_cache(episodio_url: str, data: list) -> None:
    if _rc.redis is None:
        return
    try:
        _rc.redis.setex(
            f"servidores:{episodio_url}",
            SERVIDORES_TTL,
            json.dumps(data, ensure_ascii=False),
        )
    except Exception as exc:
        _log.debug("Redis save_servidores failed: %s", exc)

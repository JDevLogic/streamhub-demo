"""Admin dashboard â€” visual control centre for the AniStream backend.

Routes
------
GET  /dashboard                    â€” Main HTML dashboard (Basic Auth required)
GET  /dashboard/api/stats          â€” Server stats JSON
GET  /dashboard/api/cache          â€” Cache summary JSON
POST /dashboard/api/cache/clear    â€” Clear a cache table
GET  /dashboard/api/intros         â€” List all intro skip entries
POST /dashboard/api/intros         â€” Create / update an intro skip entry (no_intro=true = episodio sin intro)
DELETE /dashboard/api/intros       â€” Delete an intro skip entry
GET  /dashboard/api/intros/pending â€” Episodes without intro skip configured
DELETE /dashboard/api/intros/pending â€” Remove pending episode entry
GET  /dashboard/api/logs           â€” Application logs (in-memory buffer)
POST /dashboard/api/logs/clear     â€” Clear log buffer
GET  /dashboard/api/metrics        â€” Per-endpoint performance metrics
GET  /dashboard/api/activity       â€” Recent request activity log
GET  /dashboard/api/system         â€” System information (disk, versions, etc.)
"""

import os
import secrets
import sys
import time
from pathlib import Path
from typing import Optional

import psutil
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel

from dashboard.templates import DASHBOARD_HTML
from db.database import DB_PATH, get_db_connection
from db import redis_client as _rc
from db import metrics
from db import source_health
from db.error_stats import LABELS as _ERR_LABELS
from utils import log_buffer, activity

router = APIRouter()
_security = HTTPBasic()

# â”€â”€ Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

_DASHBOARD_USER = os.environ.get("DASHBOARD_USER", "")
_DASHBOARD_PASS = os.environ.get("DASHBOARD_PASS", "")
if not _DASHBOARD_USER or not _DASHBOARD_PASS:
    raise RuntimeError(
        "DASHBOARD_USER and DASHBOARD_PASS environment variables must be set. "
        "Add them to your .env file."
    )

_STARTUP_TIME = time.time()


def _require_auth(credentials: HTTPBasicCredentials = Depends(_security)):
    ok_user = secrets.compare_digest(
        credentials.username.encode(), _DASHBOARD_USER.encode()
    )
    ok_pass = secrets.compare_digest(
        credentials.password.encode(), _DASHBOARD_PASS.encode()
    )
    if not (ok_user and ok_pass):
        raise HTTPException(
            status_code=401,
            detail="Unauthorized",
            headers={"WWW-Authenticate": "Basic realm=AniStream Dashboard"},
        )
    return credentials.username


# â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

def _uptime_str(seconds: float) -> str:
    s = int(seconds)
    d, s = divmod(s, 86400)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    parts = []
    if d:
        parts.append(f"{d}d")
    if h:
        parts.append(f"{h}h")
    if m:
        parts.append(f"{m}m")
    parts.append(f"{s}s")
    return " ".join(parts)


def _redis_count(prefix: str) -> int:
    """Count keys matching a prefix using SCAN (non-blocking)."""
    if not _rc.is_available():
        return 0
    count = 0
    cursor = 0
    while True:
        cursor, keys = _rc.redis.scan(cursor, match=f"{prefix}:*", count=200)
        count += len(keys)
        if cursor == 0:
            break
    return count


def _cache_counts() -> dict:
    with get_db_connection() as conn:
        intros = conn.execute("SELECT COUNT(*) FROM intro_skips").fetchone()[0]
    return {
        "anime": _redis_count("anime"),
        "episodios": _redis_count("episodios"),
        "servidores": _redis_count("servidores"),
        "intros": intros,
    }


def _db_size_mb() -> float:
    """Return SQLite DB file size in MB."""
    try:
        size = DB_PATH.stat().st_size
        # Include WAL and SHM if they exist
        for suffix in ("-wal", "-shm"):
            p = DB_PATH.parent / (DB_PATH.name + suffix)
            if p.exists():
                size += p.stat().st_size
        return round(size / (1024 * 1024), 2)
    except Exception:
        return 0.0


# â”€â”€ API endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@router.get("/dashboard/api/stats")
async def api_stats(_user=Depends(_require_auth)):
    proc   = psutil.Process()
    mem    = psutil.virtual_memory()
    cpu    = psutil.cpu_percent(interval=0.2)
    uptime = time.time() - _STARTUP_TIME
    act    = activity.summary()
    redis_info: dict = {}
    if _rc.is_available():
        try:
            ri = _rc.redis.info(section="memory")
            redis_info = {
                "used_mb": round(ri.get("used_memory", 0) / 1024 / 1024, 1),
                "peak_mb": round(ri.get("used_memory_peak", 0) / 1024 / 1024, 1),
            }
        except Exception:
            pass

    return {
        "uptime":       _uptime_str(uptime),
        "uptime_s":     round(uptime),
        "cpu_pct":      cpu,
        "mem_total_mb": round(mem.total / 1024 / 1024),
        "mem_used_mb":  round(mem.used  / 1024 / 1024),
        "mem_pct":      mem.percent,
        "proc_rss_mb":  round(proc.memory_info().rss / 1024 / 1024, 1),
        "db_size_mb":   _db_size_mb(),
        "redis":        redis_info,
        "redis_ok":     _rc.is_available(),
        "total_requests": act["total"],
        "rpm":          act["rpm"],
        "errors":       act["errors"],
        "avg_ms":       act["avg_ms"],
    }


@router.get("/dashboard/api/cache")
async def api_cache(_user=Depends(_require_auth)):
    return _cache_counts()


@router.post("/dashboard/api/cache/clear")
async def api_cache_clear(request: Request, _user=Depends(_require_auth)):
    body  = await request.json()
    table = body.get("table", "")
    # Map legacy table names to Redis key prefixes
    prefix_map = {
        "anime_cache": "anime",
        "episodios_cache": "episodios",
        "servidores_cache": "servidores",
    }
    prefix = prefix_map.get(table)
    if not prefix:
        raise HTTPException(status_code=400, detail=f"tabla invÃ¡lida: {table}")
    if not _rc.is_available():
        raise HTTPException(status_code=503, detail="Redis no disponible")
    cursor = 0
    deleted = 0
    while True:
        cursor, keys = _rc.redis.scan(cursor, match=f"{prefix}:*", count=200)
        if keys:
            deleted += _rc.redis.delete(*keys)
        if cursor == 0:
            break
    return {"cleared": table, "deleted": deleted}


@router.get("/dashboard/api/intros")
async def api_intros_list(_user=Depends(_require_auth)):
    with get_db_connection() as conn:
        rows = conn.execute(
            "SELECT episodio_url, label, intro_start, intro_end, updated_at, no_intro "
            "FROM intro_skips ORDER BY updated_at DESC"
        ).fetchall()
    return [dict(r) for r in rows]


class IntroSkipIn(BaseModel):
    episodio_url: str
    label:        str   = ""
    intro_start:  float = 0.0
    intro_end:    float = 85.0
    no_intro:     bool  = False


@router.post("/dashboard/api/intros")
async def api_intros_upsert(body: IntroSkipIn, _user=Depends(_require_auth)):
    now = time.time()
    if body.no_intro:
        intro_start, intro_end, no_intro_i = 0.0, 0.0, 1
    else:
        if body.intro_end <= body.intro_start:
            raise HTTPException(
                status_code=400, detail="El fin debe ser mayor que el inicio"
            )
        intro_start, intro_end, no_intro_i = body.intro_start, body.intro_end, 0
    with get_db_connection() as conn:
        conn.execute(
            """
            INSERT INTO intro_skips (episodio_url, label, intro_start, intro_end, updated_at, no_intro)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(episodio_url) DO UPDATE SET
                label       = excluded.label,
                intro_start = excluded.intro_start,
                intro_end   = excluded.intro_end,
                updated_at  = excluded.updated_at,
                no_intro    = excluded.no_intro
            """,
            (body.episodio_url, body.label, intro_start, intro_end, now, no_intro_i),
        )
    return {"saved": body.episodio_url}


@router.delete("/dashboard/api/intros")
async def api_intros_delete(request: Request, _user=Depends(_require_auth)):
    body = await request.json()
    url  = body.get("episodio_url", "")
    if not url:
        raise HTTPException(status_code=400, detail="episodio_url requerido")
    with get_db_connection() as conn:
        conn.execute("DELETE FROM intro_skips WHERE episodio_url = ?", (url,))
    return {"deleted": url}


@router.get("/dashboard/api/intros/pending")
async def api_intros_pending(_user=Depends(_require_auth)):
    """Episodes pending intro config: already-seen without skip + next 5 predicted per anime.

    Scoped to animes present in any synced user's "Mi lista" so the dashboard only
    lists content the user actually follows. Falls back to the full set when no
    user has pushed state yet (initial setup).
    """
    import asyncio
    import json as _json
    import re
    from concurrent.futures import ThreadPoolExecutor
    with get_db_connection() as conn:
        pending_rows = conn.execute(
            """
            SELECT s.episodio_url, s.last_seen
            FROM seen_episodes s
            LEFT JOIN intro_skips i ON s.episodio_url = i.episodio_url
            WHERE i.episodio_url IS NULL
            ORDER BY s.last_seen DESC
            LIMIT 100
            """
        ).fetchall()
        all_seen_rows = conn.execute(
            "SELECT episodio_url, last_seen FROM seen_episodes"
        ).fetchall()
        configured = {r["episodio_url"] for r in conn.execute(
            "SELECT episodio_url FROM intro_skips"
        ).fetchall()}
        user_state_rows = conn.execute(
            "SELECT payload FROM user_state"
        ).fetchall()
    all_seen = {r["episodio_url"] for r in all_seen_rows}

    # Union of short slug names (e.g. "dandelion") across every user's Mi lista.
    mylist_slugs: set[str] = set()
    for r in user_state_rows:
        try:
            payload = _json.loads(str(r["payload"]))
        except Exception:
            continue
        items = payload.get("myList") if isinstance(payload, dict) else None
        if not isinstance(items, list):
            continue
        for it in items:
            if not isinstance(it, dict):
                continue
            anime_url = str(it.get("animeUrl") or "").strip().rstrip("/")
            if not anime_url:
                continue
            short = anime_url.rsplit("/", 1)[-1]
            if short:
                mylist_slugs.add(short)

    # Filter only when at least one user has pushed a non-empty Mi lista. If nobody
    # has synced yet, keep the legacy behaviour so the panel isn't silently empty.
    filter_active = bool(mylist_slugs)

    def _short_slug(slug_url: str) -> str:
        return slug_url.rstrip("/").rsplit("/", 1)[-1]

    # URL shape: /ver/<slug>-<N>. We split on the trailing "-<digits>".
    pattern = re.compile(r"^(.*)-(\d+)$")

    def _ep_in_mylist(ep_url: str) -> bool:
        m = pattern.match(ep_url)
        slug_url = m.group(1) if m else ep_url
        return _short_slug(slug_url) in mylist_slugs

    result = [
        {"episodio_url": r["episodio_url"], "last_updated": r["last_seen"], "predicted": False}
        for r in pending_rows
        if not filter_active or _ep_in_mylist(r["episodio_url"])
    ]

    # Group by anime slug and find the highest episode seen per anime.
    # Use ALL seen episodes (even those already configured) so predictions persist
    # after the user configures the real ones.
    latest_per_anime: dict[str, tuple[int, float]] = {}
    for r in all_seen_rows:
        m = pattern.match(r["episodio_url"])
        if not m:
            continue
        slug, ep = m.group(1), int(m.group(2))
        if filter_active and _short_slug(slug) not in mylist_slugs:
            continue
        prev = latest_per_anime.get(slug)
        if prev is None or ep > prev[0]:
            latest_per_anime[slug] = (ep, r["last_seen"])

    # In demo mode episode counts are not available from a real source,
    # so predictions are skipped (None causes the prediction loop to continue).
    def _safe_count(ep_url: str) -> int | None:
        return None

    slugs = list(latest_per_anime.keys())
    sample_urls = [f"{slug}-{latest_per_anime[slug][0]}" for slug in slugs]
    loop = asyncio.get_running_loop()
    with ThreadPoolExecutor(max_workers=min(8, max(1, len(slugs)))) as pool:
        counts_list = await asyncio.gather(*[
            loop.run_in_executor(pool, _safe_count, u) for u in sample_urls
        ]) if slugs else []
    counts_by_slug = dict(zip(slugs, counts_list))

    predicted = []
    for slug, (ep, last_seen) in latest_per_anime.items():
        max_ep = counts_by_slug.get(slug)
        if max_ep is None:
            # Unknown total â€” skip predictions to avoid listing non-existent episodes.
            continue
        for offset in range(1, 6):
            next_ep = ep + offset
            if next_ep > max_ep:
                break
            next_url = f"{slug}-{next_ep}"
            if next_url in configured or next_url in all_seen:
                continue
            predicted.append({
                "episodio_url": next_url,
                "last_updated": last_seen,
                "predicted": True,
            })

    predicted.sort(key=lambda x: (-x["last_updated"], x["episodio_url"]))
    result.extend(predicted)
    return result


@router.delete("/dashboard/api/intros/pending")
async def api_intros_pending_delete(request: Request, _user=Depends(_require_auth)):
    body = await request.json()
    url = body.get("episodio_url", "")
    if not url:
        raise HTTPException(status_code=400, detail="episodio_url requerido")
    with get_db_connection() as conn:
        conn.execute("DELETE FROM seen_episodes WHERE episodio_url = ?", (url,))
    return {"deleted_pending": url}


@router.get("/dashboard/api/logs")
async def api_logs(
    limit: int = Query(200, ge=1, le=500),
    level: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    _user=Depends(_require_auth),
):
    logs = log_buffer.get_logs(limit=limit, level=level, search=search)
    counts = log_buffer.count_by_level()
    return {"lines": logs, "counts": counts}


@router.post("/dashboard/api/logs/clear")
async def api_logs_clear(_user=Depends(_require_auth)):
    log_buffer.clear()
    return {"cleared": True}


@router.get("/dashboard/api/metrics")
async def api_metrics(_user=Depends(_require_auth)):
    return metrics.snapshot()


@router.get("/dashboard/api/activity")
async def api_activity(
    limit: int = Query(100, ge=1, le=300),
    path: Optional[str] = Query(None),
    _user=Depends(_require_auth),
):
    return {
        "requests": activity.recent(limit=limit, path_filter=path or ""),
        "summary": activity.summary(),
    }


@router.get("/dashboard/api/system")
async def api_system(_user=Depends(_require_auth)):
    import platform
    disk = psutil.disk_usage("/")

    redis_info = {}
    if _rc.is_available():
        try:
            ri = _rc.redis.info()
            redis_info = {
                "version":          ri.get("redis_version"),
                "uptime_s":         ri.get("uptime_in_seconds"),
                "used_memory_mb":   round(ri.get("used_memory", 0) / 1024 / 1024, 1),
                "peak_memory_mb":   round(ri.get("used_memory_peak", 0) / 1024 / 1024, 1),
                "connected_clients": ri.get("connected_clients"),
                "total_keys":       sum(
                    ri.get(f"db{i}", {}).get("keys", 0) for i in range(16)
                ),
                "hit_rate": round(
                    ri.get("keyspace_hits", 0)
                    / max(ri.get("keyspace_hits", 0) + ri.get("keyspace_misses", 0), 1),
                    3,
                ),
            }
        except Exception:
            pass

    return {
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "pid": os.getpid(),
        "db_path": str(DB_PATH),
        "db_size_mb": _db_size_mb(),
        "disk_total_gb": round(disk.total / (1024**3), 1),
        "disk_used_gb": round(disk.used / (1024**3), 1),
        "disk_free_gb": round(disk.free / (1024**3), 1),
        "disk_pct": disk.percent,
        "cpu_count": psutil.cpu_count(),
        "boot_time": psutil.boot_time(),
        "startup_time": _STARTUP_TIME,
        "redis_ok": _rc.is_available(),
        "redis": redis_info,
    }


# â”€â”€ Source health â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Demo source health probes -----------------------------------------------------

def _probe_mock_catalog():
    """Probe seguro para la demo pública."""
    return True


def _probe_mock_metadata():
    """Probe seguro para metadata demo."""
    return True


def _probe_demo_video():
    """Probe seguro para validar el recurso de vídeo demo."""
    import requests

    resp = requests.head(
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        timeout=10,
    )

    if resp.status_code not in (200, 206):
        raise RuntimeError(f"HTTP {resp.status_code}")


_PROBES = {
    "mock_catalog": _probe_mock_catalog,
    "mock_metadata": _probe_mock_metadata,
    "demo_video": _probe_demo_video,
}

@router.get("/dashboard/api/sources")
async def api_sources(_user=Depends(_require_auth)):
    return {"sources": source_health.snapshot()}


@router.post("/dashboard/api/sources/{name}/test")
async def api_sources_test(name: str, _user=Depends(_require_auth)):
    if name not in source_health.SOURCES:
        raise HTTPException(status_code=404, detail=f"fuente desconocida: {name}")
    probe = _PROBES.get(name)
    if not probe:
        raise HTTPException(status_code=501, detail=f"sin probe definido para {name}")
    t0 = time.perf_counter()
    try:
        probe()
    except Exception as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        msg = f"{type(exc).__name__}: {exc}"
        source_health.record_failure(name, msg, elapsed)
        return {"ok": False, "elapsed_ms": round(elapsed, 1), "error": msg}
    elapsed = (time.perf_counter() - t0) * 1000
    source_health.record_success(name, elapsed)
    return {"ok": True, "elapsed_ms": round(elapsed, 1)}


@router.post("/dashboard/api/sources/{name}/reset")
async def api_sources_reset(name: str, _user=Depends(_require_auth)):
    if name not in source_health.SOURCES:
        raise HTTPException(status_code=404, detail=f"fuente desconocida: {name}")
    source_health.reset(name)
    return {"ok": True, "reset": name}


@router.get("/dashboard/api/errors")
async def api_errors(_user=Depends(_require_auth)):
    """Aggregated error-category breakdown across all sources.

    `totals` ranks categories globally; `sources` lists the sources that
    have errors, worst first, each with its own per-category breakdown.
    """
    totals: dict[str, int] = {}
    per_source = []
    for s in source_health.snapshot():
        cats = s.get("error_categories") or []
        if not cats:
            continue
        for c in cats:
            totals[c["category"]] = totals.get(c["category"], 0) + c["count"]
        per_source.append({
            "name":       s["name"],
            "label":      s["label"],
            "kind":       s["kind"],
            "total":      sum(c["count"] for c in cats),
            "categories": cats,
        })
    totals_list = sorted(
        ({"category": k, "label": _ERR_LABELS.get(k, k), "count": v}
         for k, v in totals.items()),
        key=lambda d: d["count"], reverse=True,
    )
    per_source.sort(key=lambda d: d["total"], reverse=True)
    return {"totals": totals_list, "sources": per_source}


@router.get("/dashboard/api/sources/{name}/history")
async def api_source_history(
    name: str,
    days: int = Query(7, ge=1, le=90),
    _user=Depends(_require_auth),
):
    """Durable hourly/daily rollup for one source (telemetry Phase 4).

    Answers "when do failures happen" â€” `by_hour` has 24 fixed buckets in
    server-local time.
    """
    if name not in source_health.SOURCES:
        raise HTTPException(status_code=404, detail=f"fuente desconocida: {name}")
    from db import event_history
    return event_history.history(name, days)


@router.get("/dashboard/api/users")
async def api_users(
    limit: int = Query(200, ge=1, le=1000),
    search: Optional[str] = Query(None),
    _user=Depends(_require_auth),
):
    now = time.time()
    where = ""
    params: list = [now]
    if search:
        where = "WHERE lower(u.username) LIKE ? OR lower(u.email) LIKE ?"
        q = f"%{search.lower()}%"
        params.extend([q, q])
    params.append(limit)

    with get_db_connection() as conn:
        rows = conn.execute(
            f"""
            SELECT
                u.id,
                u.username,
                u.email,
                u.created_at,
                COALESCE(us.updated_at, 0) AS state_updated_at,
                COALESCE(LENGTH(us.payload), 0) AS state_size_bytes,
                (
                    SELECT COUNT(*)
                    FROM user_sessions s
                    WHERE s.user_id = u.id AND s.expires_at > ?
                ) AS active_sessions
            FROM users u
            LEFT JOIN user_state us ON us.user_id = u.id
            {where}
            ORDER BY u.created_at DESC
            LIMIT ?
            """,
            tuple(params),
        ).fetchall()
    return [dict(r) for r in rows]


@router.get("/dashboard/api/users/{user_id}")
async def api_user_detail(user_id: int, _user=Depends(_require_auth)):
    now = time.time()
    with get_db_connection() as conn:
        row = conn.execute(
            """
            SELECT
                u.id,
                u.username,
                u.email,
                u.created_at,
                COALESCE(us.updated_at, 0) AS state_updated_at,
                COALESCE(LENGTH(us.payload), 0) AS state_size_bytes,
                (
                    SELECT COUNT(*)
                    FROM user_sessions s
                    WHERE s.user_id = u.id AND s.expires_at > ?
                ) AS active_sessions
            FROM users u
            LEFT JOIN user_state us ON us.user_id = u.id
            WHERE u.id = ?
            """,
            (now, user_id),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return dict(row)


@router.post("/dashboard/api/users/{user_id}/sessions/revoke")
async def api_user_revoke_sessions(user_id: int, _user=Depends(_require_auth)):
    with get_db_connection() as conn:
        exists = conn.execute("SELECT 1 FROM users WHERE id = ?", (user_id,)).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        deleted = conn.execute("DELETE FROM user_sessions WHERE user_id = ?", (user_id,)).rowcount
    return {"ok": True, "revoked_sessions": deleted}


@router.delete("/dashboard/api/users/{user_id}")
async def api_user_delete(user_id: int, _user=Depends(_require_auth)):
    with get_db_connection() as conn:
        exists = conn.execute("SELECT 1 FROM users WHERE id = ?", (user_id,)).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        conn.execute("DELETE FROM user_sessions WHERE user_id = ?", (user_id,))
        conn.execute("DELETE FROM user_state WHERE user_id = ?", (user_id,))
        conn.execute("DELETE FROM users WHERE id = ?", (user_id,))
    return {"ok": True, "deleted_user_id": user_id}


# â”€â”€ Debug Console endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@router.get("/dashboard/api/debug/search")
async def api_debug_search(q: str = "", _user=Depends(_require_auth)):
    """Search anime by name â€” returns list with title, url, cover."""
    if not q.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro q")
    from providers.provider_factory import get_provider
    t0 = time.perf_counter()
    results = get_provider().buscar(q.strip())
    elapsed = round((time.perf_counter() - t0) * 1000, 1)
    return {"results": results, "elapsed_ms": elapsed, "mode": "demo"}


@router.get("/dashboard/api/debug/episodes")
async def api_debug_episodes(url: str = "", _user=Depends(_require_auth)):
    """Get demo episode list for an anime URL."""
    if not url.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro url")

    from providers.provider_factory import get_provider

    provider = get_provider()
    t0 = time.perf_counter()
    episodes = provider.get_episodios(url.strip())
    elapsed = round((time.perf_counter() - t0) * 1000, 1)

    return {
        "episodes": episodes,
        "elapsed_ms": elapsed,
        "count": len(episodes),
        "mode": "demo",
    }


@router.get("/dashboard/api/debug/servers")
async def api_debug_servers(url: str = "", _user=Depends(_require_auth)):
    """Get demo video servers for an episode URL."""
    if not url.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro url")

    from providers.provider_factory import get_provider

    provider = get_provider()
    t0 = time.perf_counter()
    servers = provider.get_servidores(url.strip())
    elapsed = round((time.perf_counter() - t0) * 1000, 1)

    return {
        "servers": servers,
        "count": len(servers),
        "elapsed_ms": elapsed,
        "per_source": {
            "mock_catalog": {
                "servers": servers,
                "elapsed_ms": elapsed,
                "ok": True,
            }
        },
        "mode": "demo",
    }


@router.get("/dashboard/api/debug/resolve")
async def api_debug_resolve(url: str = "", _user=Depends(_require_auth)):
    """Resolve a demo URL to a public demo video stream."""
    if not url.strip():
        raise HTTPException(status_code=400, detail="Falta parámetro url")

    from providers.provider_factory import get_provider

    provider = get_provider()
    t0 = time.perf_counter()
    result = provider.resolver(url.strip())
    elapsed = round((time.perf_counter() - t0) * 1000, 1)

    return {
        "streams": result,
        "elapsed_ms": elapsed,
        "supported": True,
        "count": len(result),
        "mode": "demo",
    }

# â”€â”€ Public read-only endpoint (no auth) â€” used by the Flutter app â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@router.get("/intro-skip")
async def intro_skip_public(url: str = ""):
    """Return intro skip times for an episode URL. Returns {} if not configured or marked no_intro."""
    if not url:
        return {}
    with get_db_connection() as conn:
        row = conn.execute(
            "SELECT intro_start, intro_end, no_intro FROM intro_skips WHERE episodio_url = ?",
            (url,),
        ).fetchone()
    if not row:
        return {}
    if row["no_intro"]:
        return {}
    return {"intro_start": row["intro_start"], "intro_end": row["intro_end"]}


# â”€â”€ HTML Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Dashboard HTML is assembled in dashboard.templates (DASHBOARD_HTML).


@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(_user=Depends(_require_auth)):
    return HTMLResponse(content=DASHBOARD_HTML)



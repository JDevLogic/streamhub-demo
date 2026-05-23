"""Classify provider / resolver error strings into coarse categories.

Pure functions only — no I/O. The category *counters* live in
:mod:`db.source_health` (Redis hash ``source:errcat:{name}``). Kept in a
separate module so the classifier can be reused by the Phase 4 SQLite
rollup and unit-tested in isolation.

The input is the same string :func:`db.source_health.record_failure`
receives, i.e. ``f"{type(exc).__name__}: {exc}"``.

Categories
----------
  timeout     — request timed out
  connection  — DNS / refused / TLS / could not connect
  http_5xx    — upstream returned 5xx
  http_4xx    — upstream returned 4xx (not expiry-related)
  expired     — 403/404/410 or token/expiry wording → stale video URL
  json        — malformed JSON in the upstream payload
  parse       — page fetched but structure no longer matches (HTML changed)
  other       — anything else
"""

from __future__ import annotations

import re

CATEGORIES: tuple[str, ...] = (
    "timeout", "connection", "http_5xx", "http_4xx",
    "expired", "json", "parse", "other",
)

# Human-readable labels for the dashboard
LABELS: dict[str, str] = {
    "timeout":    "Timeout",
    "connection": "Conexión",
    "http_5xx":   "HTTP 5xx",
    "http_4xx":   "HTTP 4xx",
    "expired":    "URL expirada",
    "json":       "JSON inválido",
    "parse":      "HTML cambió",
    "other":      "Otro",
}

_STATUS_RE = re.compile(r"\b([1-5]\d\d)\b")


def classify_error(error: str | None) -> str:
    """Map an error string (``"ClassName: message"``) to a category.

    Order matters: more specific signals are checked first so that, e.g.,
    a ``ConnectTimeout`` lands in ``timeout`` rather than ``connection``.
    """
    if not error:
        return "other"
    raw = str(error)
    low = raw.lower()
    cls = raw.partition(": ")[0].strip().lower()

    # ── timeouts ──────────────────────────────────────────────────────
    if "timeout" in cls or "timed out" in low or "timeout" in low:
        return "timeout"

    # ── connection-level failures ─────────────────────────────────────
    if (
        "connectionerror" in cls
        or "newconnectionerror" in cls
        or "maxretryerror" in cls
        or "sslerror" in cls
        or "proxyerror" in cls
        or "connectionreset" in cls
        or "name or service not known" in low
        or "failed to establish" in low
        or "connection refused" in low
        or "connection aborted" in low
        or "getaddrinfo" in low
        or "[errno -2]" in low
    ):
        return "connection"

    # ── malformed JSON payload ────────────────────────────────────────
    if "jsondecodeerror" in cls or "expecting value" in low or (
        "json" in low and "decod" in low
    ):
        return "json"

    # ── explicit HTTP status code ─────────────────────────────────────
    if "http" in low or "status" in low:
        m = _STATUS_RE.search(raw)
        code = int(m.group(1)) if m else None
        if code is not None:
            if code in (403, 404, 410):
                return "expired"
            if 500 <= code <= 599:
                return "http_5xx"
            if 400 <= code <= 499:
                return "http_4xx"

    # ── stale / expired video URL wording ─────────────────────────────
    if any(k in low for k in (
        "expired", "expir", "caducad", "token",
        "no longer available", "gone",
    )):
        return "expired"

    # ── page fetched but structure changed / nothing matched ──────────
    if (
        cls in ("attributeerror", "indexerror", "keyerror", "typeerror")
        or "nonetype" in low
        or "no match" in low
        or "sin campo" in low
        or "not found" in low
        or "parse" in low
    ):
        return "parse"

    return "other"

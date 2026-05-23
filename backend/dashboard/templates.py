"""Dashboard HTML assembly.

Split out of ``dashboard/routes.py`` (see ``docs/refactor-dashboard-split.md``).
The static shell, CSS and JS live as real files under ``./assets`` so they
get proper tooling (lint/format/highlight); they are read once at import
and inlined into a single HTML document. Serving model is unchanged: one
authenticated ``HTMLResponse`` — no extra routes, no StaticFiles.

Assembled with ``str.replace`` of explicit tokens, **never** f-string or
``str.format``: the CSS/JS contain literal ``{`` ``}``. Data still flows
to the page via ``/dashboard/api/*`` fetches.
"""

from pathlib import Path

_ASSETS = Path(__file__).parent / "assets"

# read_text uses universal newlines → always '\n', regardless of how the
# asset files are checked out (LF/CRLF). Keeps output stable.
_SHELL = (_ASSETS / "dashboard.html").read_text(encoding="utf-8")
_CSS = (_ASSETS / "dashboard.css").read_text(encoding="utf-8")
_JS = (_ASSETS / "dashboard.js").read_text(encoding="utf-8")

DASHBOARD_HTML = (
    _SHELL
    .replace("/*__DASHBOARD_CSS__*/", _CSS, 1)
    .replace("/*__DASHBOARD_JS__*/", _JS, 1)
)

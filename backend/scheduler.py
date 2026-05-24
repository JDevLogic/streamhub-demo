"""Scheduler demo para la versión pública.

Mantiene la estructura de tareas programadas del backend, pero no realiza
scraping ni llamadas a fuentes externas no oficiales.
"""

from __future__ import annotations

import logging

from apscheduler.schedulers.background import BackgroundScheduler

from providers.provider_factory import get_provider


_log = logging.getLogger("scheduler")
_scheduler: BackgroundScheduler | None = None


def warmup_demo_catalog() -> None:
    """Precalienta datos demo para validar el flujo de scheduler."""
    try:
        provider = get_provider()
        animes = provider.get_catalog()
        episodes = provider.get_latest_episodes()
        _log.info(
            "Demo warmup OK: %d catalog items, %d recent episodes",
            len(animes),
            len(episodes),
        )
    except Exception as exc:
        _log.warning("Demo warmup failed: %s", exc)


def refresh_demo_sources() -> None:
    """Tarea periódica demo para mantener visible la arquitectura."""
    try:
        provider = get_provider()
        provider.get_on_air()
        _log.info("Demo refresh OK")
    except Exception as exc:
        _log.warning("Demo refresh failed: %s", exc)


def start_scheduler() -> BackgroundScheduler:
    """Arranca el scheduler de la demo pública."""
    global _scheduler

    if _scheduler and _scheduler.running:
        return _scheduler

    scheduler = BackgroundScheduler(timezone="Europe/Madrid")

    scheduler.add_job(
        warmup_demo_catalog,
        "interval",
        minutes=30,
        id="demo_warmup_catalog",
        replace_existing=True,
        max_instances=1,
    )

    scheduler.add_job(
        refresh_demo_sources,
        "interval",
        minutes=60,
        id="demo_refresh_sources",
        replace_existing=True,
        max_instances=1,
    )

    scheduler.start()
    _scheduler = scheduler

    warmup_demo_catalog()

    _log.info("Demo scheduler started")
    return scheduler


def stop_scheduler() -> None:
    """Detiene el scheduler si está activo."""
    global _scheduler

    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        _log.info("Demo scheduler stopped")

    _scheduler = None

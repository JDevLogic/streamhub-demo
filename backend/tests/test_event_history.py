"""Tests del módulo de historial de eventos (SQLite)."""

import time

from db import event_history


class TestRecord:
    def test_record_ok_no_lanza(self, client):
        event_history.record("src://test-ok", "ok")

    def test_record_fail_con_categoria(self, client):
        event_history.record("src://test-fail", "fail", "timeout")

    def test_record_empty(self, client):
        event_history.record("src://test-empty", "empty")

    def test_record_categoria_none(self, client):
        event_history.record("src://test-none", "fail", None)


class TestHistory:
    def test_history_devuelve_estructura_correcta(self, client):
        result = event_history.history("src://any", days=1)
        assert "source" in result
        assert "days" in result
        assert "by_hour" in result
        assert "by_day" in result
        assert "by_category" in result
        assert len(result["by_hour"]) == 24

    def test_history_refleja_eventos_grabados(self, client):
        src = f"src://hist-{int(time.time() * 1000)}"
        event_history.record(src, "ok")
        event_history.record(src, "fail", "timeout")
        result = event_history.history(src, days=1)
        total_ok = sum(h["ok"] for h in result["by_hour"])
        total_fail = sum(h["fail"] for h in result["by_hour"])
        assert total_ok >= 1
        assert total_fail >= 1

    def test_history_categoria_aparece_en_by_category(self, client):
        src = f"src://cat-{int(time.time() * 1000)}"
        event_history.record(src, "fail", "timeout")
        result = event_history.history(src, days=1)
        cats = [c["category"] for c in result["by_category"]]
        assert "timeout" in cats

    def test_history_fuente_sin_eventos(self, client):
        result = event_history.history("src://never-existed-xyz-abc", days=1)
        assert result["by_day"] == []
        assert all(h["ok"] == 0 for h in result["by_hour"])

    def test_history_days_maxima_limitado(self, client):
        result = event_history.history("src://any", days=9999)
        assert result["days"] <= event_history.RETENTION_DAYS

    def test_history_days_minimo_1(self, client):
        result = event_history.history("src://any", days=0)
        assert result["days"] == 1


class TestPrune:
    def test_prune_devuelve_entero(self, client):
        count = event_history.prune()
        assert isinstance(count, int)
        assert count >= 0

    def test_prune_elimina_registros_antiguos(self, client):
        import sqlite3
        from db.database import DB_PATH

        with sqlite3.connect(str(DB_PATH)) as conn:
            conn.execute(
                "INSERT OR IGNORE INTO source_events_hourly "
                "(source, outcome, err_category, day, hour, count) "
                "VALUES (?, 'ok', '', '1970-01-01', 0, 1)",
                ("src://prune-old",),
            )

        removed = event_history.prune(retention_days=1)
        assert removed >= 1

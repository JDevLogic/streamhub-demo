"""Tests de log_buffer y activity (rutas de fallback sin Redis)."""

import logging

from utils import activity, log_buffer


# -- log_buffer ----------------------------------------------------------------

class TestLogBuffer:
    def setup_method(self):
        log_buffer.clear()

    def _emit(self, message: str, level: int = logging.INFO) -> None:
        handler = log_buffer.DashboardLogHandler()
        handler.setFormatter(logging.Formatter("%(message)s"))
        record = logging.LogRecord("test", level, "", 0, message, (), None)
        handler.emit(record)

    def test_emit_almacena_entrada_en_fallback(self):
        self._emit("hola mundo")
        logs = log_buffer.get_logs()
        assert any("hola mundo" in e["message"] for e in logs)

    def test_get_logs_devuelve_lista(self):
        assert isinstance(log_buffer.get_logs(), list)

    def test_get_logs_filtro_por_nivel(self):
        self._emit("error msg", logging.ERROR)
        logs = log_buffer.get_logs(level="ERROR")
        assert all(e["level"] == "ERROR" for e in logs)

    def test_get_logs_filtro_por_busqueda(self):
        self._emit("marker-unico-xyz")
        logs = log_buffer.get_logs(search="marker-unico-xyz")
        assert len(logs) >= 1

    def test_get_logs_nivel_all_no_filtra(self):
        self._emit("info msg", logging.INFO)
        self._emit("warn msg", logging.WARNING)
        logs = log_buffer.get_logs(level="ALL")
        assert len(logs) >= 2

    def test_clear_vacia_el_buffer(self):
        self._emit("borrar esto")
        log_buffer.clear()
        assert log_buffer.get_logs() == []

    def test_count_by_level_devuelve_dict(self):
        log_buffer.clear()
        self._emit("i", logging.INFO)
        self._emit("w", logging.WARNING)
        self._emit("e", logging.ERROR)
        counts = log_buffer.count_by_level()
        assert isinstance(counts, dict)
        assert counts.get("INFO", 0) >= 1
        assert counts.get("WARNING", 0) >= 1
        assert counts.get("ERROR", 0) >= 1

    def test_count_by_level_buffer_vacio(self):
        counts = log_buffer.count_by_level()
        assert isinstance(counts, dict)


# -- activity ------------------------------------------------------------------

class TestActivity:
    def test_record_no_lanza(self):
        activity.record("GET", "/ping", 200, 5.0, "1.2.3.4")

    def test_recent_devuelve_lista(self):
        assert isinstance(activity.recent(), list)

    def test_recent_con_path_filter(self):
        activity.record("GET", "/unique-path-filter", 200, 5.0, "1.1.1.1")
        result = activity.recent(path_filter="/unique-path-filter")
        assert all("/unique-path-filter" in e["path"] for e in result)

    def test_recent_limit_se_respeta(self):
        for _ in range(5):
            activity.record("GET", "/test", 200, 1.0, "1.2.3.4")
        result = activity.recent(limit=2)
        assert len(result) <= 2

    def test_summary_tiene_campos_obligatorios(self):
        activity.record("GET", "/test", 200, 15.0, "1.2.3.4")
        result = activity.summary()
        for field in ("total", "errors", "rpm", "avg_ms", "top_paths"):
            assert field in result

    def test_summary_cuenta_errores(self):
        activity.record("GET", "/fail", 500, 200.0, "1.2.3.4")
        result = activity.summary()
        assert result["errors"] >= 1

    def test_summary_avg_ms_positivo(self):
        activity.record("GET", "/test", 200, 42.0, "1.2.3.4")
        result = activity.summary()
        assert result["avg_ms"] >= 0

    def test_record_bucket_rollover(self, monkeypatch):
        fake_now = [1_000_000.0]
        monkeypatch.setattr("time.time", lambda: fake_now[0])
        activity.record("GET", "/a", 200, 5.0, "1.1.1.1")
        fake_now[0] += 61.0
        activity.record("GET", "/b", 200, 5.0, "1.1.1.1")

"""Tests del dashboard de administración (Basic Auth requerido)."""

import base64
import uuid


def _basic(user="testadmin", pw="testpass123"):
    token = base64.b64encode(f"{user}:{pw}".encode()).decode()
    return {"Authorization": f"Basic {token}"}


API_KEY = "test-api-key"
HEADERS = {"X-API-Key": API_KEY}


# -- Autenticación ----------------------------------------------------------

class TestDashboardAuth:
    def test_sin_auth_devuelve_401(self, client):
        r = client.get("/dashboard")
        assert r.status_code == 401

    def test_credenciales_incorrectas_devuelven_401(self, client):
        r = client.get("/dashboard", headers=_basic("wrong", "wrong"))
        assert r.status_code == 401

    def test_credenciales_correctas_devuelven_html(self, client):
        r = client.get("/dashboard", headers=_basic())
        assert r.status_code == 200
        assert "text/html" in r.headers["content-type"]


# -- Stats y sistema --------------------------------------------------------

class TestDashboardApiStats:
    def test_stats_tiene_campos_obligatorios(self, client):
        r = client.get("/dashboard/api/stats", headers=_basic())
        assert r.status_code == 200
        data = r.json()
        for field in ("uptime", "cpu_pct", "mem_pct", "db_size_mb", "redis_ok"):
            assert field in data

    def test_system_tiene_campos_obligatorios(self, client):
        r = client.get("/dashboard/api/system", headers=_basic())
        assert r.status_code == 200
        data = r.json()
        for field in ("python", "platform", "pid", "db_path"):
            assert field in data

    def test_stats_sin_auth_devuelve_401(self, client):
        r = client.get("/dashboard/api/stats")
        assert r.status_code == 401


# -- Caché ------------------------------------------------------------------

class TestDashboardApiCache:
    def test_cache_devuelve_contadores(self, client):
        r = client.get("/dashboard/api/cache", headers=_basic())
        assert r.status_code == 200
        assert "intros" in r.json()

    def test_cache_clear_tabla_invalida_devuelve_400(self, client):
        r = client.post(
            "/dashboard/api/cache/clear",
            json={"table": "tabla_falsa"},
            headers=_basic(),
        )
        assert r.status_code == 400


# -- Métricas y actividad ---------------------------------------------------

class TestDashboardApiMetricsActivity:
    def test_metrics_devuelve_dict(self, client):
        r = client.get("/dashboard/api/metrics", headers=_basic())
        assert r.status_code == 200
        assert isinstance(r.json(), dict)

    def test_activity_tiene_requests_y_summary(self, client):
        r = client.get("/dashboard/api/activity", headers=_basic())
        assert r.status_code == 200
        data = r.json()
        assert "requests" in data
        assert "summary" in data

    def test_activity_con_filtro_de_path(self, client):
        r = client.get("/dashboard/api/activity?path=/health", headers=_basic())
        assert r.status_code == 200


# -- Logs -------------------------------------------------------------------

class TestDashboardApiLogs:
    def test_logs_devuelve_lines_y_counts(self, client):
        r = client.get("/dashboard/api/logs", headers=_basic())
        assert r.status_code == 200
        data = r.json()
        assert "lines" in data
        assert "counts" in data

    def test_logs_con_filtro_nivel(self, client):
        r = client.get("/dashboard/api/logs?level=ERROR", headers=_basic())
        assert r.status_code == 200

    def test_logs_con_busqueda(self, client):
        r = client.get("/dashboard/api/logs?search=startup", headers=_basic())
        assert r.status_code == 200

    def test_logs_clear(self, client):
        r = client.post("/dashboard/api/logs/clear", headers=_basic())
        assert r.status_code == 200
        assert r.json()["cleared"] is True


# -- Intro skips -----------------------------------------------------------

class TestDashboardApiIntros:
    EP_URL = "demo://episode/intro-dashboard-test"

    def test_list_devuelve_lista(self, client):
        r = client.get("/dashboard/api/intros", headers=_basic())
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_upsert_con_tiempos_validos(self, client):
        r = client.post(
            "/dashboard/api/intros",
            json={"episodio_url": self.EP_URL, "intro_start": 5.0, "intro_end": 90.0},
            headers=_basic(),
        )
        assert r.status_code == 200
        assert r.json()["saved"] == self.EP_URL

    def test_upsert_no_intro_true(self, client):
        r = client.post(
            "/dashboard/api/intros",
            json={"episodio_url": "demo://episode/no-intro-ep", "no_intro": True},
            headers=_basic(),
        )
        assert r.status_code == 200

    def test_upsert_fin_menor_inicio_devuelve_400(self, client):
        r = client.post(
            "/dashboard/api/intros",
            json={"episodio_url": "demo://ep/bad", "intro_start": 90.0, "intro_end": 10.0},
            headers=_basic(),
        )
        assert r.status_code == 400

    def test_delete_url_existente(self, client):
        r = client.request(
            "DELETE",
            "/dashboard/api/intros",
            json={"episodio_url": self.EP_URL},
            headers=_basic(),
        )
        assert r.status_code == 200

    def test_delete_sin_url_devuelve_400(self, client):
        r = client.request(
            "DELETE", "/dashboard/api/intros", json={}, headers=_basic()
        )
        assert r.status_code == 400

    def test_pending_devuelve_lista(self, client):
        r = client.get("/dashboard/api/intros/pending", headers=_basic())
        assert r.status_code == 200


# -- Intro-skip público (sin auth) ------------------------------------------

class TestIntroSkipPublic:
    def test_sin_url_devuelve_dict_vacio(self, client):
        r = client.get("/intro-skip")
        assert r.status_code == 200
        assert r.json() == {}

    def test_url_sin_configurar_devuelve_dict_vacio(self, client):
        r = client.get("/intro-skip?url=demo://episode/unknown-ep")
        assert r.status_code == 200
        assert r.json() == {}

    def test_url_con_intro_devuelve_tiempos(self, client):
        ep = "demo://episode/public-intro"
        client.post(
            "/dashboard/api/intros",
            json={"episodio_url": ep, "intro_start": 10.0, "intro_end": 80.0},
            headers=_basic(),
        )
        r = client.get(f"/intro-skip?url={ep}")
        assert r.status_code == 200
        data = r.json()
        assert data["intro_start"] == 10.0
        assert data["intro_end"] == 80.0

    def test_url_con_no_intro_devuelve_dict_vacio(self, client):
        ep = "demo://episode/public-no-intro"
        client.post(
            "/dashboard/api/intros",
            json={"episodio_url": ep, "no_intro": True},
            headers=_basic(),
        )
        r = client.get(f"/intro-skip?url={ep}")
        assert r.status_code == 200
        assert r.json() == {}


# -- Sources ----------------------------------------------------------------

class TestDashboardApiSources:
    def test_sources_devuelve_lista(self, client):
        r = client.get("/dashboard/api/sources", headers=_basic())
        assert r.status_code == 200
        assert "sources" in r.json()

    def test_source_history_valido(self, client):
        r = client.get(
            "/dashboard/api/sources/mock_catalog/history", headers=_basic()
        )
        assert r.status_code == 200
        assert "by_hour" in r.json()

    def test_source_history_invalido_devuelve_404(self, client):
        r = client.get(
            "/dashboard/api/sources/fuente_falsa/history", headers=_basic()
        )
        assert r.status_code == 404

    def test_source_test_mock_catalog(self, client):
        r = client.post(
            "/dashboard/api/sources/mock_catalog/test", headers=_basic()
        )
        assert r.status_code == 200
        assert r.json()["ok"] is True

    def test_source_test_invalido_devuelve_404(self, client):
        r = client.post(
            "/dashboard/api/sources/fuente_falsa/test", headers=_basic()
        )
        assert r.status_code == 404

    def test_source_reset_valido(self, client):
        r = client.post(
            "/dashboard/api/sources/mock_catalog/reset", headers=_basic()
        )
        assert r.status_code == 200
        assert r.json()["ok"] is True

    def test_source_reset_invalido_devuelve_404(self, client):
        r = client.post(
            "/dashboard/api/sources/fuente_falsa/reset", headers=_basic()
        )
        assert r.status_code == 404

    def test_errors_devuelve_totals_y_sources(self, client):
        r = client.get("/dashboard/api/errors", headers=_basic())
        assert r.status_code == 200
        data = r.json()
        assert "totals" in data
        assert "sources" in data


# -- Usuarios ---------------------------------------------------------------

class TestDashboardApiUsers:
    def test_list_users_devuelve_lista(self, client, auth_token):
        r = client.get("/dashboard/api/users", headers=_basic())
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_list_users_con_busqueda(self, client, auth_token):
        r = client.get("/dashboard/api/users?search=testuser", headers=_basic())
        assert r.status_code == 200
        users = r.json()
        assert any(u["username"] == "testuser" for u in users)

    def test_user_por_id_invalido_devuelve_404(self, client):
        r = client.get("/dashboard/api/users/99999", headers=_basic())
        assert r.status_code == 404

    def test_revoke_sessions_usuario_invalido_devuelve_404(self, client):
        r = client.post(
            "/dashboard/api/users/99999/sessions/revoke", headers=_basic()
        )
        assert r.status_code == 404

    def test_delete_usuario_invalido_devuelve_404(self, client):
        r = client.request(
            "DELETE", "/dashboard/api/users/99999", headers=_basic()
        )
        assert r.status_code == 404

    def test_crud_completo_usuario_temporal(self, client):
        uid = uuid.uuid4().hex[:8]
        payload = {
            "username": f"tmp_{uid}",
            "email": f"tmp_{uid}@example.com",
            "password": "password123",
        }
        client.post("/auth/register", json=payload, headers=HEADERS)

        r = client.get(f"/dashboard/api/users?search=tmp_{uid}", headers=_basic())
        users = r.json()
        assert len(users) >= 1
        user_id = users[0]["id"]

        r2 = client.get(f"/dashboard/api/users/{user_id}", headers=_basic())
        assert r2.status_code == 200

        r3 = client.post(
            f"/dashboard/api/users/{user_id}/sessions/revoke", headers=_basic()
        )
        assert r3.status_code == 200

        r4 = client.request(
            "DELETE", f"/dashboard/api/users/{user_id}", headers=_basic()
        )
        assert r4.status_code == 200
        assert r4.json()["ok"] is True


# -- Debug Console ----------------------------------------------------------

class TestDashboardApiDebug:
    def test_search_sin_q_devuelve_400(self, client):
        r = client.get("/dashboard/api/debug/search", headers=_basic())
        assert r.status_code == 400

    def test_episodes_sin_url_devuelve_400(self, client):
        r = client.get("/dashboard/api/debug/episodes", headers=_basic())
        assert r.status_code == 400

    def test_servers_sin_url_devuelve_400(self, client):
        r = client.get("/dashboard/api/debug/servers", headers=_basic())
        assert r.status_code == 400

    def test_resolve_sin_url_devuelve_400(self, client):
        r = client.get("/dashboard/api/debug/resolve", headers=_basic())
        assert r.status_code == 400

    def test_servers_con_url_demo(self, client):
        r = client.get(
            "/dashboard/api/debug/servers?url=demo://episode/test",
            headers=_basic(),
        )
        assert r.status_code == 200
        data = r.json()
        assert "servers" in data
        assert "count" in data

    def test_resolve_con_url_demo(self, client):
        r = client.get(
            "/dashboard/api/debug/resolve?url=demo://video/test",
            headers=_basic(),
        )
        assert r.status_code == 200
        data = r.json()
        assert "streams" in data
        assert "count" in data

"""Tests de endpoints de sistema."""

API_KEY = "test-api-key"
HEADERS = {"X-API-Key": API_KEY}


def test_health_ok(client):
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert "redis" in data


def test_metrics_sin_key_devuelve_422(client):
    r = client.get("/metrics")
    assert r.status_code == 422


def test_metrics_ok(client):
    r = client.get("/metrics", headers=HEADERS)
    assert r.status_code == 200
    assert isinstance(r.json(), dict)


def test_root_redirects_to_dashboard(client):
    r = client.get("/", follow_redirects=False)
    assert r.status_code == 302
    assert "/dashboard" in r.headers["location"]

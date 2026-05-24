"""Tests de endpoints públicos (sin autenticación)."""


def test_health_ok(client):
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert "redis" in data


def test_metrics_ok(client):
    r = client.get("/metrics")
    assert r.status_code == 200
    assert isinstance(r.json(), dict)


def test_root_redirects_to_dashboard(client):
    r = client.get("/", follow_redirects=False)
    assert r.status_code == 302
    assert "/dashboard" in r.headers["location"]

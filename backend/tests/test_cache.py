"""Tests de la capa de caché: TTL dinámico y degradación sin Redis."""

from db.cache_service import (
    DETAIL_TTL,
    EPISODES_TTL,
    STALE_FACTOR,
    _TTL_FLOOR_FACTOR,
    _TTL_STEP_FACTOR,
    get_detail_from_cache,
    get_dynamic_ttl,
    get_episodes_from_cache,
    get_sources_from_cache,
    save_detail_to_cache,
    save_episodes_to_cache,
    save_sources_to_cache,
)


# -- TTL dinámico -----------------------------------------------------------

class TestGetDynamicTtl:
    def test_sin_cambios_devuelve_base(self):
        assert get_dynamic_ttl(86_400, 0) == 86_400

    def test_cinco_cambios_reduce_a_la_mitad(self):
        # 86400 - 5 × 8640 = 43200
        assert get_dynamic_ttl(86_400, 5) == 43_200

    def test_floor_se_respeta_con_muchos_cambios(self):
        floor = int(86_400 * _TTL_FLOOR_FACTOR)
        assert get_dynamic_ttl(86_400, 9) == floor
        assert get_dynamic_ttl(86_400, 100) == floor

    def test_floor_es_25_pct_del_base(self):
        for base in [3_600, 86_400]:
            expected_floor = int(base * _TTL_FLOOR_FACTOR)
            assert get_dynamic_ttl(base, 1_000) == expected_floor

    def test_step_es_10_pct_del_base(self):
        step = int(86_400 * _TTL_STEP_FACTOR)
        assert get_dynamic_ttl(86_400, 1) == 86_400 - step

    def test_ttl_nunca_es_negativo(self):
        assert get_dynamic_ttl(100, 10_000) >= 0

    def test_constantes_publicas_son_coherentes(self):
        assert DETAIL_TTL == 86_400
        assert EPISODES_TTL == 3_600
        assert 0 < STALE_FACTOR < 1


# -- Degradación sin Redis --------------------------------------------------
# En el entorno de tests no hay Redis. Todos los gets deben devolver None
# y todos los saves deben completarse sin lanzar excepciones.

class TestSinRedis:
    def test_get_detail_devuelve_none(self):
        assert get_detail_from_cache("http://example.com/titulo") is None

    def test_save_detail_no_lanza(self):
        save_detail_to_cache("http://example.com/titulo", {"titulo": "Test", "episodios_count": 12})

    def test_get_episodes_devuelve_none(self):
        assert get_episodes_from_cache("http://example.com/titulo") is None

    def test_save_episodes_no_lanza(self):
        save_episodes_to_cache("http://example.com/titulo", [{"episodio": "1"}])

    def test_get_sources_devuelve_none(self):
        assert get_sources_from_cache("http://example.com/episodio") is None

    def test_save_sources_no_lanza(self):
        save_sources_to_cache("http://example.com/episodio", [{"name": "server1", "url": "http://s.io"}])

    def test_get_detail_no_falla_con_urls_extranas(self):
        assert get_detail_from_cache("") is None
        assert get_detail_from_cache("demo://content/test") is None
        assert get_detail_from_cache("x" * 500) is None

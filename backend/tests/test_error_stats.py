"""Tests del clasificador de errores (pure functions, sin I/O)."""

from db.error_stats import classify_error


class TestClassifyError:
    def test_none_devuelve_other(self):
        assert classify_error(None) == "other"

    def test_cadena_vacia_devuelve_other(self):
        assert classify_error("") == "other"

    def test_timeout_en_nombre_de_clase(self):
        assert classify_error("ReadTimeout: read timed out") == "timeout"

    def test_timeout_en_mensaje(self):
        assert classify_error("Exception: request timeout exceeded") == "timeout"

    def test_timed_out_en_mensaje(self):
        assert classify_error("Exception: connection timed out after 30s") == "timeout"

    def test_connection_error(self):
        assert classify_error("ConnectionError: failed to establish connection") == "connection"

    def test_ssl_error(self):
        assert classify_error("SSLError: certificate verify failed") == "connection"

    def test_dns_failure(self):
        assert classify_error("Exception: name or service not known") == "connection"

    def test_connection_refused(self):
        assert classify_error("OSError: connection refused") == "connection"

    def test_connection_aborted(self):
        assert classify_error("OSError: connection aborted") == "connection"

    def test_getaddrinfo_failure(self):
        assert classify_error("Exception: getaddrinfo failed for host") == "connection"

    def test_json_decode_error(self):
        assert classify_error("JSONDecodeError: expecting value: line 1 col 1") == "json"

    def test_json_decod_en_mensaje(self):
        assert classify_error("Exception: failed to json decod response") == "json"

    def test_http_403_es_expired(self):
        assert classify_error("HTTPError: HTTP 403 status code") == "expired"

    def test_http_404_es_expired(self):
        assert classify_error("HTTPError: HTTP 404 status code") == "expired"

    def test_http_410_es_expired(self):
        assert classify_error("HTTPError: HTTP 410 status code") == "expired"

    def test_http_500_es_5xx(self):
        assert classify_error("HTTPError: HTTP 500 status code") == "http_5xx"

    def test_http_503_es_5xx(self):
        assert classify_error("HTTPError: HTTP 503 status code") == "http_5xx"

    def test_http_429_es_4xx(self):
        assert classify_error("HTTPError: HTTP 429 status code") == "http_4xx"

    def test_expired_en_mensaje(self):
        assert classify_error("Exception: video URL has expired") == "expired"

    def test_token_en_mensaje(self):
        assert classify_error("Exception: invalid token in request") == "expired"

    def test_attribute_error_es_parse(self):
        assert classify_error("AttributeError: NoneType has no attribute x") == "parse"

    def test_key_error_es_parse(self):
        assert classify_error("KeyError: 'titulo'") == "parse"

    def test_index_error_es_parse(self):
        assert classify_error("IndexError: list index out of range") == "parse"

    def test_no_match_en_mensaje(self):
        assert classify_error("Exception: no match found on page") == "parse"

    def test_error_desconocido_es_other(self):
        assert classify_error("SomeUnknownError: something weird") == "other"

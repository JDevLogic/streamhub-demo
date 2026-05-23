import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;


class AnimeService {
  // Override with --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5050',
  );

  // Override with --dart-define=API_KEY=...
  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
  );

  static const _timeout = Duration(seconds: 20);

  /// Detalle y listas de episodios pueden implicar scraping en el servidor;
  /// en redes lentas o franquicias con muchas relaciones conviene más margen.
  static const _heavyTimeout = Duration(seconds: 45);
  static const _resolvedTtl = Duration(minutes: 5);
  static const _detailTtl = Duration(minutes: 10);
  static String get _requiredApiKey {
    if (_apiKey.isEmpty) {
      throw StateError(
        'API_KEY no configurada. Recompila con --dart-define=API_KEY=...',
      );
    }
    return _apiKey;
  }

  static Map<String, String> get _headers => {'X-API-Key': _requiredApiKey};

  // Per-instance resolved-URL cache: avoids redundant resolver round-trips
  // for the same episode within a session.
  final _resolvedCache =
      <String, ({List<Map<String, dynamic>> sources, DateTime at})>{};
  final _detailCache = <String, ({Map<String, dynamic> data, DateTime at})>{};

  // ── Internal helpers ──────────────────────────────────────────────

  Future<http.Response> _get(Uri uri, {Duration? timeout}) async {
    const maxRetries = 2;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final response =
          await http.get(uri, headers: _headers).timeout(timeout ?? _timeout);
      if (response.statusCode != 429) return response;
      if (attempt == maxRetries) return response;
      final retryAfter = int.tryParse(
            response.headers['retry-after'] ?? '',
          ) ??
          2;
      await Future.delayed(Duration(seconds: retryAfter));
    }
    throw StateError('unreachable');
  }

  /// Fetch a JSON list endpoint and decode it to a typed list of maps.
  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, String>? params,
    Duration? timeout,
    required String errorMessage,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final response = await _get(uri, timeout: timeout);
    if (response.statusCode != 200) {
      throw Exception('$errorMessage (HTTP ${response.statusCode})');
    }
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>>? _getCachedResolved(String embedUrl) {
    final entry = _resolvedCache[embedUrl];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _resolvedTtl) {
      _resolvedCache.remove(embedUrl);
      return null;
    }
    return entry.sources;
  }

  Map<String, dynamic>? _getCachedDetail(String animeUrl) {
    final entry = _detailCache[animeUrl];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > _detailTtl) {
      _detailCache.remove(animeUrl);
      return null;
    }
    return entry.data;
  }

  // ── API methods ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAnimes() =>
      _getList('/animes', errorMessage: 'Error al cargar animes');

  Future<List<Map<String, dynamic>>> getEpisodios(String animeUrl) => _getList(
        '/episodios',
        params: {'url': animeUrl},
        timeout: _heavyTimeout,
        errorMessage: 'Error al cargar episodios',
      );

  Future<List<Map<String, dynamic>>> getServidores(String episodioUrl) =>
      _getList(
        '/servidores',
        params: {'url': episodioUrl},
        errorMessage: 'Error al cargar servidores',
      );

  Future<List<Map<String, dynamic>>> getUltimosEpisodios() => _getList(
        '/ultimos-episodios',
        errorMessage: 'Error al cargar últimos episodios',
      );

  Future<List<Map<String, dynamic>>> getEnEmision() => _getList(
        '/en-emision',
        errorMessage: 'Error al cargar animes en emisión',
      );

  Future<List<Map<String, dynamic>>> buscarAnimes(String query) => _getList(
        '/buscar',
        params: {'q': query},
        errorMessage: 'Error en búsqueda',
      );

  Future<List<Map<String, dynamic>>> getAnimesporGenero(String genero) =>
      _getList(
        '/animes-por-genero',
        params: {'genero': genero},
        errorMessage: 'Error al cargar animes por género',
      );

  Future<Map<String, dynamic>> getAnimeDetalle(String animeUrl) async {
    final cached = _getCachedDetail(animeUrl);
    if (cached != null) return cached;

    final uri = Uri.parse('$baseUrl/anime-detalle')
        .replace(queryParameters: {'url': animeUrl});
    final response = await _get(uri, timeout: _heavyTimeout);
    if (response.statusCode != 200) {
      throw Exception(
          'Error al cargar detalle del anime (HTTP ${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _detailCache[animeUrl] = (data: data, at: DateTime.now());
    return data;
  }

  /// Returns intro skip times for an episode URL, or null if not configured.
  Future<({double start, double end})?> getIntroSkip(String episodioUrl) async {
    if (episodioUrl.isEmpty) return null;
    try {
      final uri = Uri.parse('$baseUrl/intro-skip')
          .replace(queryParameters: {'url': episodioUrl});
      final response = await _get(uri, timeout: const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.isEmpty) return null;
      return (
        start: (body['intro_start'] as num).toDouble(),
        end: (body['intro_end'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Warm the backend detail cache for a list of anime URLs (fire and forget).
  void prefetch(List<String> animeUrls) {
    if (animeUrls.isEmpty) return;
    final uri = Uri.parse('$baseUrl/prefetch');
    http
        .post(uri,
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'urls': animeUrls}))
        .timeout(const Duration(seconds: 5))
        .catchError((_) => http.Response('', 200));
  }

  /// Warm local in-memory detail cache for first search results.
  /// This reduces first-open latency from Search -> Detail.
  void prefetchDetailCache(List<String> animeUrls, {int limit = 4}) {
    if (animeUrls.isEmpty) return;
    final urls = animeUrls
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toSet()
        .take(limit);
    for (final url in urls) {
      if (_getCachedDetail(url) != null) continue;
      getAnimeDetalle(url).catchError((_) => <String, dynamic>{});
    }
  }

  /// Resolve an embed URL to direct MP4/HLS stream(s).
  /// Runs on-device so the phone's IP is used (avoids IP-locked tokens).
  /// Uses an in-memory cache to avoid redundant resolver calls.
  Future<List<Map<String, dynamic>>> resolveDirectUrl(String embedUrl) async {
    final cached = _getCachedResolved(embedUrl);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse('/resolver').replace(
        queryParameters: {'url': embedUrl},
      );

      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);

      final sources = decoded is List
          ? decoded.map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      if (sources.isNotEmpty) {
        _resolvedCache[embedUrl] = (sources: sources, at: DateTime.now());
      }
      return sources;
    } catch (_) {
      return [];
    }
  }

  // ── Server priority (pure utility — stays static) ─────────────────

  static const _kServerPriority = [
    'demo',
  ];







  ];

  static int _serverPriorityOf(Map<String, dynamic> server) {
    final url = (server['enlace'] ?? '').toString().toLowerCase();

    if (url.contains('voe.')) return 1000; // Always keep Voe as final fallback.
    for (int i = 0; i < _kServerPriority.length; i++) {
      if (url.contains(_kServerPriority[i])) return i;
    }
    return _kServerPriority.length;
  }

  static List<Map<String, dynamic>> sortServersByPriority(
    List<Map<String, dynamic>> servers,
  ) {
    final sorted = List<Map<String, dynamic>>.from(servers);
    sorted.sort((a, b) => _serverPriorityOf(a).compareTo(_serverPriorityOf(b)));
    return sorted;
  }
}


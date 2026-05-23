import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of uploading local state. Lets callers react to version conflicts.
class UploadResult {
  const UploadResult({
    required this.ok,
    required this.conflict,
    this.version,
    this.currentServerVersion,
  });

  final bool ok;
  final bool conflict;
  final int? version;
  final int? currentServerVersion;
}

class UserSyncService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5050',
  );

  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
  );

  static const _timeout = Duration(seconds: 20);

  static String get _requiredApiKey {
    if (_apiKey.isEmpty) {
      throw StateError(
        'API_KEY no configurada. Recompila con --dart-define=API_KEY=...',
      );
    }
    return _apiKey;
  }

  /// Returns the raw decoded body (payload + version + updated_at), or null
  /// on network/auth failure. A freshly-created user has `payload == null`
  /// and `version == 0`.
  static Future<Map<String, dynamic>?> downloadState(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/user/state'),
      headers: {
        'Authorization': 'Bearer $token',
        'X-API-Key': _requiredApiKey,
      },
    ).timeout(_timeout);
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Uploads [payload] using optimistic concurrency. When [expectedVersion]
  /// is provided and doesn't match server's version, returns an
  /// [UploadResult] with `conflict: true` and the `currentServerVersion`
  /// the caller can use to re-merge + retry.
  static Future<UploadResult> uploadState(
    String token,
    Map<String, dynamic> payload, {
    int? expectedVersion,
  }) async {
    final body = <String, dynamic>{'payload': payload};
    if (expectedVersion != null) {
      body['expected_version'] = expectedVersion;
    }
    final res = await http
        .post(
          Uri.parse('$baseUrl/user/state'),
          headers: {
            'Authorization': 'Bearer $token',
            'X-API-Key': _requiredApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return UploadResult(
        ok: true,
        conflict: false,
        version: (decoded['version'] as num?)?.toInt(),
      );
    }

    if (res.statusCode == 409) {
      int? serverVersion;
      try {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final detail = decoded['detail'];
        if (detail is Map) {
          serverVersion = (detail['current_version'] as num?)?.toInt();
        }
      } catch (_) {}
      return UploadResult(
        ok: false,
        conflict: true,
        currentServerVersion: serverVersion,
      );
    }

    return const UploadResult(ok: false, conflict: false);
  }
}

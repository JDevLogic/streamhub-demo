import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthServiceResult<T> {
  const AuthServiceResult({
    required this.ok,
    this.data,
    this.message,
  });

  final bool ok;
  final T? data;
  final String? message;
}

class AuthService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5050',
  );

  static const String _apiKey = String.fromEnvironment(
    'API_KEY',
  );

  static const _timeout = Duration(seconds: 15);

  // /auth/* endpoints don't require X-API-Key on the backend, so we only
  // attach the header when it's defined. This lets login/register/me/logout
  // work even if the app was built without --dart-define=API_KEY=...
  static Map<String, String> _jsonHeaders() => {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
      };

  static Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        if (_apiKey.isNotEmpty) 'X-API-Key': _apiKey,
      };

  static Future<AuthServiceResult<Map<String, dynamic>>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'identifier': identifier,
              'password': password,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        return AuthServiceResult(
          ok: false,
          message: _messageFromResponse(
            res,
            fallback: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
          ),
        );
      }
      return AuthServiceResult(
        ok: true,
        data: jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AuthServiceResult(
        ok: false,
        message: 'No hay conexión con el servidor. Inténtalo de nuevo.',
      );
    }
  }

  static Future<AuthServiceResult<void>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return const AuthServiceResult(ok: true);
      }
      return AuthServiceResult(
        ok: false,
        message: _messageFromResponse(
          res,
          fallback: 'No se pudo crear la cuenta. Verifica los datos.',
        ),
      );
    } catch (_) {
      return const AuthServiceResult(
        ok: false,
        message: 'No hay conexión con el servidor. Inténtalo de nuevo.',
      );
    }
  }

  static Future<Map<String, dynamic>?> me(String token) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/auth/me'),
          headers: _authHeaders(token),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> logout(String token) async {
    await http
        .post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: _authHeaders(token),
        )
        .timeout(_timeout);
  }

  static String _messageFromResponse(
    http.Response res, {
    required String fallback,
  }) {
    if (res.statusCode == 401) return 'Credenciales inválidas.';
    if (res.statusCode == 409) return 'Ese usuario o email ya existe.';
    if (res.statusCode == 422 || res.statusCode == 400) {
      return 'Revisa los datos e inténtalo de nuevo.';
    }

    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    } catch (_) {}
    return fallback;
  }
}

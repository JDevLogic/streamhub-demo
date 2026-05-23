import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';
import '../services/watch_history.dart';

// ── Auth State ────────────────────────────────────────────────────────────────

enum AuthStatus { unknown, unauthenticated, authenticated, guest }

class AuthState {
  const AuthState({
    required this.status,
    this.username,
    this.email,
    this.token,
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastSyncError,
    this.lastAuthError,
  });

  final AuthStatus status;
  final String? username;
  final String? email;
  final String? token;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastSyncError;
  final String? lastAuthError;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.guest;
  bool get isInitializing => status == AuthStatus.unknown;
  bool get isLoggedIn =>
      status == AuthStatus.authenticated || status == AuthStatus.guest;

  AuthState copyWith({
    AuthStatus? status,
    String? username,
    String? email,
    String? token,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastSyncError,
    bool clearLastSyncError = false,
    String? lastAuthError,
    bool clearLastAuthError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      username: username ?? this.username,
      email: email ?? this.email,
      token: token ?? this.token,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncError:
          clearLastSyncError ? null : lastSyncError ?? this.lastSyncError,
      lastAuthError:
          clearLastAuthError ? null : lastAuthError ?? this.lastAuthError,
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.unknown)) {
    _loadPersistedState();
  }

  static const _kStatusKey = 'auth_status';
  static const _kUsernameKey = 'auth_username';
  static const _kEmailKey = 'auth_email';
  static const _kTokenKey = 'auth_token';
  static const _kLastAccountKey = 'auth_last_account';
  static const _kLastSyncAtKey = 'auth_last_sync_at';

  // On startup, restore previous session from SharedPreferences.
  // Local credentials resolve the UI immediately; token validation and cloud
  // sync run in the background so the app doesn't block on the network.
  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kStatusKey);
    final lastSyncAt =
        DateTime.tryParse(prefs.getString(_kLastSyncAtKey) ?? '');
    if (saved == AuthStatus.authenticated.name) {
      final token = prefs.getString(_kTokenKey);
      if (token == null || token.isEmpty) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        username: prefs.getString(_kUsernameKey),
        email: prefs.getString(_kEmailKey),
        token: token,
        lastSyncAt: lastSyncAt,
      );
      unawaited(_refreshSessionInBackground(token));
    } else if (saved == AuthStatus.guest.name) {
      state = AuthState(status: AuthStatus.guest, lastSyncAt: lastSyncAt);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _refreshSessionInBackground(String token) async {
    try {
      final me = await AuthService.me(token);
      // Only update profile fields; don't log out on null (could be offline).
      if (me != null && state.status == AuthStatus.authenticated) {
        final prefs = await SharedPreferences.getInstance();
        final username =
            (me['username'] as String?) ?? prefs.getString(_kUsernameKey);
        final email = (me['email'] as String?) ?? prefs.getString(_kEmailKey);
        if (username != null) await prefs.setString(_kUsernameKey, username);
        if (email != null) await prefs.setString(_kEmailKey, email);
        state = state.copyWith(username: username, email: email);
      }
      // Suppress cloud pushes until the initial download completes, so a stale
      // local state can't overwrite fresher cloud data from another device
      // during the HTTP download window.
      final downloaded = await WatchHistory.runWithoutCloudSync(() async {
        return _syncWithCloud(token);
      });
      // Flush any local mutations made during the sync window so they reach
      // cloud. Uses the conflict-retry path so a concurrent upload from
      // another device doesn't silently lose our changes.
      final pushed = await WatchHistory.pushToCloudWithRetry(token);
      if (downloaded && pushed) {
        await _markSyncSuccess();
      } else {
        _markSyncFailure('No se pudo completar la sincronización.');
      }
    } catch (_) {
      // Local UX stays functional if validation/sync fails.
      _markSyncFailure('No se pudo sincronizar. Revisa tu conexión.');
    }
  }

  Future<bool> login(String emailOrUser, String password) async {
    if (emailOrUser.trim().isEmpty || password.trim().isEmpty) {
      state =
          state.copyWith(lastAuthError: 'Completa email/usuario y contraseña.');
      return false;
    }

    final response = await AuthService.login(
      identifier: emailOrUser.trim(),
      password: password.trim(),
    );
    if (!response.ok || response.data == null) {
      state = state.copyWith(
        lastAuthError: response.message ?? 'No se pudo iniciar sesión.',
      );
      return false;
    }

    final data = response.data!;
    final user = (data['user'] as Map?)?.cast<String, dynamic>();
    final token = data['access_token'] as String?;
    if (user == null || token == null || token.isEmpty) {
      state = state.copyWith(lastAuthError: 'Respuesta inválida del servidor.');
      return false;
    }
    final accountKey =
        ((user['email'] as String?) ?? (user['username'] as String?) ?? '')
            .toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final previousAccount =
        (prefs.getString(_kLastAccountKey) ?? '').toLowerCase();
    final switchedAccount = previousAccount.isNotEmpty &&
        accountKey.isNotEmpty &&
        previousAccount != accountKey;

    // Prevent cross-account bleed: start with a clean local state on account switch.
    // Hard-wipe (not soft-clear) — otherwise tombstones would sync to the new account.
    if (switchedAccount) {
      await WatchHistory.runWithoutCloudSync(() async {
        await WatchHistory.hardClearAllSyncedData();
      });
      // Previous account's cloud version is meaningless for the new account.
      await WatchHistory.clearCloudVersion();
    }

    final newState = AuthState(
      status: AuthStatus.authenticated,
      username: user['username'] as String?,
      email: user['email'] as String?,
      token: token,
    );

    await _persist(newState, accountKey: accountKey);
    final syncOk = await _syncWithCloud(token, clearLocalOnEmptyRemote: false);
    final lastSyncAt = syncOk ? DateTime.now() : state.lastSyncAt;
    if (syncOk) {
      await _persistLastSyncAt(lastSyncAt!);
    }
    state = newState.copyWith(
      lastSyncAt: lastSyncAt,
      lastSyncError:
          syncOk ? null : 'Sesión iniciada, pero no se pudo sincronizar.',
      clearLastSyncError: syncOk,
      clearLastAuthError: true,
    );
    return true;
  }

  Future<bool> registerAndLogin({
    required String username,
    required String email,
    required String password,
  }) async {
    if (username.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty) {
      state = state.copyWith(
          lastAuthError: 'Completa usuario, email y contraseña.');
      return false;
    }

    final result = await AuthService.register(
      username: username.trim(),
      email: email.trim(),
      password: password.trim(),
    );
    if (!result.ok) {
      state = state.copyWith(
        lastAuthError: result.message ?? 'No se pudo crear la cuenta.',
      );
      return false;
    }

    // New accounts must not inherit guest/local progress from previous sessions.
    // Hard-wipe (not soft-clear) — otherwise tombstones would sync to the new account.
    await WatchHistory.runWithoutCloudSync(() async {
      await WatchHistory.hardClearAllSyncedData();
    });
    await WatchHistory.clearCloudVersion();
    return login(email.trim(), password.trim());
  }

  Future<void> continueAsGuest() async {
    state = const AuthState(status: AuthStatus.guest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStatusKey, AuthStatus.guest.name);
    await prefs.remove(_kTokenKey);
  }

  Future<void> logout() async {
    final token = state.token;
    if (token != null && token.isNotEmpty) {
      try {
        await WatchHistory.pushToCloudWithRetry(token);
        await AuthService.logout(token);
      } catch (_) {}
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStatusKey);
    await prefs.remove(_kUsernameKey);
    await prefs.remove(_kEmailKey);
    await prefs.remove(_kTokenKey);
    await WatchHistory.clearCloudVersion();
  }

  Future<bool> syncNow() async {
    final token = state.token;
    if (state.status != AuthStatus.authenticated ||
        token == null ||
        token.isEmpty) {
      state = state.copyWith(
        lastSyncError: 'Inicia sesión para sincronizar tu progreso.',
      );
      return false;
    }
    if (state.isSyncing) return false;

    state = state.copyWith(isSyncing: true, clearLastSyncError: true);
    try {
      final downloaded = await WatchHistory.runWithoutCloudSync(() async {
        return _syncWithCloud(token);
      });
      final pushed = await WatchHistory.pushToCloudWithRetry(token);
      final ok = downloaded && pushed;
      if (ok) {
        await _markSyncSuccess();
      } else {
        _markSyncFailure('No se pudo completar la sincronización.');
      }
      return ok;
    } catch (_) {
      _markSyncFailure('No se pudo sincronizar. Revisa tu conexión.');
      return false;
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> _persist(AuthState s, {String? accountKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStatusKey, s.status.name);
    if (s.username != null) await prefs.setString(_kUsernameKey, s.username!);
    if (s.email != null) await prefs.setString(_kEmailKey, s.email!);
    if (s.token != null) await prefs.setString(_kTokenKey, s.token!);
    if (accountKey != null && accountKey.isNotEmpty) {
      await prefs.setString(_kLastAccountKey, accountKey);
    }
  }

  Future<bool> _syncWithCloud(String token,
      {bool clearLocalOnEmptyRemote = false}) async {
    try {
      final remote = await UserSyncService.downloadState(token);
      if (remote == null) return false;
      final remotePayload =
          (remote['payload'] as Map?)?.cast<String, dynamic>();
      final serverVersion = (remote['version'] as num?)?.toInt() ?? 0;
      // Remember the version we just observed so a subsequent push can prove
      // it was based on the latest server state (optimistic concurrency).
      await WatchHistory.saveCloudVersion(serverVersion);

      final localPayload = await WatchHistory.exportSyncPayload();
      final localHasData = _payloadHasUserData(localPayload);
      final remoteHasData = _payloadHasUserData(remotePayload);

      if (remoteHasData) {
        // True merge now (last-write-wins per entry on updatedAt), not a wipe.
        await WatchHistory.mergeSyncPayload(remotePayload!);
      } else if (clearLocalOnEmptyRemote) {
        await WatchHistory.runWithoutCloudSync(() async {
          await WatchHistory.hardClearAllSyncedData();
        });
      } else if (localHasData) {
        // Keep local data when remote is empty (prevents accidental wipe).
        // pushToCloudWithRetry handles the expected_version + 409 retry dance.
        return WatchHistory.pushToCloudWithRetry(token);
      }
      // When remote has data, the merge is enough here. Regular mutations/logout
      // already push updates and avoid accidental overwrite with empty payloads.
      return true;
    } catch (_) {
      // Keep local UX resilient if sync fails.
      return false;
    }
  }

  Future<void> _markSyncSuccess() async {
    final syncedAt = DateTime.now();
    await _persistLastSyncAt(syncedAt);
    if (state.status == AuthStatus.authenticated) {
      state = state.copyWith(
        lastSyncAt: syncedAt,
        clearLastSyncError: true,
      );
    }
  }

  void _markSyncFailure(String message) {
    if (state.status == AuthStatus.authenticated) {
      state = state.copyWith(lastSyncError: message);
    }
  }

  Future<void> _persistLastSyncAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSyncAtKey, value.toIso8601String());
  }

  bool _payloadHasUserData(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final myList = payload['myList'];
    final history = payload['history'];
    final progress = payload['progress'];
    final hasMyList = myList is List && myList.isNotEmpty;
    final hasHistory = history is List && history.isNotEmpty;
    // v1 stored progress as Map<epUrl, {...}>; v2 stores it as List<Map>.
    final hasProgress = (progress is Map && progress.isNotEmpty) ||
        (progress is List && progress.isNotEmpty);
    final watched = payload['watched'];
    final hasWatched = watched is List && watched.isNotEmpty;
    return hasMyList || hasHistory || hasProgress || hasWatched;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

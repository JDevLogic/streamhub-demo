import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/watch_database.dart';
import 'user_sync_service.dart';

/// Public API — callers are unchanged. Backed by SQLite via Drift.
class WatchHistory {
  static WatchDatabase? _db;
  static bool _isImporting = false;
  static bool _suppressCloudPush = false;

  static WatchDatabase get _database {
    _db ??= WatchDatabase();
    return _db!;
  }

  /// Call once on app start (after WidgetsFlutterBinding.ensureInitialized).
  /// Migrates existing SharedPreferences data to SQLite on first run.
  static Future<void> init() => _database.migrateFromPrefs();

  // --------------- Content-level (home "Últimos Vistos") ---------------

  static Future<void> add({
    required String titulo,
    required String url,
    String imagen = '',
    String lastEpisodeUrl = '',
    String lastEpisodeName = '',
    int lastKnownEpisodeCount = 0,
    String estado = '',
  }) async {
    final db = _database;
    final existing = await db.getAnime(url);

    // Preserve existing count when caller sends 0
    int count = lastKnownEpisodeCount;
    if (count == 0) {
      if (existing != null) count = existing.epCount;
    }
    // Prefer Mi Lista's cover when available — it's the user-confirmed one.
    // Falls back to the caller-provided image, then to whatever the history
    // row already held. This prevents stale S1 covers from overriding a
    // correct S2 cover already saved in Mi Lista.
    final myListEntry = await db.getMyListEntry(url);
    final myListImg = myListEntry?.imagen ?? '';
    final safeImage = myListImg.isNotEmpty
        ? myListImg
        : (imagen.isNotEmpty ? imagen : (existing?.imagen ?? ''));
    final safeStatus = estado.isNotEmpty ? estado : (existing?.estado ?? '');

    await db.upsertAnime(
      AnimeHistoryCompanion.insert(
        url: url,
        titulo: titulo,
        imagen: Value(safeImage),
        lastEpUrl: Value(lastEpisodeUrl),
        lastEpName: Value(lastEpisodeName),
        epCount: Value(count),
        estado: Value(safeStatus),
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _pushCloudIfLoggedIn();
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final rows = await _database.allHistory();
    return rows
        .map((r) => {
              'titulo': r.titulo,
              'url': r.url,
              'imagen': r.imagen,
              'lastEpisodeUrl': r.lastEpUrl,
              'lastEpisodeName': r.lastEpName,
              'lastKnownEpisodeCount': r.epCount,
              'estado': r.estado,
              'timestamp': r.ts,
            })
        .toList();
  }

  static Future<void> remove(String url) async {
    if (url.isEmpty) return;
    await _database.removeAnime(url);
    await _pushCloudIfLoggedIn();
  }

  static Future<void> clear() async {
    await _database.clearHistory();
    await _pushCloudIfLoggedIn();
  }

  // --------------- Episode-level (watched checkmarks) ---------------

  static Future<void> markEpisodeWatched(String episodeUrl) async {
    if (episodeUrl.isEmpty) return;
    await _database.markWatched(episodeUrl);
    await _pushCloudIfLoggedIn();
  }

  static Future<void> unmarkEpisodeWatched(String episodeUrl) async {
    if (episodeUrl.isEmpty) return;
    await _database.unmarkWatched(episodeUrl);
    await _pushCloudIfLoggedIn();
  }

  static Future<Set<String>> getWatchedEpisodes() => _database.watchedSet();

  static Future<void> clearWatchedEpisodes() async {
    await _database.clearWatchedEpisodes();
    await _pushCloudIfLoggedIn();
  }

  static Future<String?> getLastEpisodeUrl(String contentUrl) async {
    final entry = await _database.getAnime(contentUrl);
    return entry?.lastEpUrl;
  }

  // --------------- Episode progress (resume from last point) ---------------

  static Future<void> saveEpisodeProgress({
    required String episodeUrl,
    required double position,
    required double duration,
  }) async {
    if (episodeUrl.isEmpty || duration <= 0) return;
    await _database.saveProgress(
      episodeUrl: episodeUrl,
      position: position,
      duration: duration,
    );
    await _pushCloudIfLoggedIn();
  }

  static Future<double?> getEpisodeProgress(String episodeUrl) async {
    if (episodeUrl.isEmpty) return null;
    return _database.getProgress(episodeUrl);
  }

  static Future<void> clearEpisodeProgress(String episodeUrl) async {
    if (episodeUrl.isEmpty) return;
    await _database.clearProgress(episodeUrl);
    await _pushCloudIfLoggedIn();
  }

  /// Returns all episode URLs that have a saved progress position.
  /// Used by home_screen enrichment to avoid re-reading SharedPreferences.
  static Future<Set<String>> episodesWithProgress() =>
      _database.episodesWithProgress();

  /// Returns all progress entries as {episodeUrl → {position, duration}}.
  /// Used by the "Continuar Viendo" row to render progress bars.
  static Future<Map<String, Map<String, double>>> getAllProgress() =>
      _database.allProgressEntries();

  // --------------- Listings cache (offline fallback) ---------------

  /// Returns the raw JSON string stored for [key], or null if not cached.
  static Future<String?> getListingCache(String key) =>
      _database.getCachedListing(key);

  /// Persists [json] for [key], replacing any previous entry.
  static Future<void> saveListingCache(String key, String json) =>
      _database.saveListing(key, json);

  // --------------- My List (Favorites with status) ---------------

  static Future<List<Map<String, dynamic>>> getMyList() async {
    final rows = await _database.getAllMyList();
    return rows
        .map((r) => {
              'animeUrl': r.contentUrl,
              'titulo': r.titulo,
              'imagen': r.imagen,
              'status': r.status,
              'episodesWatched': r.episodesWatched,
              'totalEpisodes': r.totalEpisodes,
              'ts': r.ts,
            })
        .toList();
  }

  static Future<String?> getMyListStatus(String contentUrl) async {
    final entry = await _database.getMyListEntry(contentUrl);
    return entry?.status;
  }

  static Future<void> saveToMyList({
    required String contentUrl,
    required String titulo,
    required String imagen,
    required String status,
    required int episodesWatched,
    required int totalEpisodes,
  }) async {
    await _database.upsertMyListEntry(
      MyListEntriesCompanion.insert(
        contentUrl: contentUrl,
        titulo: titulo,
        imagen: Value(imagen),
        status: status,
        episodesWatched: Value(episodesWatched),
        totalEpisodes: Value(totalEpisodes),
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _pushCloudIfLoggedIn();
  }

  static Future<void> removeFromMyList(String contentUrl) async {
    await _database.removeMyListEntry(contentUrl);
    await _pushCloudIfLoggedIn();
  }

  /// Updates only the stored cover image for an existing Mi Lista entry.
  /// No-ops if the entry doesn't exist or the image is already up to date.
  static Future<void> updateMyListImage(String contentUrl, String imagen) async {
    if (imagen.isEmpty) return;
    final entry = await _database.getMyListEntry(contentUrl);
    if (entry == null || entry.imagen == imagen) return;
    await _database.upsertMyListEntry(
      MyListEntriesCompanion(
        contentUrl: Value(entry.contentUrl),
        titulo: Value(entry.titulo),
        imagen: Value(imagen),
        status: Value(entry.status),
        episodesWatched: Value(entry.episodesWatched),
        totalEpisodes: Value(entry.totalEpisodes),
        ts: Value(entry.ts),
      ),
    );
  }

  static Future<void> clearMyList() async {
    await _database.clearMyList();
    await _pushCloudIfLoggedIn();
  }

  static Future<void> clearAllEpisodeProgress() async {
    await _database.clearAllEpisodeProgress();
    await _pushCloudIfLoggedIn();
  }

  /// Automatically increment watched episodes if the content is in My List.
  /// Auto-sets 'completado' only when [contentIsFinished] is true.
  static Future<void> handleEpisodeFinished(
    String contentUrl, {
    bool contentIsFinished = false,
  }) async {
    final entry = await _database.getMyListEntry(contentUrl);
    // User condition: Do not auto-add if it's not in the list.
    if (entry == null) return;

    int newWatched = entry.episodesWatched + 1;
    String newStatus = entry.status;

    // Cap at current known total.
    if (entry.totalEpisodes > 0 && newWatched >= entry.totalEpisodes) {
      newWatched = entry.totalEpisodes;
      if (contentIsFinished) {
        newStatus = 'completado';
      } else if (newStatus == 'planeado') {
        newStatus = 'en_proceso';
      }
    } else if (newStatus == 'planeado' && newWatched > 0) {
      // If they started watching a planned title, it's now in process
      newStatus = 'en_proceso';
    }

    await _database.upsertMyListEntry(
      MyListEntriesCompanion.insert(
        contentUrl: entry.contentUrl,
        titulo: entry.titulo,
        imagen: Value(entry.imagen),
        status: newStatus,
        episodesWatched: Value(newWatched),
        totalEpisodes: Value(entry.totalEpisodes),
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _pushCloudIfLoggedIn();
  }

  /// Reconciles My List progress using the real watched count from episodes UI.
  /// Useful to keep My List in sync when users manually toggle watched/unwatched.
  static Future<void> syncMyListEpisodeCount({
    required String contentUrl,
    required int watchedCount,
    required int totalEpisodes,
    bool contentIsFinished = false,
  }) async {
    final entry = await _database.getMyListEntry(contentUrl);
    if (entry == null) return;

    final safeWatched =
        watchedCount.clamp(0, totalEpisodes > 0 ? totalEpisodes : watchedCount);
    String newStatus = entry.status;
    if (safeWatched > 0 && newStatus == 'planeado') {
      newStatus = 'en_proceso';
    }
    if (contentIsFinished && totalEpisodes > 0 && safeWatched >= totalEpisodes) {
      newStatus = 'completado';
    }

    await _database.upsertMyListEntry(
      MyListEntriesCompanion.insert(
        contentUrl: entry.contentUrl,
        titulo: entry.titulo,
        imagen: Value(entry.imagen),
        status: newStatus,
        episodesWatched: Value(safeWatched),
        totalEpisodes:
            Value(totalEpisodes > 0 ? totalEpisodes : entry.totalEpisodes),
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _pushCloudIfLoggedIn();
  }

  /// Payload format version. v1 = legacy (no per-entry timestamps, no
  /// tombstones). v2 = current (each entry carries `updatedAt` / `deletedAt`,
  /// tombstoned rows are included so deletions propagate across devices).
  static const int _syncPayloadVersion = 2;

  static Future<Map<String, dynamic>> exportSyncPayload() async {
    final db = _database;
    final myListRows = await db.allMyListRaw();
    final historyRows = await db.allHistoryRaw();
    final progressRows = await db.allProgressRaw();
    final watchedRows = await db.allWatchedRaw();

    return {
      'version': _syncPayloadVersion,
      'myList': [
        for (final r in myListRows)
          {
            'animeUrl': r.contentUrl,
            'titulo': r.titulo,
            'imagen': r.imagen,
            'status': r.status,
            'episodesWatched': r.episodesWatched,
            'totalEpisodes': r.totalEpisodes,
            'ts': r.ts,
            'updatedAt': r.updatedAt,
            'deletedAt': r.deletedAt,
          },
      ],
      'history': [
        for (final r in historyRows)
          {
            'url': r.url,
            'titulo': r.titulo,
            'imagen': r.imagen,
            'lastEpisodeUrl': r.lastEpUrl,
            'lastEpisodeName': r.lastEpName,
            'lastKnownEpisodeCount': r.epCount,
            'estado': r.estado,
            'timestamp': r.ts,
            'updatedAt': r.updatedAt,
            'deletedAt': r.deletedAt,
          },
      ],
      'progress': [
        for (final r in progressRows)
          {
            'episodeUrl': r.episodeUrl,
            'position': r.position,
            'duration': r.duration,
            'ts': r.ts,
            'updatedAt': r.updatedAt,
            'deletedAt': r.deletedAt,
          },
      ],
      'watched': [
        for (final r in watchedRows)
          {
            'episodeUrl': r.episodeUrl,
            'updatedAt': r.updatedAt,
            'deletedAt': r.deletedAt,
          },
      ],
      'syncedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Merges [remote] into local state using last-write-wins per entry on
  /// `updatedAt`. Tombstones (`deletedAt != null`) are applied as soft-deletes
  /// so removals propagate across devices. Legacy v1 payloads (no per-entry
  /// timestamps) are handled by treating `syncedAt` as every entry's
  /// `updatedAt` and assuming no tombstones — good enough as a one-time
  /// migration into v2.
  static Future<void> mergeSyncPayload(Map<String, dynamic> remote) async {
    _isImporting = true;
    try {
      final db = _database;
      final version = (remote['version'] as num?)?.toInt() ?? 1;
      final isLegacy = version < 2;
      final legacyTs = (remote['syncedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;

      // ── My List ───────────────────────────────────────────────────────
      final myList =
          (remote['myList'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final r in myList) {
        await db.mergeApplyMyList(
          contentUrl: (r['animeUrl'] ?? '').toString(),
          titulo: (r['titulo'] ?? '').toString(),
          imagen: (r['imagen'] ?? '').toString(),
          status: (r['status'] ?? 'planeado').toString(),
          episodesWatched: (r['episodesWatched'] as num?)?.toInt() ?? 0,
          totalEpisodes: (r['totalEpisodes'] as num?)?.toInt() ?? 0,
          ts: (r['ts'] as num?)?.toInt() ?? legacyTs,
          updatedAt:
              isLegacy ? legacyTs : ((r['updatedAt'] as num?)?.toInt() ?? 0),
          deletedAt: isLegacy ? null : (r['deletedAt'] as num?)?.toInt(),
        );
      }

      // ── History ───────────────────────────────────────────────────────
      final history =
          (remote['history'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      for (final r in history) {
        await db.mergeApplyAnime(
          url: (r['url'] ?? '').toString(),
          titulo: (r['titulo'] ?? '').toString(),
          imagen: (r['imagen'] ?? '').toString(),
          lastEpUrl: (r['lastEpisodeUrl'] ?? '').toString(),
          lastEpName: (r['lastEpisodeName'] ?? '').toString(),
          epCount: (r['lastKnownEpisodeCount'] as num?)?.toInt() ?? 0,
          estado: (r['estado'] ?? '').toString(),
          ts: (r['timestamp'] as num?)?.toInt() ?? legacyTs,
          updatedAt:
              isLegacy ? legacyTs : ((r['updatedAt'] as num?)?.toInt() ?? 0),
          deletedAt: isLegacy ? null : (r['deletedAt'] as num?)?.toInt(),
        );
      }

      // ── Progress ──────────────────────────────────────────────────────
      // Legacy payloads stored this as a Map<episodeUrl, {position,duration}>.
      // v2 stores it as a List<Map> with full metadata.
      final progressNode = remote['progress'];
      if (progressNode is Map) {
        // Legacy map form.
        final map = progressNode.cast<String, dynamic>();
        for (final entry in map.entries) {
          final v = (entry.value as Map?)?.cast<String, dynamic>() ?? const {};
          await db.mergeApplyProgress(
            episodeUrl: entry.key,
            position: (v['position'] as num?)?.toDouble() ?? 0,
            duration: (v['duration'] as num?)?.toDouble() ?? 0,
            ts: legacyTs,
            updatedAt: legacyTs,
            deletedAt: null,
          );
        }
      } else if (progressNode is List) {
        for (final raw in progressNode) {
          final r = (raw as Map?)?.cast<String, dynamic>() ?? const {};
          await db.mergeApplyProgress(
            episodeUrl: (r['episodeUrl'] ?? '').toString(),
            position: (r['position'] as num?)?.toDouble() ?? 0,
            duration: (r['duration'] as num?)?.toDouble() ?? 0,
            ts: (r['ts'] as num?)?.toInt() ?? legacyTs,
            updatedAt:
                isLegacy ? legacyTs : ((r['updatedAt'] as num?)?.toInt() ?? 0),
            deletedAt: isLegacy ? null : (r['deletedAt'] as num?)?.toInt(),
          );
        }
      }

      // ── Watched ───────────────────────────────────────────────────────
      // Legacy: List<String>. v2: List<Map>.
      final watchedNode = remote['watched'];
      if (watchedNode is List) {
        for (final raw in watchedNode) {
          if (raw is String) {
            await db.mergeApplyWatched(
              episodeUrl: raw,
              updatedAt: legacyTs,
              deletedAt: null,
            );
          } else if (raw is Map) {
            final r = raw.cast<String, dynamic>();
            await db.mergeApplyWatched(
              episodeUrl: (r['episodeUrl'] ?? '').toString(),
              updatedAt: isLegacy
                  ? legacyTs
                  : ((r['updatedAt'] as num?)?.toInt() ?? 0),
              deletedAt: isLegacy ? null : (r['deletedAt'] as num?)?.toInt(),
            );
          }
        }
      }
    } finally {
      _isImporting = false;
    }
  }

  /// Kept for backward compatibility. Delegates to [mergeSyncPayload].
  @Deprecated('Use mergeSyncPayload — import semantics are now a proper merge.')
  static Future<void> importSyncPayload(Map<String, dynamic> payload) =>
      mergeSyncPayload(payload);

  /// Prefs key holding the last cloud version this client successfully
  /// observed. Used for optimistic concurrency — we send it as
  /// `expected_version` on upload; server returns 409 if another device
  /// already raced us, and we re-merge + retry once.
  static const String _kCloudVersionKey = 'cloud_sync_version';

  static Future<int> _loadCloudVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kCloudVersionKey) ?? 0;
  }

  static Future<void> saveCloudVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCloudVersionKey, version);
  }

  static Future<void> clearCloudVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCloudVersionKey);
  }

  /// Uploads the current local payload to the cloud with optimistic
  /// concurrency. On 409 (another device wrote first), re-downloads +
  /// re-merges + retries once. Returns true if the server accepted the
  /// write. Silent on failure — local DB remains authoritative.
  static Future<bool> pushToCloudWithRetry(String token) async {
    try {
      final expected = await _loadCloudVersion();
      final payload = await exportSyncPayload();
      final counts = _payloadCounts(payload);
      debugPrint('[SYNC] push expectedVersion=$expected counts=$counts');
      final result = await UserSyncService.uploadState(
        token,
        payload,
        expectedVersion: expected,
      );
      if (result.ok) {
        if (result.version != null) {
          await saveCloudVersion(result.version!);
        }
        debugPrint('[SYNC] push OK newVersion=${result.version}');
        return true;
      }
      if (!result.conflict) {
        debugPrint('[SYNC] push FAILED non-conflict');
        return false;
      }

      debugPrint(
          '[SYNC] push CONFLICT serverVersion=${result.currentServerVersion} — re-download + merge + retry');
      final remote = await UserSyncService.downloadState(token);
      if (remote == null) return false;
      final remotePayload =
          (remote['payload'] as Map?)?.cast<String, dynamic>();
      final serverVersion = (remote['version'] as num?)?.toInt() ?? 0;
      if (remotePayload != null) {
        debugPrint(
            '[SYNC] conflict-merge remoteCounts=${_payloadCounts(remotePayload)}');
        await mergeSyncPayload(remotePayload);
      }
      await saveCloudVersion(serverVersion);

      final mergedPayload = await exportSyncPayload();
      final retry = await UserSyncService.uploadState(
        token,
        mergedPayload,
        expectedVersion: serverVersion,
      );
      if (retry.ok && retry.version != null) {
        await saveCloudVersion(retry.version!);
      }
      debugPrint(
          '[SYNC] push retry ok=${retry.ok} newVersion=${retry.version}');
      return retry.ok;
    } catch (e, st) {
      debugPrint('[SYNC] push THREW: $e\n$st');
      return false;
    }
  }

  static Map<String, int> _payloadCounts(Map<String, dynamic> p) {
    int listLen(dynamic v) => v is List ? v.length : 0;
    int mapOrList(dynamic v) {
      if (v is List) return v.length;
      if (v is Map) return v.length;
      return 0;
    }

    return {
      'v': (p['version'] as num?)?.toInt() ?? 1,
      'myList': listLen(p['myList']),
      'history': listLen(p['history']),
      'progress': mapOrList(p['progress']),
      'watched': listLen(p['watched']),
    };
  }

  static Future<void> _pushCloudIfLoggedIn() async {
    if (_isImporting || _suppressCloudPush) return;
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString('auth_status');
    final token = prefs.getString('auth_token');
    if (status != 'authenticated' || token == null || token.isEmpty) return;
    await pushToCloudWithRetry(token);
  }

  static Future<T> runWithoutCloudSync<T>(Future<T> Function() action) async {
    _suppressCloudPush = true;
    try {
      return await action();
    } finally {
      _suppressCloudPush = false;
    }
  }

  /// Hard-wipes every synced table. Used ONLY for account-isolation scenarios
  /// (logout/account-switch) where we must not leave tombstones that could
  /// sync to the next account. For user-initiated wipes, use clear*.
  static Future<void> hardClearAllSyncedData() async {
    final db = _database;
    await db.hardClearHistory();
    await db.hardClearMyList();
    await db.hardClearAllEpisodeProgress();
    await db.hardClearWatchedEpisodes();
  }
}

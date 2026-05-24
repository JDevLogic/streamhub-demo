import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'watch_database.g.dart';

// ── Table definitions ────────────────────────────────────────────────────────

class AnimeHistory extends Table {
  TextColumn get url => text()();
  TextColumn get titulo => text()();
  TextColumn get imagen => text().withDefault(const Constant(''))();
  TextColumn get lastEpUrl => text().withDefault(const Constant(''))();
  TextColumn get lastEpName => text().withDefault(const Constant(''))();
  IntColumn get epCount => integer().withDefault(const Constant(0))();
  TextColumn get estado => text().withDefault(const Constant(''))();
  IntColumn get ts => integer()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {url};
}

class WatchedEpisodes extends Table {
  TextColumn get episodeUrl => text()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {episodeUrl};
}

class EpisodeProgress extends Table {
  TextColumn get episodeUrl => text()();
  RealColumn get position => real()();
  RealColumn get duration => real()();
  IntColumn get ts => integer()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {episodeUrl};
}

class ListingsCache extends Table {
  TextColumn get key      => text()();
  TextColumn get dataJson => text()();
  IntColumn  get ts       => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

class MyListEntries extends Table {
  TextColumn get contentUrl => text()();
  TextColumn get titulo => text()();
  TextColumn get imagen => text().withDefault(const Constant(''))();
  TextColumn get status => text()(); // 'en_proceso', 'planeado', 'completado', 'en_espera', 'abandonado'
  IntColumn get episodesWatched => integer().withDefault(const Constant(0))();
  IntColumn get totalEpisodes => integer().withDefault(const Constant(0))();
  IntColumn get ts => integer()(); // timestamp of last update
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {contentUrl};
}

// ── Database class ────────────────────────────────────────────────────────────

@DriftDatabase(tables: [AnimeHistory, WatchedEpisodes, EpisodeProgress, ListingsCache, MyListEntries])
class WatchDatabase extends _$WatchDatabase {
  WatchDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(listingsCache);
      if (from < 3) await m.createTable(myListEntries);
      if (from < 4) {
        await m.addColumn(animeHistory, animeHistory.estado);
      }
      if (from < 5) {
        await m.addColumn(animeHistory, animeHistory.updatedAt);
        await m.addColumn(animeHistory, animeHistory.deletedAt);
        await m.addColumn(watchedEpisodes, watchedEpisodes.updatedAt);
        await m.addColumn(watchedEpisodes, watchedEpisodes.deletedAt);
        await m.addColumn(episodeProgress, episodeProgress.updatedAt);
        await m.addColumn(episodeProgress, episodeProgress.deletedAt);
        await m.addColumn(myListEntries, myListEntries.updatedAt);
        await m.addColumn(myListEntries, myListEntries.deletedAt);
        // Backfill updatedAt so existing rows participate correctly in the
        // first merge. Tables with a `ts` column reuse it; watched_episodes
        // has no timestamp, so we stamp it with the migration time.
        final now = DateTime.now().millisecondsSinceEpoch;
        await customStatement('UPDATE anime_history SET updated_at = ts');
        await customStatement('UPDATE episode_progress SET updated_at = ts');
        await customStatement('UPDATE my_list_entries SET updated_at = ts');
        await customStatement(
          'UPDATE watched_episodes SET updated_at = ?',
          [now],
        );
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'watch_history');
  }

  // ── One-time migration from SharedPreferences ──────────────────────────

  /// Runs once on first launch after upgrade. Moves all data from
  /// SharedPreferences JSON blobs into SQLite. Idempotent.
  Future<void> migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('_wh_migrated_v1') == true) return;

    await transaction(() async {
      // Anime history
      final rawHistory = prefs.getString('watch_history');
      if (rawHistory != null && rawHistory.isNotEmpty) {
        try {
          final list = jsonDecode(rawHistory) as List<dynamic>;
          for (final e in list.cast<Map<String, dynamic>>()) {
            final ts = (e['timestamp'] as int?) ?? 0;
            await into(animeHistory).insertOnConflictUpdate(
              AnimeHistoryCompanion.insert(
                url:        e['url']?.toString() ?? '',
                titulo:     e['titulo']?.toString() ?? '',
                imagen:     Value(e['imagen']?.toString() ?? ''),
                lastEpUrl:  Value(e['lastEpisodeUrl']?.toString() ?? ''),
                lastEpName: Value(e['lastEpisodeName']?.toString() ?? ''),
                epCount:    Value((e['lastKnownEpisodeCount'] as int?) ?? 0),
                ts:         ts,
                updatedAt:  Value(ts),
              ),
            );
          }
        } catch (_) {}
      }

      // Watched episodes
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final url in prefs.getStringList('watched_episodes') ?? []) {
        await into(watchedEpisodes).insertOnConflictUpdate(
          WatchedEpisodesCompanion.insert(
            episodeUrl: url,
            updatedAt: Value(now),
          ),
        );
      }

      // Episode progress
      final rawProgress = prefs.getString('episode_progress');
      if (rawProgress != null && rawProgress.isNotEmpty) {
        try {
          final map = jsonDecode(rawProgress) as Map<String, dynamic>;
          for (final entry in map.entries) {
            final v = entry.value as Map<String, dynamic>;
            final ts = (v['timestamp'] as int?) ?? 0;
            await into(episodeProgress).insertOnConflictUpdate(
              EpisodeProgressCompanion.insert(
                episodeUrl: entry.key,
                position:   (v['position'] as num?)?.toDouble() ?? 0.0,
                duration:   (v['duration'] as num?)?.toDouble() ?? 0.0,
                ts:         ts,
                updatedAt:  Value(ts),
              ),
            );
          }
        } catch (_) {}
      }
    });

    await prefs.setBool('_wh_migrated_v1', true);
  }

  // ── Anime history queries ─────────────────────────────────────────────────

  Future<List<AnimeHistoryData>> allHistory({int limit = 30}) {
    return (select(animeHistory)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.ts)])
          ..limit(limit))
        .get();
    }

  Future<void> upsertAnime(AnimeHistoryCompanion entry) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Stamp updatedAt and clear any tombstone so a re-added anime
    // "un-deletes" correctly across devices during merge.
    final stamped = entry.copyWith(
      updatedAt: Value(now),
      deletedAt: const Value(null),
    );
    await into(animeHistory).insertOnConflictUpdate(stamped);
    // Keep only the last 30 live entries (tombstones don't count toward cap).
    final oldest = await (select(animeHistory)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.ts)])
          ..limit(1, offset: 30))
        .get();
    if (oldest.isNotEmpty) {
      await (delete(animeHistory)
            ..where((t) => t.ts.isSmallerOrEqualValue(oldest.first.ts) & t.deletedAt.isNull()))
          .go();
    }
  }

  Future<AnimeHistoryData?> getAnime(String url) {
    return (select(animeHistory)
          ..where((t) => t.url.equals(url) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> removeAnime(String url) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(animeHistory)..where((t) => t.url.equals(url))).write(
      AnimeHistoryCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  /// Soft-clears every live history row. Used for user-initiated wipes.
  Future<void> clearHistory() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(animeHistory)..where((t) => t.deletedAt.isNull())).write(
      AnimeHistoryCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  /// Hard-deletes every history row. Used only for account-isolation wipes
  /// where we must NOT leave tombstones that could sync to the next account.
  Future<void> hardClearHistory() => delete(animeHistory).go();

  // ── Watched episodes queries ──────────────────────────────────────────────

  Future<void> markWatched(String episodeUrl) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(watchedEpisodes).insertOnConflictUpdate(
      WatchedEpisodesCompanion(
        episodeUrl: Value(episodeUrl),
        updatedAt: Value(now),
        deletedAt: const Value(null),
      ),
    );
    // Clear any stale resume-progress row for this episode so it doesn't
    // keep the anime pinned in "Continuar viendo" after it's been watched.
    await clearProgress(episodeUrl);
  }

  Future<void> unmarkWatched(String episodeUrl) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(watchedEpisodes)..where((t) => t.episodeUrl.equals(episodeUrl))).write(
      WatchedEpisodesCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  Future<void> clearWatchedEpisodes() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(watchedEpisodes)..where((t) => t.deletedAt.isNull())).write(
      WatchedEpisodesCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  Future<void> hardClearWatchedEpisodes() => delete(watchedEpisodes).go();

  Future<Set<String>> watchedSet() async {
    final rows = await (select(watchedEpisodes)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return rows.map((r) => r.episodeUrl).toSet();
  }

  // ── Episode progress queries ──────────────────────────────────────────────

  Future<void> saveProgress({
    required String episodeUrl,
    required double position,
    required double duration,
  }) async {
    // Only save meaningful positions. Near-start or near-end positions are
    // silently ignored — callers use clearProgress() explicitly when they
    // want to remove an entry (e.g. when episode is marked as watched).
    // This prevents transient position=0 events (common with libmpv on HTTP
    // streams after seek) from accidentally erasing saved resume points.
    final isNearStart = position <= 5;
    final isNearEnd =
        position >= duration * 0.90 || (duration - position) <= 60;

    if (isNearStart || isNearEnd) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await into(episodeProgress).insertOnConflictUpdate(
      EpisodeProgressCompanion(
        episodeUrl: Value(episodeUrl),
        position:   Value(position),
        duration:   Value(duration),
        ts:         Value(now),
        updatedAt:  Value(now),
        deletedAt:  const Value(null),
      ),
    );
  }

  Future<double?> getProgress(String episodeUrl) async {
    final row = await (select(episodeProgress)
          ..where((t) => t.episodeUrl.equals(episodeUrl) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;

    final isNearEnd =
        row.position >= row.duration * 0.90 ||
        (row.duration - row.position) <= 60;
    if (isNearEnd) {
      await clearProgress(episodeUrl);
      return null;
    }

    final pos = row.position;
    if (!pos.isFinite || pos <= 0) return null;
    return pos;
  }

  Future<void> clearProgress(String episodeUrl) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(episodeProgress)..where((t) => t.episodeUrl.equals(episodeUrl))).write(
      EpisodeProgressCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  /// Returns URLs of all episodes that have a saved progress position.
  Future<Set<String>> episodesWithProgress() async {
    final rows = await (select(episodeProgress)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final valid = rows.where((r) {
      if (r.duration <= 0) return false;
      final nearEnd =
          r.position >= r.duration * 0.90 ||
          (r.duration - r.position) <= 60;
      return !nearEnd && r.position > 5;
    });
    return valid.map((r) => r.episodeUrl).toSet();
  }

  /// Returns all progress entries keyed by episodeUrl.
  Future<Map<String, Map<String, double>>> allProgressEntries() async {
    final rows = await (select(episodeProgress)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return {
      for (final r in rows)
        if (r.duration > 0 &&
            r.position > 5 &&
            r.position < r.duration * 0.90 &&
            (r.duration - r.position) > 60)
        r.episodeUrl: {'position': r.position, 'duration': r.duration, 'updatedAt': r.updatedAt.toDouble()},
    };
  }

  // ── Listings cache queries ────────────────────────────────────────────────

  Future<String?> getCachedListing(String key) async {
    final row = await (select(listingsCache)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.dataJson;
  }

  Future<void> saveListing(String key, String json) {
    return into(listingsCache).insertOnConflictUpdate(
      ListingsCacheCompanion.insert(
        key:      key,
        dataJson: json,
        ts:       DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  // ── MyList queries ────────────────────────────────────────────────────────

  Future<List<MyListEntry>> getAllMyList() {
    return (select(myListEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.ts)]))
        .get();
  }

  Future<MyListEntry?> getMyListEntry(String url) {
    return (select(myListEntries)
          ..where((t) => t.contentUrl.equals(url) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> upsertMyListEntry(MyListEntriesCompanion entry) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stamped = entry.copyWith(
      updatedAt: Value(now),
      deletedAt: const Value(null),
    );
    return into(myListEntries).insertOnConflictUpdate(stamped);
  }

  Future<void> removeMyListEntry(String url) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(myListEntries)..where((t) => t.contentUrl.equals(url))).write(
      MyListEntriesCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  Future<void> clearMyList() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(myListEntries)..where((t) => t.deletedAt.isNull())).write(
      MyListEntriesCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  Future<void> hardClearMyList() => delete(myListEntries).go();

  Future<void> clearAllEpisodeProgress() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(episodeProgress)..where((t) => t.deletedAt.isNull())).write(
      EpisodeProgressCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  Future<void> hardClearAllEpisodeProgress() => delete(episodeProgress).go();

  // ── Sync export (raw, including tombstones) ───────────────────────────────

  Future<List<AnimeHistoryData>> allHistoryRaw() =>
      select(animeHistory).get();

  Future<List<MyListEntry>> allMyListRaw() =>
      select(myListEntries).get();

  Future<List<EpisodeProgressData>> allProgressRaw() =>
      select(episodeProgress).get();

  Future<List<WatchedEpisode>> allWatchedRaw() =>
      select(watchedEpisodes).get();

  // ── Merge-apply (last-write-wins per entry) ───────────────────────────────

  /// Applies a remote anime-history row. No-op when local `updatedAt` is
  /// strictly greater — on a tie, remote wins (idempotent re-application).
  Future<void> mergeApplyAnime({
    required String url,
    required String titulo,
    required String imagen,
    required String lastEpUrl,
    required String lastEpName,
    required int epCount,
    required String estado,
    required int ts,
    required int updatedAt,
    required int? deletedAt,
  }) async {
    if (url.isEmpty) return;
    final local = await (select(animeHistory)..where((t) => t.url.equals(url)))
        .getSingleOrNull();
    if (local != null && local.updatedAt > updatedAt) return;
    await into(animeHistory).insertOnConflictUpdate(
      AnimeHistoryCompanion(
        url:        Value(url),
        titulo:     Value(titulo),
        imagen:     Value(imagen),
        lastEpUrl:  Value(lastEpUrl),
        lastEpName: Value(lastEpName),
        epCount:    Value(epCount),
        estado:     Value(estado),
        ts:         Value(ts),
        updatedAt:  Value(updatedAt),
        deletedAt:  Value(deletedAt),
      ),
    );
  }

  Future<void> mergeApplyMyList({
    required String contentUrl,
    required String titulo,
    required String imagen,
    required String status,
    required int episodesWatched,
    required int totalEpisodes,
    required int ts,
    required int updatedAt,
    required int? deletedAt,
  }) async {
    if (contentUrl.isEmpty) return;
    final local = await (select(myListEntries)
          ..where((t) => t.contentUrl.equals(contentUrl)))
        .getSingleOrNull();
    if (local != null && local.updatedAt > updatedAt) return;
    await into(myListEntries).insertOnConflictUpdate(
      MyListEntriesCompanion(
        contentUrl:        Value(contentUrl),
        titulo:          Value(titulo),
        imagen:          Value(imagen),
        status:          Value(status),
        episodesWatched: Value(episodesWatched),
        totalEpisodes:   Value(totalEpisodes),
        ts:              Value(ts),
        updatedAt:       Value(updatedAt),
        deletedAt:       Value(deletedAt),
      ),
    );
  }

  Future<void> mergeApplyProgress({
    required String episodeUrl,
    required double position,
    required double duration,
    required int ts,
    required int updatedAt,
    required int? deletedAt,
  }) async {
    if (episodeUrl.isEmpty) return;
    final local = await (select(episodeProgress)
          ..where((t) => t.episodeUrl.equals(episodeUrl)))
        .getSingleOrNull();
    if (local != null && local.updatedAt > updatedAt) return;
    await into(episodeProgress).insertOnConflictUpdate(
      EpisodeProgressCompanion(
        episodeUrl: Value(episodeUrl),
        position:   Value(position),
        duration:   Value(duration),
        ts:         Value(ts),
        updatedAt:  Value(updatedAt),
        deletedAt:  Value(deletedAt),
      ),
    );
  }

  Future<void> mergeApplyWatched({
    required String episodeUrl,
    required int updatedAt,
    required int? deletedAt,
  }) async {
    if (episodeUrl.isEmpty) return;
    final local = await (select(watchedEpisodes)
          ..where((t) => t.episodeUrl.equals(episodeUrl)))
        .getSingleOrNull();
    if (local != null && local.updatedAt > updatedAt) return;
    await into(watchedEpisodes).insertOnConflictUpdate(
      WatchedEpisodesCompanion(
        episodeUrl: Value(episodeUrl),
        updatedAt:  Value(updatedAt),
        deletedAt:  Value(deletedAt),
      ),
    );
  }
}

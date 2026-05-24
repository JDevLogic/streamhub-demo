import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/content_service.dart';
import '../services/watch_history.dart';

/// Single shared instance — all call sites read from this provider.
final contentServiceProvider = Provider<ContentService>((ref) => ContentService());

// ── Listing cache keys ────────────────────────────────────────────────────────

const _kLatestKey   = 'listing_latest_episodes';
const _kOnAirKey    = 'listing_on_air';
const _kCatalogKey  = 'listing_catalog';

// ── Helper ────────────────────────────────────────────────────────────────────

/// Network-first fetch with offline fallback.
/// On success the response is persisted to the Drift listings cache.
/// On failure the last cached JSON is returned; if nothing was ever cached,
/// the original exception is rethrown (visible to the UI as an error state).
Future<List<Map<String, dynamic>>> _fetchWithCache(
  String cacheKey,
  Future<List<Map<String, dynamic>>> Function() fetch,
) async {
  try {
    final data = await fetch();
    await WatchHistory.saveListingCache(cacheKey, jsonEncode(data));
    return data;
  } catch (_) {
    final cached = await WatchHistory.getListingCache(cacheKey);
    if (cached != null) {
      return (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    }
    rethrow;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Cached across navigations — only re-fetches when explicitly invalidated
/// (e.g. pull-to-refresh) or when the ProviderScope is disposed.
/// Falls back to last cached data when offline.

final latestEpisodesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchWithCache(
    _kLatestKey,
    ref.watch(contentServiceProvider).getLatestEpisodes,
  ),
);

final onAirProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchWithCache(
    _kOnAirKey,
    ref.watch(contentServiceProvider).getOnAir,
  ),
);

final catalogProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchWithCache(
    _kCatalogKey,
    ref.watch(contentServiceProvider).getCatalog,
  ),
);

/// Keyed by content URL — each URL gets its own cached entry.
/// Detail pages are not cached offline (too many URLs, lower priority).
final detailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, url) => ref.watch(contentServiceProvider).getDetail(url),
);

// Tab-visibility signals — incremented by MainNavigationScreen when the user
// switches to that tab so screens can refresh without RouteAware tricks.
final homeTabRefreshProvider    = StateProvider<int>((ref) => 0);
final miListaTabRefreshProvider = StateProvider<int>((ref) => 0);

/// Contenido filtrado por género en modo demo.
/// autoDispose: se libera al salir del género — cache reside en el servidor.
final byGenreProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, genero) =>
      ref.watch(contentServiceProvider).getByGenre(genero),
);

/// Live episode count for a specific content URL.
/// Used by detail screen to avoid stale `episodios_count` from detail cache.
final episodeCountProvider =
    FutureProvider.autoDispose.family<int, String>(
  (ref, url) async {
    final eps = await ref.watch(contentServiceProvider).getEpisodes(url);
    return eps.length;
  },
);

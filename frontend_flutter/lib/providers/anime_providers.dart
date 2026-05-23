import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/anime_service.dart';
import '../services/watch_history.dart';

/// Single shared instance — all call sites read from this provider.
final animeServiceProvider = Provider<AnimeService>((ref) => AnimeService());

// ── Listing cache keys ────────────────────────────────────────────────────────

const _kUltimosKey  = 'listing_ultimos_episodios';
const _kEmisionKey  = 'listing_en_emision';
const _kAgregadosKey = 'listing_animes_agregados';

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

final ultimosEpisodiosProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchWithCache(
    _kUltimosKey,
    ref.watch(animeServiceProvider).getUltimosEpisodios,
  ),
);

final enEmisionProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchWithCache(
    _kEmisionKey,
    ref.watch(animeServiceProvider).getEnEmision,
  ),
);

final animesAgregadosProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => _fetchWithCache(
    _kAgregadosKey,
    ref.watch(animeServiceProvider).getAnimes,
  ),
);

/// Keyed by anime URL — each URL gets its own cached entry.
/// Detail pages are not cached offline (too many URLs, lower priority).
final animeDetalleProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, url) => ref.watch(animeServiceProvider).getAnimeDetalle(url),
);

// Tab-visibility signals — incremented by MainNavigationScreen when the user
// switches to that tab so screens can refresh without RouteAware tricks.
final homeTabRefreshProvider    = StateProvider<int>((ref) => 0);
final miListaTabRefreshProvider = StateProvider<int>((ref) => 0);

/// Animes filtrados por g�nero en modo demo.
/// autoDispose: se libera al salir del género — cache reside en el servidor.
final animesporGeneroProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, genero) =>
      ref.watch(animeServiceProvider).getAnimesporGenero(genero),
);

/// Live episode count for a specific anime URL.
/// Used by detail screen to avoid stale `episodios_count` from detail cache.
final animeEpisodeCountProvider =
    FutureProvider.autoDispose.family<int, String>(
  (ref, url) async {
    final eps = await ref.watch(animeServiceProvider).getEpisodios(url);
    return eps.length;
  },
);


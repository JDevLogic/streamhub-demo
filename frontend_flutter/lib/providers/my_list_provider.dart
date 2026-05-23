import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../services/watch_history.dart';

// Provider para tener toda la mi lista actualizada en pantalla.
final myListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return [];
  }
  return await WatchHistory.getMyList();
});

// Provider específico para consultar rápidamente el estado individual de un anime.
// Devuelve null si no está en la lista.
final animeMyListStatusProvider = FutureProvider.family<String?, String>((ref, animeUrl) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return null;
  }
  return await WatchHistory.getMyListStatus(animeUrl);
});

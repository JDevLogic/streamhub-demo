import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/native_player_screen.dart';
import '../screens/episodios_screen.dart' show PlayerScreen;
import '../theme.dart';
import '../widgets/loading_episode_overlay.dart';
import 'anime_service.dart';
import 'watch_history.dart';

/// Resultado devuelto por [autoResolveAndPlay] para que el caller pueda
/// reaccionar (refrescar historial, etc.) sin acoplar lógica de navegación.
enum AutoResolveResult { played, noServers, error }

// ── Per-episode best-server cache ──────────────────────────────────────

const _kBestServerPrefix = 'best_server_';

Future<String?> loadBestServer(String episodeUrl) async {
  if (episodeUrl.isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_kBestServerPrefix$episodeUrl');
}

Future<void> saveBestServer(String episodeUrl, String serverEnlace) async {
  if (episodeUrl.isEmpty || serverEnlace.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_kBestServerPrefix$episodeUrl', serverEnlace);
}

// ── Per-anime session preferred server (in-memory, resets on app restart) ──

final Map<String, String> _animePreferredServer = {};

/// Guarda qué servidor funcionó para un anime en esta sesión.
/// [serverName] es el nombre del servidor demo.
void setAnimePreferredServer(String animeUrl, String serverName) {
  if (animeUrl.isEmpty || serverName.isEmpty) return;
  _animePreferredServer[animeUrl] = serverName.toLowerCase();
}

/// Devuelve el nombre del servidor preferido para este anime en la sesión,
/// o null si no hay historial.
String? getAnimePreferredServer(String animeUrl) =>
    _animePreferredServer[animeUrl];

/// Reordena [servers] colocando el servidor preferido de primero.
/// Prioridad:
///   1. Caché de episodio (enlace exacto, persistido entre sesiones).
///   2. Preferencia de sesión por anime (nombre de servidor, en memoria).
Future<List<Map<String, dynamic>>> applyPreferredServerOrder(
  List<Map<String, dynamic>> servers,
  String episodeUrl,
  String animeUrl,
) async {
  if (servers.isEmpty) return servers;

  // 1. Episode-level cache: enlace exacto del servidor que funcionó antes
  final cached = await loadBestServer(episodeUrl);
  if (cached != null && cached.isNotEmpty && !cached.toLowerCase().contains('voe.')) {
    final idx = servers.indexWhere(
      (s) => (s['enlace'] ?? '').toString() == cached,
    );
    if (idx > 0) {
      final copy = List<Map<String, dynamic>>.from(servers);
      copy.insert(0, copy.removeAt(idx));
      return copy;
    }
  }

  // 2. Anime-level session preference: nombre del servidor que funcionó
  //    en otro episodio del mismo anime durante esta sesión.
  final preferred = getAnimePreferredServer(animeUrl);
  if (preferred != null && preferred.isNotEmpty) {
    final idx = servers.indexWhere(
      (s) => (s['servidor'] ?? '').toString().toLowerCase().contains(preferred),
    );
    if (idx > 0) {
      final copy = List<Map<String, dynamic>>.from(servers);
      copy.insert(0, copy.removeAt(idx));
      return copy;
    }
  }

  return servers;
}

// ── Source validation ──────────────────────────────────────────────────

bool _isValidSource(List<Map<String, dynamic>> sources) {
  return sources.any((s) => (s['url'] ?? '').toString().isNotEmpty);
}

// ── Parallel resolver ─────────────────────────────────────────────────

typedef _Resolved = ({Map<String, dynamic> srv, List<Map<String, dynamic>> sources});

/// Race [servers] in parallel. Returns the first valid resolved source,
/// or null if all fail. Servers should already be sorted by priority —
/// when two resolve at the same time, whichever completes first wins.
Future<_Resolved?> _raceResolvers(
  List<Map<String, dynamic>> servers,
  AnimeService service,
) async {
  if (servers.isEmpty) return null;
  final completer = Completer<_Resolved?>();
  var pending = 0;

  for (final srv in servers) {
    final enlace = (srv['enlace'] ?? '').toString();
    if (enlace.isEmpty) continue;
    pending++;
    service.resolveDirectUrl(enlace).then((sources) {
      if (_isValidSource(sources) && !completer.isCompleted) {
        completer.complete((srv: srv, sources: sources));
        return;
      }
      if (--pending == 0 && !completer.isCompleted) completer.complete(null);
    }).catchError((_) {
      if (--pending == 0 && !completer.isCompleted) completer.complete(null);
    });
  }

  if (pending == 0) return null;
  // Timeout: if no resolver wins in 10s, fall through to WebView
  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => null,
  );
}

// ── Main function ──────────────────────────────────────────────────────

/// Muestra un loading overlay, obtiene servidores, los ordena por prioridad,
/// intenta resolver un MP4/HLS nativo y abre [NativePlayerScreen].
/// Si ningún servidor resuelve, abre [PlayerScreen] (WebView).
///
/// [episodios] y [episodeIndex] son opcionales — sirven para que el
/// PlayerScreen de WebView pueda navegar entre episodios.
Future<AutoResolveResult> autoResolveAndPlay(
  BuildContext context, {
  required AnimeService service,
  required String animeTitle,
  required String animeUrl,
  required String animeImage,
  String animeStatus = '',
  required String episodioUrl,
  required String episodioNombre,
  List<Map<String, dynamic>> episodios = const [],
  int episodeIndex = 0,
  VoidCallback? onDone,
}) async {
  final navContext = context;

  showDialog(
    context: navContext,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.65), // slightly darker for aesthetic pop
    builder: (_) => const PopScope(
      canPop: false,
      child: LoadingEpisodeOverlay(),
    ),
  );

  try {
    // 1. Fetch servers + intro-skip in parallel (intro warms cache for later)
    final serversFuture = service.getServidores(episodioUrl);
    unawaited(service.getIntroSkip(episodioUrl));
    final raw = await serversFuture;
    if (!navContext.mounted) return AutoResolveResult.error;

    if (raw.isEmpty) {
      Navigator.pop(navContext);
      _showSnack(navContext, 'No hay servidores disponibles');
      return AutoResolveResult.noServers;
    }

    // 2. Register in history (but do NOT mark watched yet — the player
    //    will do that once the user reaches 90 % of the episode)
    WatchHistory.add(
      titulo: animeTitle,
      url: animeUrl,
      imagen: animeImage,
      lastEpisodeUrl: episodioUrl,
      lastEpisodeName: episodioNombre,
      lastKnownEpisodeCount: episodios.length,
      estado: animeStatus,
    );

    // 3. Sort by demo priority
    var servidores = AnimeService.sortServersByPriority(raw); // static utility

    // 4. Promote cached best server to front if still present
    servidores = await applyPreferredServerOrder(servidores, episodioUrl, animeUrl);

    // 5. Race top 5 servers in parallel; fall back sequentially for the rest
    final top  = servidores.take(5).toList();
    final rest = servidores.skip(5).toList();

    Future<AutoResolveResult?> tryResolved(_Resolved resolved) async {
      final enlace = (resolved.srv['enlace'] ?? '').toString();
      final nombre = (resolved.srv['servidor'] ?? 'Servidor').toString();
      final bestUrl = resolved.sources.last['url']?.toString() ?? '';
      if (bestUrl.isEmpty || !navContext.mounted) return null;

      // No guardamos aquí: el player guarda el preferido solo cuando
      // confirma reproducción real, evitando cachear servers que resuelven
      // pero no reproducen.
      Navigator.pop(navContext);
      await Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (_) => NativePlayerScreen(
            animeTitle: animeTitle,
            episodeName: episodioNombre,
            videoUrl: bestUrl,
            serverName: nombre,
            serverEnlace: enlace,
            episodeUrl: episodioUrl,
            qualities: resolved.sources,
            animeUrl: animeUrl,
            animeImage: animeImage,
            animeStatus: animeStatus,
            episodios: episodios,
            currentEpisodeIndex: episodeIndex,
            onSwitchToWebView: () {
              Navigator.push(
                navContext,
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    animeTitle: animeTitle,
                    animeUrl: animeUrl,
                    animeImage: animeImage,
                    animeStatus: animeStatus,
                    episodios: episodios,
                    initialEpisodeIndex: episodeIndex,
                    servidores: servidores,
                    initialServerIndex: 0,
                  ),
                ),
              );
            },
          ),
        ),
      );
      onDone?.call();
      return AutoResolveResult.played;
    }

    // Parallel race: top 3
    final winner = await _raceResolvers(top, service);
    if (winner != null) {
      final r = await tryResolved(winner);
      if (r != null) return r;
    }

    // Sequential fallback: remaining servers
    for (final server in rest) {
      final enlace = (server['enlace'] ?? '').toString();
      if (enlace.isEmpty) continue;
      try {
        final sources = await service.resolveDirectUrl(enlace);
        if (!_isValidSource(sources)) continue;
        final r = await tryResolved((srv: server, sources: sources));
        if (r != null) return r;
      } catch (_) {
        continue;
      }
    }

    // 6. Fallback: WebView (raw = lista sin ordenar, el usuario elige)
    if (!navContext.mounted) return AutoResolveResult.error;
    Navigator.pop(navContext);
    await Navigator.push(
      navContext,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          animeTitle: animeTitle,
          animeUrl: animeUrl,
          animeImage: animeImage,
          animeStatus: animeStatus,
          episodios: episodios,
          initialEpisodeIndex: episodeIndex,
          servidores: servidores,
          initialServerIndex: 0,
        ),
      ),
    );
    onDone?.call();
    return AutoResolveResult.played;
  } catch (e) {
    if (!navContext.mounted) return AutoResolveResult.error;
    Navigator.pop(navContext);
    _showSnack(navContext, 'Error cargando servidores');
    return AutoResolveResult.error;
  }
}

void _showSnack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: GoogleFonts.sora(fontSize: 13)),
      backgroundColor: VoidTheme.card,
      behavior: SnackBarBehavior.floating,
    ),
  );
}


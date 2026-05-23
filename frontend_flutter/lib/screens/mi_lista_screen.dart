import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/anime_providers.dart'
    show animeServiceProvider, miListaTabRefreshProvider;
import '../providers/auth_provider.dart';
import '../providers/my_list_provider.dart';
import '../services/watch_history.dart';
import '../theme.dart';
import '../widgets/search_button.dart';
import '../widgets/states.dart' show TappableScale;
import 'anime_detail_screen.dart';

class MiListaScreen extends ConsumerWidget {
  const MiListaScreen({super.key, required this.isGuest});

  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isGuest) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VoidTheme.primary.withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                          color: VoidTheme.primary.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bookmark_border_rounded,
                      color: VoidTheme.primary,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mi Lista',
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Inicia sesión para guardar tus animes\nfavoritos y acceder a ellos desde\ncualquier dispositivo.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      color: VoidTheme.textSecondary,
                      fontSize: 13.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () => ref.read(authProvider.notifier).logout(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [VoidTheme.primaryDark, VoidTheme.primary],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: VoidTheme.primary.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Iniciar sesión',
                            style: GoogleFonts.sora(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Authenticated state: showing list
    return const _MyListContent();
  }
}

class _MyListContent extends ConsumerStatefulWidget {
  const _MyListContent();

  @override
  ConsumerState<_MyListContent> createState() => _MyListContentState();
}

class _MyListContentState extends ConsumerState<_MyListContent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  final List<String> statuses = [
    'Todos',
    'En proceso',
    'Planeado',
    'Completado',
  ];

  final Map<String, String> statusMap = {
    'Todos': 'todos',
    'En proceso': 'en_proceso',
    'Planeado': 'planeado',
    'Completado': 'completado',
  };

  bool _reconciling = false;
  Map<String, String> _lastEpisodeByAnime = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: statuses.length, vsync: this);
    _loadLastEpisodes();
    ref.read(myListProvider.future).then((_) => _reconcileTotalsInBackground());
    // Run reconciliation whenever the user switches to this tab so episode
    // counts are always fresh (IndexedStack keeps this widget alive between
    // tab switches, so didChangeAppLifecycleState alone isn't enough).
    ref.listenManual(miListaTabRefreshProvider, (_, __) {
      if (!mounted) return;
      _reconcileTotalsInBackground();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Refresh automatically when user returns from player/background.
    ref.invalidate(myListProvider);
    _loadLastEpisodes();
    // Also re-run reconciliation to catch newly published episodes.
    _reconcileTotalsInBackground();
  }

  Future<void> _loadLastEpisodes() async {
    final history = await WatchHistory.getAll();
    if (!mounted) return;
    setState(() {
      _lastEpisodeByAnime = {
        for (final entry in history)
          (entry['url'] ?? '').toString():
              (entry['lastEpisodeName'] ?? '').toString(),
      };
    });
  }

  /// Walks every Mi Lista entry, fetches the current episode list from the
  /// provider, and calls [WatchHistory.syncMyListEpisodeCount] when the
  /// totals differ from what's stored. Rate-limited to a small in-flight
  /// batch to avoid hammering the backend. Re-invalidates the provider
  /// once at the end so the UI rebuilds with fresh numbers.
  Future<void> _reconcileTotalsInBackground() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      final list = await WatchHistory.getMyList();
      final watched = await WatchHistory.getWatchedEpisodes();
      if (list.isEmpty) return;

      final service = ref.read(animeServiceProvider);
      bool changed = false;

      const kBatch = 3;
      for (int i = 0; i < list.length; i += kBatch) {
        if (!mounted) return;
        final batch = list.skip(i).take(kBatch).toList();
        await Future.wait(batch.map((item) async {
          final animeUrl = (item['animeUrl'] ?? '').toString();
          if (animeUrl.isEmpty) return;
          try {
            final eps = await service.getEpisodios(animeUrl);
            if (eps.isEmpty) return;
            final total = (item['totalEpisodes'] as int?) ?? 0;
            final prevCount = (item['episodesWatched'] as int?) ?? 0;
            final epUrls = eps
                .map((e) => (e['url'] ?? '').toString())
                .where((u) => u.isNotEmpty)
                .toSet();
            final watchedCount = watched.where(epUrls.contains).length;
            if (total != eps.length || prevCount != watchedCount) {
              await WatchHistory.syncMyListEpisodeCount(
                animeUrl: animeUrl,
                watchedCount: watchedCount,
                totalEpisodes: eps.length,
              );
              changed = true;
            }
          } catch (_) {}
        }));
      }

      if (changed && mounted) {
        ref.invalidate(myListProvider);
      }
    } finally {
      _reconciling = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(myListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Mi Lista',
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const AnimeSearchButton(margin: EdgeInsets.zero),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              indicatorColor: VoidTheme.primary,
              indicatorWeight: 3,
              labelColor: VoidTheme.primary,
              unselectedLabelColor: VoidTheme.textSecondary,
              labelStyle:
                  GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  GoogleFonts.sora(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: statuses.map((tab) => Tab(text: tab)).toList(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (listAsync.isLoading && !listAsync.hasValue) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: VoidTheme.primary));
                  }
                  if (listAsync.hasError) {
                    return Center(
                        child: Text('Error: ${listAsync.error}',
                            style: GoogleFonts.sora(color: VoidTheme.text)));
                  }

                  final allData = listAsync.value ?? [];

                  return TabBarView(
                    controller: _tabController,
                    children: statuses.map((statusKey) {
                      final serverStatus = statusMap[statusKey]!;
                      final filtered = serverStatus == 'todos'
                          ? allData
                          : allData
                              .where((e) => e['status'] == serverStatus)
                              .toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No hay animes aquí',
                            style: GoogleFonts.sora(
                                color: VoidTheme.textSecondary, fontSize: 13),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await _reconcileTotalsInBackground();
                          await _loadLastEpisodes();
                          final refreshed = ref.refresh(myListProvider.future);
                          await refreshed;
                        },
                        color: VoidTheme.primary,
                        backgroundColor: VoidTheme.card,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final animeUrl =
                                (item['animeUrl'] ?? '').toString();
                            return _MyListCard(
                              item: item,
                              lastEpisodeName:
                                  _lastEpisodeByAnime[animeUrl] ?? '',
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyListCard extends ConsumerWidget {
  const _MyListCard({required this.item, required this.lastEpisodeName});

  final Map<String, dynamic> item;
  final String lastEpisodeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = item['titulo'] as String;
    final img = item['imagen'] as String;
    final epsWatched = item['episodesWatched'] as int;
    final epsTotal = item['totalEpisodes'] as int;
    final animeUrl = item['animeUrl'] as String;

    double progress = 0.0;
    if (epsTotal > 0) {
      progress = (epsWatched / epsTotal).clamp(0.0, 1.0);
    }

    return TappableScale(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnimeDetailScreen(
              animeUrl: animeUrl,
              animeTitle: title,
            ),
          ),
        );
        if (!context.mounted) return;
        ref.invalidate(myListProvider);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: VoidTheme.card),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 64,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  // Progress text & bar
                  Positioned(
                    bottom: 6,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$epsWatched vistos de ${epsTotal > 0 ? epsTotal : '?'}',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (lastEpisodeName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Último: ${_compactEpisodeName(lastEpisodeName)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: VoidTheme.surface.withOpacity(0.5),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                VoidTheme.primary),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              color: VoidTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

String _compactEpisodeName(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(value);
  if (match != null) return 'Ep. ${match.group(1)}';
  return value;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/anime_providers.dart';
import '../providers/auth_provider.dart';
import '../navigation_observer.dart';
import '../services/auto_resolve.dart';
import '../services/user_sync_service.dart';
import '../services/watch_history.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/home/content_rows.dart';
import '../widgets/skeletons.dart';
import '../widgets/home/hero_card.dart';
import '../widgets/home/section_header.dart';
import '../widgets/states.dart';
import 'anime_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  // Backing store for "Continuar Viendo". We keep the last successfully
  // computed list in-memory so pull-to-refresh / didPopNext don't briefly
  // wipe the row back to shimmer (which was causing the "items flash" the
  // user reported). New results only overwrite [_vistos] when ready.
  List<Map<String, dynamic>> _vistos = const [];
  bool _vistosInitialLoad = true;
  int _vistosLoadToken = 0;
  bool _refreshingOnResume = false;
  Timer? _swrRecheckTimer;

  // Backend /episodios uses stale-while-revalidate: the first call returns
  // cached data while a background re-scrape runs. A silent recheck a few
  // seconds later picks up the fresh list so the "new episode" badge in
  // Continuar Viendo appears without the user having to pull-to-refresh.
  static const _swrRecheckDelay = Duration(seconds: 4);

  String _normalizeAnimeUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
    if (value.startsWith('demo://')) return value;
    if (value.startsWith('/')) return 'demo://anime';
    return 'demo://anime/';
    return 'demo://anime/$value';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVistos();
    _prefetchVisible();
    _scheduleSwrRecheck();
    // Refresh immediately whenever the user switches back to the Home tab
    // (IndexedStack keeps this widget alive so didPopNext doesn't fire).
    ref.listenManual(homeTabRefreshProvider, (_, __) {
      if (!mounted) return;
      _refreshVistos();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _swrRecheckTimer?.cancel();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to Home from any pushed screen (players included).
    _refreshVistos();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _refreshingOnResume) return;
    _refreshingOnResume = true;
    _triggerCloudSync().then((_) {
      if (!mounted) return;
      ref.invalidate(ultimosEpisodiosProvider);
      ref.invalidate(enEmisionProvider);
      ref.invalidate(animesAgregadosProvider);
      _refreshVistos();
      _scheduleSwrRecheck();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      _refreshingOnResume = false;
    });
  }

  void _scheduleSwrRecheck() {
    _swrRecheckTimer?.cancel();
    _swrRecheckTimer = Timer(_swrRecheckDelay, () {
      if (!mounted) return;
      _loadVistos();
    });
  }

  Future<void> _prefetchVisible() async {
    try {
      final results = await Future.wait([
        ref.read(ultimosEpisodiosProvider.future),
        ref.read(enEmisionProvider.future),
        ref.read(animesAgregadosProvider.future),
      ]);
      final episodios = results[0];
      final emision = results[1];
      final agregados = results[2];

      final urls = <String>{};
      for (final ep in episodios.take(8)) {
        final epUrl = (ep['url'] ?? '').toString();
        if (epUrl.isNotEmpty) {
          urls.add(epUrl
              .replaceFirst('/ver/', '/anime/')
              .replaceFirst(RegExp(r'-\d+$'), ''));
        }
      }
      for (final anime in emision.take(4)) {
        final url = (anime['url'] ?? '').toString();
        if (url.isNotEmpty) urls.add(url);
      }
      for (final anime in agregados.take(6)) {
        final url = (anime['url'] ?? '').toString();
        if (url.isNotEmpty) urls.add(url);
      }
      ref.read(animeServiceProvider).prefetch(urls.toList());
    } catch (_) {}
  }

  Future<void> _loadVistos() async {
    final token = ++_vistosLoadToken;
    final result = await _buildEnrichedVistos();
    // Drop stale results if a newer load started while we were awaiting.
    if (!mounted || token != _vistosLoadToken) return;
    setState(() {
      _vistos = result;
      _vistosInitialLoad = false;
    });
  }

  Future<List<Map<String, dynamic>>> _buildEnrichedVistos() async {
    final vistos = await WatchHistory.getAll();
    if (vistos.isEmpty) return const [];

    final progressUrls = await WatchHistory.episodesWithProgress();
    final allProgress = await WatchHistory.getAllProgress();
    final watchedUrls = await WatchHistory.getWatchedEpisodes();
    final myList = await WatchHistory.getMyList();
    final myListByUrl = <String, Map<String, dynamic>>{
      for (final e in myList) (e['animeUrl'] ?? '').toString(): e,
    };

    const kBatch = 3;
    final enriched = <Map<String, dynamic>>[];
    for (int i = 0; i < vistos.length; i += kBatch) {
      if (!mounted) return const [];
      final batch = vistos.skip(i).take(kBatch).toList();
      final results = await Future.wait(batch.map((entry) async {
        final knownCount = (entry['lastKnownEpisodeCount'] as int?) ?? 0;
        final animeUrl = (entry['url'] ?? '').toString();
        if (animeUrl.isEmpty) return entry;

        // Mi Lista is the authoritative source for both the "I'm done" signal
        // and for the cover image. If Mi Lista has this anime:
        //   • mark as caught-up when status='completado' or counter maxed out
        //   • override the history-row cover with Mi Lista's cover (which the
        //     user has already confirmed is correct for S1/S2 etc.)
        // This fixes stale wrong covers in Continuar Viendo without requiring
        // a backend re-scrape or a manual history wipe.
        final myListEntry = myListByUrl[animeUrl];
        var preMerged = entry;
        if (myListEntry != null) {
          final status = (myListEntry['status'] ?? '').toString();
          final watched = (myListEntry['episodesWatched'] as int?) ?? 0;
          final total = (myListEntry['totalEpisodes'] as int?) ?? 0;
          if (status == 'completado' || (total > 0 && watched >= total)) {
            return {...entry, '_caughtUp': true};
          }
          final myListImg = (myListEntry['imagen'] ?? '').toString();
          if (myListImg.isNotEmpty) {
            preMerged = {...entry, 'imagen': myListImg};
          }
        }

        try {
          final eps =
              await ref.read(animeServiceProvider).getEpisodios(animeUrl);
          if (eps.isEmpty) return preMerged;

          // Reconcile Mi Lista's totalEpisodes/episodesWatched whenever we
          // already have the fresh scraped list. This keeps the progress bar
          // in Mi Lista accurate (e.g. 0/1 → 1/2 when a new episode airs)
          // without waiting for the user to enter the episodes screen.
          if (myListEntry != null) {
            final total = (myListEntry['totalEpisodes'] as int?) ?? 0;
            final prevCount = (myListEntry['episodesWatched'] as int?) ?? 0;
            final epUrls = eps
                .map((e) => (e['url'] ?? '').toString())
                .where((u) => u.isNotEmpty)
                .toSet();
            final watchedCount = watchedUrls.where(epUrls.contains).length;
            if (total != eps.length || prevCount != watchedCount) {
              unawaited(WatchHistory.syncMyListEpisodeCount(
                animeUrl: animeUrl,
                watchedCount: watchedCount,
                totalEpisodes: eps.length,
              ));
            }
          }

          final lastEpUrl = (entry['lastEpisodeUrl'] ?? '').toString();

          // Recover missing cover image from anime detail when both the
          // history row and Mi Lista are empty (rare — only for entries
          // that were never added to Mi Lista).
          var merged = preMerged;
          final currentImage = (merged['imagen'] ?? '').toString();
          if (currentImage.isEmpty) {
            try {
              final detailUrl = _normalizeAnimeUrl(animeUrl);
              final detail = await ref
                  .read(animeServiceProvider)
                  .getAnimeDetalle(detailUrl);
              final recovered =
                  (detail['imagen_hd'] ?? detail['imagen'] ?? '').toString();
              if (recovered.isNotEmpty) {
                merged = {...merged, 'imagen': recovered};
              }
            } catch (_) {}
          }

          // If the latest scraped episode is already in the watched set, the
          // user is fully caught up — hide the entry regardless of whether
          // lastEpisodeUrl happens to point at an older episode.
          final latestUrl = (eps.last['url'] ?? '').toString();
          if (watchedUrls.contains(latestUrl)) {
            return {...merged, '_caughtUp': true};
          }

          // Determine the recommended episode.
          Map<String, dynamic>? defaultEp;

          // 1. Prioritize active progress
          Map<String, dynamic>? bestProgressEp;
          double maxUpdatedAt = -1;
          for (final ep in eps) {
            final url = (ep['url'] ?? '').toString();
            if (progressUrls.contains(url)) {
              final prog = allProgress[url];
              if (prog != null) {
                final upd = prog['updatedAt'] ?? 0.0;
                if (upd > maxUpdatedAt) {
                  maxUpdatedAt = upd;
                  bestProgressEp = ep;
                }
              }
            }
          }

          if (bestProgressEp != null) {
            defaultEp = bestProgressEp;
          } else {
            // 2. Fallback: logically oldest unwatched episode
            final unwatchedEps = eps.where((ep) {
              return !watchedUrls.contains((ep['url'] ?? '').toString());
            }).toList();

            if (unwatchedEps.isEmpty) {
              return {...merged, '_caughtUp': true};
            }

            unwatchedEps.sort((a, b) {
              final aNum =
                  double.tryParse((a['episodio'] ?? '').toString()) ?? 9999.0;
              final bNum =
                  double.tryParse((b['episodio'] ?? '').toString()) ?? 9999.0;
              return aNum.compareTo(bNum);
            });
            defaultEp = unwatchedEps.first;
          }

          final theUrl = (defaultEp['url'] ?? '').toString();
          final epName = (defaultEp['episodio'] ?? '').toString();

          // Activate "SIGUIENTE/NUEVO" badge when the recommended episode diverges
          // from the history's last played episode, or if there's a newly published episode.
          final hasNewEp = (eps.length > knownCount) || (theUrl != lastEpUrl);

          if (hasNewEp) {
            return {
              ...merged,
              'lastEpisodeUrl': theUrl,
              'lastEpisodeName': epName,
              'hasNewEpisode': true,
              'newEpisodeUrl': theUrl,
              'newEpisodeName': epName,
            };
          }

          return {
            ...merged,
            'lastEpisodeUrl': theUrl,
            'lastEpisodeName': epName,
          };
        } catch (_) {}
        return preMerged;
      }));
      enriched.addAll(results);
    }

    final filtered = enriched.where((e) => e['_caughtUp'] != true).toList();

    // PRIORITY: Sort animes with new episodes to the beginning
    filtered.sort((a, b) {
      final aNew = a['hasNewEpisode'] == true ? 1 : 0;
      final bNew = b['hasNewEpisode'] == true ? 1 : 0;
      return bNew.compareTo(aNew); // 1 before 0
    });

    return filtered;
  }

  void _refreshVistos() {
    _loadVistos();
  }

  Future<void> _triggerCloudSync() async {
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated && authState.token != null) {
      try {
        await WatchHistory.runWithoutCloudSync(() async {
          final remote = await UserSyncService.downloadState(authState.token!);
          if (remote != null) {
            final payload =
                (remote['payload'] as Map?)?.cast<String, dynamic>();
            if (payload != null) await WatchHistory.mergeSyncPayload(payload);
          }
        });
      } catch (_) {}
    }
  }

  Future<void> _refreshAll() async {
    await _triggerCloudSync();

    ref.invalidate(ultimosEpisodiosProvider);
    ref.invalidate(enEmisionProvider);
    ref.invalidate(animesAgregadosProvider);
    await Future.wait([
      _loadVistos(),
      ref.read(ultimosEpisodiosProvider.future),
      ref.read(enEmisionProvider.future),
      ref.read(animesAgregadosProvider.future),
    ]);
  }

  void _openAnime(String titulo, String url, [String imagen = '']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailScreen(
          animeTitle: titulo,
          animeUrl: url,
          animeImage: imagen,
        ),
      ),
    ).then((_) => _refreshVistos());
  }

  void _openContinuarViendo(
    String titulo,
    String url,
    String imagen, {
    String lastEpisodeUrl = '',
    String lastEpisodeName = '',
  }) {
    if (lastEpisodeUrl.isEmpty) {
      _openAnime(titulo, url, imagen);
      return;
    }
    _autoPlayEpisode(
      animeTitle: titulo,
      animeUrl: url,
      animeImage: imagen,
      episodioUrl: lastEpisodeUrl,
      episodioNombre: lastEpisodeName,
    );
  }

  void _openEpisodio(Map<String, dynamic> ep) {
    final titulo = (ep['titulo'] ?? '').toString();
    final episodio = (ep['episodio'] ?? '').toString();
    final episodioUrl = (ep['url'] ?? '').toString();
    final imagen = (ep['imagen'] ?? '').toString();
    final animeUrl = episodioUrl
        .replaceFirst('/ver/', '/anime/')
        .replaceFirst(RegExp(r'-\d+$'), '');

    _autoPlayEpisode(
      animeTitle: titulo,
      animeUrl: animeUrl,
      animeImage: imagen,
      episodioUrl: episodioUrl,
      episodioNombre: episodio,
    );
  }

  Future<void> _autoPlayEpisode({
    required String animeTitle,
    required String animeUrl,
    required String animeImage,
    required String episodioUrl,
    required String episodioNombre,
  }) async {
    List<Map<String, dynamic>> episodios = [];
    int episodeIndex = 0;
    try {
      episodios = await ref.read(animeServiceProvider).getEpisodios(animeUrl);
      episodeIndex = episodios.indexWhere(
        (e) => (e['url'] ?? '').toString() == episodioUrl,
      );
      if (episodeIndex < 0) episodeIndex = 0;
    } catch (_) {}

    if (!mounted) return;
    await autoResolveAndPlay(
      context,
      service: ref.read(animeServiceProvider),
      animeTitle: animeTitle,
      animeUrl: animeUrl,
      animeImage: animeImage,
      episodioUrl: episodioUrl,
      episodioNombre: episodioNombre,
      episodios: episodios,
      episodeIndex: episodeIndex,
    );
    if (!mounted) return;
    _refreshVistos();
    // Some progress writes are async on player close. Do a quick short burst
    // to make the row feel near-instant without manual pull-to-refresh.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _refreshVistos();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _refreshVistos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: VoidTheme.primary,
        backgroundColor: VoidTheme.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: ShaderMask(
                shaderCallback: (bounds) =>
                    VoidTheme.gradientPrimary.createShader(bounds),
                child: Text(
                  'ANISTREAM',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: VoidTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VoidTheme.cardBorder),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.search_rounded,
                        color: VoidTheme.textSecondary, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ).then((_) => _refreshVistos()),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: FadeInEntrance(
                duration: const Duration(milliseconds: 800),
                child: ref.watch(ultimosEpisodiosProvider).when(
                      loading: _heroPlaceholder,
                      error: (_, __) => _heroPlaceholder(),
                      data: (eps) => eps.isEmpty
                          ? _heroPlaceholder()
                          : HomeHeroCard(
                              ep: eps.first,
                              onTap: () => _openEpisodio(eps.first),
                            ),
                    ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeInEntrance(
                delay: const Duration(milliseconds: 150),
                child: _buildSection(
                  title: 'Últimos Episodios',
                  async: ref.watch(ultimosEpisodiosProvider),
                  onRetry: () => ref.invalidate(ultimosEpisodiosProvider),
                  shimmer: const _ShimmerHorizontalList(
                      child: EpisodeCardSkeleton()),
                  builder: (eps) => HorizontalEpisodioRow(
                    episodios: eps,
                    onTap: _openEpisodio,
                  ),
                ),
              ),
            ),
            if (!ref.watch(authProvider).isGuest)
              SliverToBoxAdapter(
                child: FadeInEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: _buildVistosSection(),
                ),
              )
            else
              SliverToBoxAdapter(
                child: FadeInEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VoidTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VoidTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: VoidTheme.amber, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Inicia sesión para usar "Continuar Viendo"',
                          style: GoogleFonts.sora(
                            color: VoidTheme.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: FadeInEntrance(
                delay: const Duration(milliseconds: 450),
                child: _buildSection(
                  title: 'Recién Agregados',
                  async: ref.watch(animesAgregadosProvider),
                  onRetry: () => ref.invalidate(animesAgregadosProvider),
                  shimmer:
                      const _ShimmerHorizontalList(child: AnimeCardSkeleton()),
                  builder: (animes) => HorizontalAnimeRow(
                    animes: animes,
                    onTap: _openAnime,
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: VoidTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoidTheme.cardBorder),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: VoidTheme.primary),
      ),
    );
  }

  Widget _buildSection<T>({
    required String title,
    required AsyncValue<List<T>> async,
    required Widget Function(List<T>) builder,
    required Widget shimmer,
    VoidCallback? onRetry,
  }) {
    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: title),
          shimmer,
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: title),
          AppErrorState(error: e, onRetry: onRetry, slim: true),
        ],
      ),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [HomeSectionHeader(title: title), builder(data)],
        );
      },
    );
  }

  Widget _buildVistosSection() {
    // Only shimmer on the very first load (before any result has landed).
    // After that, even during a refresh, we keep the last good [_vistos]
    // visible so nothing flickers in or out.
    if (_vistosInitialLoad) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          HomeSectionHeader(title: 'Continuar Viendo'),
          _ShimmerHorizontalList(
            height: 74,
            child: ContinueWatchingSkeleton(),
          ),
        ],
      );
    }
    if (_vistos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Continuar Viendo'),
        ContinuarViendoRow(
          animes: _vistos,
          onRemove: (url) async {
            await WatchHistory.remove(url);
            _refreshVistos();
          },
          onTap: (entry) {
            final hasNew = entry['hasNewEpisode'] == true;
            final epUrl = hasNew
                ? (entry['newEpisodeUrl'] ?? '').toString()
                : (entry['lastEpisodeUrl'] ?? '').toString();
            final epName = hasNew
                ? (entry['newEpisodeName'] ?? '').toString()
                : (entry['lastEpisodeName'] ?? '').toString();
            _openContinuarViendo(
              (entry['titulo'] ?? '').toString(),
              (entry['url'] ?? '').toString(),
              (entry['imagen'] ?? '').toString(),
              lastEpisodeUrl: epUrl,
              lastEpisodeName: epName,
            );
          },
        ),
      ],
    );
  }
}

class _ShimmerHorizontalList extends StatelessWidget {
  const _ShimmerHorizontalList({required this.child, this.height = 200});
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => child,
      ),
    );
  }
}


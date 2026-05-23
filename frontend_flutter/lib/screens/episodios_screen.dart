import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/anime_providers.dart';
import '../providers/appearance_provider.dart';
import '../services/anime_service.dart';
import '../services/auto_resolve.dart';
import '../services/watch_history.dart';
import '../theme.dart';
import '../widgets/loading_episode_overlay.dart';
import '../widgets/skip_intro_button.dart';
import '../widgets/skeletons.dart';
import '../widgets/states.dart';

// ---------------------------------------------------------------------------
// EpisodiosScreen – lista de episodios
// ---------------------------------------------------------------------------

enum _EpViewMode { list, grid }

enum _EpFilter { all, unwatched, watched }

const _kEpAutoGridThreshold = 50;
const _kEpRangeChipThreshold = 100;
const _kEpRangeSize = 100;
const _kEpGridCols = 5;
const _kEpListTileExtent = 78.0; // tile (~68) + bottom margin (10)
const _kEpGridTileExtent = 68.0; // square tile (~58) + bottom margin (10)

class EpisodiosScreen extends ConsumerStatefulWidget {
  const EpisodiosScreen({
    super.key,
    required this.animeTitle,
    required this.animeUrl,
    this.animeImage = '',
    this.animeStatus = '',
  });

  final String animeTitle;
  final String animeUrl;
  final String animeImage;
  final String animeStatus;

  @override
  ConsumerState<EpisodiosScreen> createState() => _EpisodiosScreenState();
}

class _EpisodiosScreenState extends ConsumerState<EpisodiosScreen> {
  late Future<List<Map<String, dynamic>>> _futureEpisodios;
  List<Map<String, dynamic>> _episodios = [];
  Set<String> _watchedUrls = {};
  Map<String, Map<String, double>> _progressMap = {};
  String? _lastPlayedUrl;
  String? _currentEpisodeUrl; // cached "next to watch" pointer
  final _scrollController = ScrollController();

  /// Recompute the episode to highlight as "next to watch":
  /// - If any episode has active saved progress, resume the latest one.
  /// - If the last played episode is unwatched, keep it (CONTINUAR).
  /// - Otherwise advance to the first unwatched episode after it.
  /// - If there is no later unwatched episode, keep the last played one as
  ///   the user's current position instead of jumping back to older gaps.
  /// Mirrors the home screen logic. Cached on _watched/_lastPlayed changes
  /// to avoid O(n) work on every tile build.
  void _recomputeCurrentEpisode() {
    if (_episodios.isEmpty) {
      _currentEpisodeUrl = null;
      return;
    }

    Map<String, dynamic>? bestProgressEp;
    double bestUpdatedAt = -1;
    for (final ep in _episodios) {
      final url = (ep['url'] ?? '').toString();
      if (url.isEmpty) continue;
      final progress = _progressMap[url];
      if (progress == null) continue;
      final updatedAt = progress['updatedAt'] ?? 0.0;
      if (updatedAt > bestUpdatedAt) {
        bestUpdatedAt = updatedAt;
        bestProgressEp = ep;
      }
    }
    if (bestProgressEp != null) {
      _currentEpisodeUrl = (bestProgressEp['url'] ?? '').toString();
      return;
    }

    final last = _lastPlayedUrl;
    if (last != null && last.isNotEmpty) {
      final lastIdx = _episodios.indexWhere(
        (ep) => (ep['url'] ?? '').toString() == last,
      );
      if (lastIdx >= 0) {
        if (!_watchedUrls.contains(last)) {
          _currentEpisodeUrl = last;
          return;
        }

        for (var i = lastIdx + 1; i < _episodios.length; i++) {
          final url = (_episodios[i]['url'] ?? '').toString();
          if (url.isNotEmpty && !_watchedUrls.contains(url)) {
            _currentEpisodeUrl = url;
            return;
          }
        }

        _currentEpisodeUrl = last;
        return;
      }
    }

    Map<String, dynamic>? bestUnwatched;
    double bestNum = double.infinity;
    for (final ep in _episodios) {
      final url = (ep['url'] ?? '').toString();
      if (url.isEmpty || _watchedUrls.contains(url)) continue;
      final raw = (ep['episodio'] ?? '').toString();
      final n = double.tryParse(raw) ??
          double.tryParse(_episodeNumberLabel(raw)) ??
          double.infinity;
      if (n < bestNum) {
        bestNum = n;
        bestUnwatched = ep;
      }
    }
    _currentEpisodeUrl =
        bestUnwatched != null ? (bestUnwatched['url'] ?? '').toString() : last;
  }

  _EpViewMode? _viewMode; // null until SharedPreferences resolves
  _EpFilter _filter = _EpFilter.all;
  int _activeRangeIdx = 0;

  bool get _animeIsFinished =>
      widget.animeStatus.toLowerCase().contains('finaliz');

  Future<void> _syncMyListProgressFromWatched() async {
    if (_episodios.isEmpty) return;
    final episodeUrls = _episodios
        .map((e) => (e['url'] ?? '').toString())
        .where((u) => u.isNotEmpty)
        .toSet();
    final watchedCount = _watchedUrls.where(episodeUrls.contains).length;
    await WatchHistory.syncMyListEpisodeCount(
      animeUrl: widget.animeUrl,
      watchedCount: watchedCount,
      totalEpisodes: _episodios.length,
      animeIsFinished: _animeIsFinished,
    );
  }

  @override
  void initState() {
    super.initState();
    final service = ref.read(animeServiceProvider);
    _futureEpisodios = service.getEpisodios(widget.animeUrl).then((eps) {
      _episodios = eps;
      _preloadServers(eps, service);
      _resolveInitialViewMode();
      _recomputeCurrentEpisode();
      return eps;
    });
    _loadWatched();
    ref.listenManual(appearanceProvider, (previous, next) {
      if (previous?.episodeView == next.episodeView) return;
      _resolveInitialViewMode();
    });
    _scrollController.addListener(_onScrollUpdateRange);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollUpdateRange);
    _scrollController.dispose();
    super.dispose();
  }

  /// Resolve the view mode: user preference if set, otherwise auto
  /// (grid for series with > _kEpAutoGridThreshold episodes).
  void _resolveInitialViewMode() {
    final preference = ref.read(appearanceProvider).episodeView;
    if (!mounted) return;
    setState(() {
      switch (preference) {
        case EpisodeViewPreference.list:
          _viewMode = _EpViewMode.list;
          break;
        case EpisodeViewPreference.grid:
          _viewMode = _EpViewMode.grid;
          break;
        case EpisodeViewPreference.automatic:
          _viewMode = _episodios.length > _kEpAutoGridThreshold
              ? _EpViewMode.grid
              : _EpViewMode.list;
          break;
      }
    });
  }

  Future<void> _setViewMode(_EpViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await ref.read(appearanceProvider.notifier).setEpisodeView(
          mode == _EpViewMode.grid
              ? EpisodeViewPreference.grid
              : EpisodeViewPreference.list,
        );
    // Re-anchor on the current episode after a layout switch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentEpisode();
    });
  }

  void _setFilter(_EpFilter f) {
    if (_filter == f) return;
    setState(() {
      _filter = f;
      _activeRangeIdx = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Filtered list (Sin ver / Vistos / Todos).
  List<Map<String, dynamic>> _filteredEpisodios() {
    if (_filter == _EpFilter.all) return _episodios;
    return _episodios.where((e) {
      final url = (e['url'] ?? '').toString();
      final isWatched = _watchedUrls.contains(url);
      return _filter == _EpFilter.watched ? isWatched : !isWatched;
    }).toList(growable: false);
  }

  /// Number of 100-episode buckets. Range chips only render when >1 bucket.
  int _rangeBucketCount(int total) =>
      total <= _kEpRangeChipThreshold ? 0 : (total / _kEpRangeSize).ceil();

  /// Pixel offset for the first item of [bucket] given the current view mode.
  double _offsetForBucket(int bucket) {
    final firstIdx = bucket * _kEpRangeSize;
    if (_viewMode == _EpViewMode.grid) {
      final row = firstIdx ~/ _kEpGridCols;
      return row * _kEpGridTileExtent;
    }
    return firstIdx * _kEpListTileExtent;
  }

  /// While scrolling, recompute which range chip should be highlighted.
  void _onScrollUpdateRange() {
    if (!_scrollController.hasClients) return;
    if (_filter != _EpFilter.all) return; // chips hidden when filtered
    final total = _episodios.length;
    if (_rangeBucketCount(total) == 0) return;

    final offset = _scrollController.offset;
    final tileH =
        _viewMode == _EpViewMode.grid ? _kEpGridTileExtent : _kEpListTileExtent;
    final unitsPerBucket = _viewMode == _EpViewMode.grid
        ? (_kEpRangeSize / _kEpGridCols)
        : _kEpRangeSize;
    final bucket = (offset / (tileH * unitsPerBucket)).floor();
    final clamped = bucket.clamp(0, _rangeBucketCount(total) - 1);
    if (clamped != _activeRangeIdx) {
      setState(() => _activeRangeIdx = clamped);
    }
  }

  void _jumpToBucket(int bucket) {
    if (!_scrollController.hasClients) return;
    final target = _offsetForBucket(bucket)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    setState(() => _activeRangeIdx = bucket);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  /// Extract a numeric episode label ("Episodio 123" → "123"). Falls back
  /// to the original string if no digits are present.
  String _episodeNumberLabel(String raw) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    return m?.group(1) ?? raw;
  }

  /// Preload servers + resolve top embed URL for the first episodes.
  /// Warms both the backend SQLite cache and the in-memory resolver cache
  /// so tapping an episode skips all network resolution.
  void _preloadServers(List<Map<String, dynamic>> eps, AnimeService service) {
    for (final ep in eps.take(5)) {
      final url = (ep['url'] ?? '').toString();
      if (url.isEmpty) continue;
      service.getServidores(url).then((servers) {
        final sorted = AnimeService.sortServersByPriority(servers);
        // Resolve only the top-priority server to avoid hammering embed sites
        for (final srv in sorted.take(1)) {
          final enlace = (srv['enlace'] ?? '').toString();
          if (enlace.isNotEmpty) {
            service
                .resolveDirectUrl(enlace)
                .catchError((_) => <Map<String, dynamic>>[]);
          }
        }
      }).catchError((_) {});
    }
  }

  Future<void> _loadWatched() async {
    final results = await Future.wait([
      WatchHistory.getWatchedEpisodes(),
      WatchHistory.getLastEpisodeUrl(widget.animeUrl),
      WatchHistory.getAllProgress(),
    ]);
    if (!mounted) return;
    setState(() {
      _watchedUrls = results[0] as Set<String>;
      _lastPlayedUrl = results[1] as String?;
      _progressMap = results[2] as Map<String, Map<String, double>>;
      _recomputeCurrentEpisode();
    });
    unawaited(_syncMyListProgressFromWatched());
    _scrollToCurrentEpisode();
  }

  void _scrollToCurrentEpisode() {
    if (_currentEpisodeUrl == null || _episodios.isEmpty) return;
    final visible = _filteredEpisodios();
    final idx = visible.indexWhere(
      (e) => (e['url'] ?? '') == _currentEpisodeUrl,
    );
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final double offset;
      if (_viewMode == _EpViewMode.grid) {
        final row = idx ~/ _kEpGridCols;
        offset = (row * _kEpGridTileExtent) - 80;
      } else {
        offset = (idx * _kEpListTileExtent) - 80;
      }
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _playEpisode(int episodeIndex) async {
    if (_episodios.isEmpty) return;

    final episodio = _episodios[episodeIndex];
    final episodioUrl = (episodio['url'] ?? '').toString();
    final episodioNombre = (episodio['episodio'] ?? 'Episodio').toString();

    await autoResolveAndPlay(
      context,
      service: ref.read(animeServiceProvider),
      animeTitle: widget.animeTitle,
      animeUrl: widget.animeUrl,
      animeImage: widget.animeImage,
      animeStatus: widget.animeStatus,
      episodioUrl: episodioUrl,
      episodioNombre: episodioNombre,
      episodios: _episodios,
      episodeIndex: episodeIndex,
      onDone: _loadWatched,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.animeTitle,
            style: GoogleFonts.sora(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: VoidTheme.text,
            )),
        iconTheme: const IconThemeData(color: VoidTheme.textSecondary),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureEpisodios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: 10,
              itemBuilder: (_, __) => const EpisodeListTileSkeleton(),
            );
          }
          if (snapshot.hasError) {
            return AppErrorState(
              error: snapshot.error!,
              onRetry: () => setState(
                () => _futureEpisodios = ref
                    .read(animeServiceProvider)
                    .getEpisodios(widget.animeUrl),
              ),
            );
          }

          final episodios = snapshot.data ?? [];
          if (episodios.isEmpty) {
            return const AppEmptyState.episodes();
          }

          // First-frame fallback while the persisted appearance preference loads.
          final mode = _viewMode ??
              (episodios.length > _kEpAutoGridThreshold
                  ? _EpViewMode.grid
                  : _EpViewMode.list);
          final visible = _filteredEpisodios();
          final showRanges = _filter == _EpFilter.all &&
              _rangeBucketCount(episodios.length) > 1;

          return Column(
            children: [
              _buildToolbar(mode, episodios.length),
              if (showRanges)
                _buildRangeStrip(_rangeBucketCount(episodios.length)),
              Expanded(
                child: visible.isEmpty
                    ? _buildEmptyForFilter()
                    : (mode == _EpViewMode.grid
                        ? _buildGrid(visible)
                        : _buildList(visible)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Toolbar: filtros + toggle de vista ────────────────────────────────────
  Widget _buildToolbar(_EpViewMode mode, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Todos', _EpFilter.all),
                  const SizedBox(width: 8),
                  _filterChip('Sin ver', _EpFilter.unwatched),
                  const SizedBox(width: 8),
                  _filterChip('Vistos', _EpFilter.watched),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _viewToggle(mode),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _EpFilter f) {
    final active = _filter == f;
    return GestureDetector(
      onTap: () => _setFilter(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [VoidTheme.primary, VoidTheme.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : VoidTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? VoidTheme.primary.withOpacity(0.6)
                : VoidTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            color: active ? Colors.white : VoidTheme.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _viewToggle(_EpViewMode mode) {
    return Container(
      decoration: BoxDecoration(
        color: VoidTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoidTheme.cardBorder),
      ),
      child: Row(
        children: [
          _viewToggleButton(Icons.view_agenda_rounded, _EpViewMode.list, mode),
          _viewToggleButton(Icons.grid_view_rounded, _EpViewMode.grid, mode),
        ],
      ),
    );
  }

  Widget _viewToggleButton(
      IconData icon, _EpViewMode target, _EpViewMode current) {
    final active = current == target;
    return GestureDetector(
      onTap: () => _setViewMode(target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 32,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [VoidTheme.primary, VoidTheme.cyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? Colors.white : VoidTheme.textSecondary,
        ),
      ),
    );
  }

  // ── Range chips (1-100, 101-200, …) ───────────────────────────────────────
  Widget _buildRangeStrip(int bucketCount) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: bucketCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final start = i * _kEpRangeSize + 1;
          final end = ((i + 1) * _kEpRangeSize).clamp(0, _episodios.length);
          final active = i == _activeRangeIdx;
          return GestureDetector(
            onTap: () => _jumpToBucket(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? VoidTheme.primary.withOpacity(0.16)
                    : VoidTheme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? VoidTheme.primary.withOpacity(0.55)
                      : VoidTheme.cardBorder,
                ),
              ),
              child: Center(
                child: Text(
                  '$start-$end',
                  style: GoogleFonts.sora(
                    color: active ? VoidTheme.text : VoidTheme.textSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyForFilter() {
    final msg = _filter == _EpFilter.unwatched
        ? 'No hay episodios sin ver'
        : 'No hay episodios marcados como vistos';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            color: VoidTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── List view (full tile) ─────────────────────────────────────────────────
  Widget _buildList(List<Map<String, dynamic>> visible) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final episodio = visible[index];
        final absoluteIdx = _episodios.indexOf(episodio);
        return _buildListTile(episodio, absoluteIdx);
      },
    );
  }

  Widget _buildListTile(Map<String, dynamic> episodio, int absoluteIdx) {
    final titulo = (episodio['episodio'] ?? 'Episodio').toString();
    final epUrl = (episodio['url'] ?? '').toString();
    final watched = _watchedUrls.contains(epUrl);
    final isCurrent = epUrl.isNotEmpty && epUrl == _currentEpisodeUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TappableScale(
        onTap: () => _playEpisode(absoluteIdx),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                gradient: isCurrent
                    ? LinearGradient(
                        colors: [
                          VoidTheme.primary.withOpacity(0.16),
                          VoidTheme.cyan.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCurrent
                    ? null
                    : watched
                        ? VoidTheme.surface.withOpacity(0.65)
                        : VoidTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? VoidTheme.primary.withOpacity(0.5)
                      : watched
                          ? VoidTheme.emerald.withOpacity(0.25)
                          : VoidTheme.cardBorder,
                  width: isCurrent ? 1.5 : 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: VoidTheme.primary.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleWatched(epUrl, watched),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: watched
                            ? VoidTheme.emerald.withOpacity(0.15)
                            : VoidTheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: watched
                              ? VoidTheme.emerald.withOpacity(0.5)
                              : VoidTheme.cardBorder.withOpacity(0.7),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          watched
                              ? Icons.check_rounded
                              : Icons.radio_button_unchecked,
                          key: ValueKey(watched),
                          color:
                              watched ? VoidTheme.emerald : VoidTheme.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: GoogleFonts.sora(
                            color:
                                watched ? VoidTheme.textMuted : VoidTheme.text,
                            fontWeight:
                                watched ? FontWeight.w400 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isCurrent && !watched
                                    ? VoidTheme.cyan
                                    : watched
                                        ? VoidTheme.emerald
                                        : VoidTheme.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCurrent && !watched
                                  ? 'CONTINUAR'
                                  : watched
                                      ? 'Visto'
                                      : 'Sin ver',
                              style: GoogleFonts.sora(
                                color: isCurrent && !watched
                                    ? VoidTheme.cyan
                                    : watched
                                        ? VoidTheme.emerald.withOpacity(0.7)
                                        : VoidTheme.textMuted,
                                fontSize: 11,
                                fontWeight: isCurrent && !watched
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                letterSpacing: isCurrent && !watched ? 0.5 : 0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: watched
                          ? null
                          : const LinearGradient(
                              colors: [VoidTheme.primary, VoidTheme.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color:
                          watched ? VoidTheme.surface.withOpacity(0.9) : null,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: watched
                          ? null
                          : [
                              BoxShadow(
                                color: VoidTheme.primary.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: watched
                          ? VoidTheme.primary.withOpacity(0.3)
                          : Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    gradient: VoidTheme.gradientPrimary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Grid view (compact numbered tiles) ────────────────────────────────────
  Widget _buildGrid(List<Map<String, dynamic>> visible) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kEpGridCols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final episodio = visible[index];
        final absoluteIdx = _episodios.indexOf(episodio);
        return _buildGridTile(episodio, absoluteIdx);
      },
    );
  }

  Widget _buildGridTile(Map<String, dynamic> episodio, int absoluteIdx) {
    final titulo = (episodio['episodio'] ?? 'Episodio').toString();
    final epUrl = (episodio['url'] ?? '').toString();
    final watched = _watchedUrls.contains(epUrl);
    final isCurrent = epUrl.isNotEmpty && epUrl == _currentEpisodeUrl;
    final number = _episodeNumberLabel(titulo);

    return TappableScale(
      onTap: () => _playEpisode(absoluteIdx),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.selectionClick();
          _toggleWatched(epUrl, watched);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [VoidTheme.primary, VoidTheme.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isCurrent
                ? null
                : watched
                    ? VoidTheme.emerald.withOpacity(0.12)
                    : VoidTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent
                  ? VoidTheme.primary.withOpacity(0.6)
                  : watched
                      ? VoidTheme.emerald.withOpacity(0.4)
                      : VoidTheme.cardBorder,
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: VoidTheme.primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  number,
                  style: GoogleFonts.sora(
                    color: isCurrent
                        ? Colors.white
                        : watched
                            ? VoidTheme.emerald
                            : VoidTheme.text,
                    fontSize: number.length >= 4 ? 14 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (watched && !isCurrent)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: VoidTheme.emerald.withOpacity(0.85),
                  ),
                ),
              if (isCurrent)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shared watched-toggle handler (optimistic UI + persistence).
  void _toggleWatched(String epUrl, bool currentlyWatched) {
    if (epUrl.isEmpty) return;
    setState(() {
      if (currentlyWatched) {
        _watchedUrls.remove(epUrl);
      } else {
        _watchedUrls.add(epUrl);
      }
      _recomputeCurrentEpisode();
    });
    if (currentlyWatched) {
      unawaited(WatchHistory.unmarkEpisodeWatched(epUrl));
    } else {
      unawaited(WatchHistory.markEpisodeWatched(epUrl));
      unawaited(
        WatchHistory.handleEpisodeFinished(
          widget.animeUrl,
          animeIsFinished: _animeIsFinished,
        ),
      );
    }
    unawaited(_syncMyListProgressFromWatched());
  }
}

// ---------------------------------------------------------------------------
// PlayerScreen – WebView (fondo) + UI propia encima (tipo Netflix)
// Autoplay controlado por JS, fallback con tap único y bloqueo visual + ad blocking
// ---------------------------------------------------------------------------

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.animeTitle,
    required this.animeUrl,
    this.animeImage = '',
    this.animeStatus = '',
    required this.episodios,
    required this.initialEpisodeIndex,
    required this.servidores,
    required this.initialServerIndex,
  });

  final String animeTitle;
  final String animeUrl;
  final String animeImage;
  final String animeStatus;
  final List<Map<String, dynamic>> episodios;
  final int initialEpisodeIndex;
  final List<Map<String, dynamic>> servidores;
  final int initialServerIndex;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _chan = MethodChannel('com.anime/orientation');

  InAppWebViewController? _wvc;
  final GlobalKey _wvKey = GlobalKey();

  late int _epIdx;
  late int _srvIdx;
  late List<Map<String, dynamic>> _servers;

  bool _loading = true;
  bool _showUI = false;
  bool _fetching = false;
  bool _showTapToPlay = false;
  bool _attemptingPlay = false;
  bool _playToggleBusy = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isFitted = false;
  bool _isDraggingSlider = false;
  double _playbackSpeed = 1.0;
  double _videoPosition = 0;
  double _videoDuration = 0;
  double _videoBufferedEnd = 0;
  bool _markedWatched = false;
  double _lastSavedProgress = -1;
  String? _error;
  int _retries = 0;

  Timer? _hideTimer;
  Timer? _loadTimer;
  Timer? _progressTimer;
  int _progressTick = 0;
  // Guard para guardar el servidor preferido una sola vez por carga,
  // en el momento en que confirmamos reproducción real.
  bool _bestServerRecorded = false;
  // Cooldown tras hacer seek: ignora updates de posición del poll durante
  // este tiempo para que no "rebote" al valor viejo mientras el video
  // todavía no ha saltado en el backend del reproductor.
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _kSeekCooldown = Duration(milliseconds: 1500);

  // Intro skip
  double? _introStart;
  double? _introEnd;
  bool _showSkipIntro = false;

  final Set<String> _allowed = {};

  bool get _animeIsFinished =>
      widget.animeStatus.toLowerCase().contains('finaliz');

  // -----------------------------------------------------------------------
  // Ad patterns – bloqueo a nivel de red
  // -----------------------------------------------------------------------

  static const _adPat = [
    'doubleclick',
    'googlesyndication',
    'googleadservices',
    'google-analytics',
    'googletagmanager',
    'pagead2',
    'adserv',
    'adclick',
    'adform',
    'admob',
    'adnxs',
    'adsystem',
    'adtrace',
    'adserver',
    'advertising',
    'popads',
    'popcash',
    'popunder',
    'popwin',
    'popmyads',
    'propellerads',
    'trafficjunky',
    'trafficfactory',
    'exoclick',
    'exosrv',
    'juicyads',
    'plugrush',
    'hilltopads',
    'clickadu',
    'evadav',
    'richpush',
    'pushground',
    'monetag',
    'ad-maven',
    'admaven',
    'bidvertiser',
    'revcontent',
    'mgid',
    'taboola',
    'outbrain',
    'clksite',
    'clkmon',
    'clickaine',
    'acint.net',
    'acscdn',
    'adsco',
    'syndication',
    'prebid',
    'amazon-adsystem',
    'facebook.com/tr',
    'shareasale',
    'affiliate',
    'landingtrack',
    'bongacams',
    'chaturbate',
    'livejasmin',
    'cam4',
    'stripchat',
    'bet365',
    'betway',
    '1xbet',
    'mostbet',
    'pinup',
    'vulkan',
    'casino',
    'gambling',
    'betting',
    'download-apk',
    'install-app',
    'popunderpop',
    'popupads',
    'adsterra',
    'notification-push',
    'push-notification',
    'onesignal',
    'pushwoosh',
    'pushcrew',
    'criteo',
    'smartadserver',
    'yieldmo',
    'pubmatic',
    'openx',
    'appnexus',
    'rubiconproject',
    'indexexchange',
    'medianet',
    'media.net',
    'disqusads',
    'outbrainimg',
    'zemanta',
    'ligatus',
    'contentad',
  ];

  static const _navBlock = [
    'google.com',
    'google.es',
    'google.co.',
    'facebook.com',
    'twitter.com',
    'instagram.com',
    'tiktok.com',
    'reddit.com',
    'linkedin.com',
    'bing.com',
    'yahoo.com',
    'duckduckgo.com',
    'amazon.com',
    'ebay.com',
    'aliexpress.com',
    'wikipedia.org',
    'microsoft.com',
    'play.google.com',
    'apps.apple.com',
  ];

  bool _isAd(String u) {
    final l = u.toLowerCase();
    for (final p in _adPat) {
      if (l.contains(p)) return true;
    }
    return false;
  }

  bool _navOk(String u) {
    final l = u.toLowerCase();
    if (l.startsWith('market://') ||
        l.startsWith('intent://') ||
        l.startsWith('blob:') ||
        l == 'about:blank') {
      return false;
    }
    if (_isAd(l)) return false;
    final h = _host(u);
    for (final b in _navBlock) {
      if (h.contains(b)) return false;
    }
    return true;
  }

  static String _host(String u) {
    try {
      return Uri.parse(u).host.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static String _root(String h) {
    final p = h.split('.');
    return p.length >= 2 ? '${p[p.length - 2]}.${p[p.length - 1]}' : h;
  }

  void _syncAllowed() {
    _allowed.clear();
    final h = _host(_vidUrl);
    if (h.isNotEmpty) {
      _allowed.add(_root(h));
      _allowed.add(h);
    }
  }

  // -----------------------------------------------------------------------
  // Computed
  // -----------------------------------------------------------------------

  String get _vidUrl {
    if (_servers.isEmpty) return '';
    return (_servers[_srvIdx]['enlace'] ?? '').toString();
  }

  String get _srvName {
    if (_servers.isEmpty) return '—';
    return (_servers[_srvIdx]['servidor'] ?? 'Servidor').toString();
  }

  String get _epName {
    if (widget.episodios.isEmpty) return '';
    return (widget.episodios[_epIdx]['episodio'] ?? 'Episodio').toString();
  }

  String get _episodeUrl {
    if (widget.episodios.isEmpty) return '';
    return (widget.episodios[_epIdx]['url'] ?? '').toString();
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  Timer? _orientationTimer;

  @override
  void initState() {
    super.initState();
    _epIdx = widget.initialEpisodeIndex;
    _srvIdx = widget.initialServerIndex;
    _servers = List<Map<String, dynamic>>.from(widget.servidores);
    _syncAllowed();
    _forceLandscape();
    // Re-forzar varias veces: el WebView puede resetear la orientación.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceLandscape();
      _loadIntroSkip(_episodeUrl);
    });
    _orientationTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (t) {
        if (t.tick >= 6) {
          t.cancel();
          return;
        } // 3 segundos
        if (mounted) _forceLandscape();
      },
    );
  }

  Future<void> _forceLandscape() async {
    // Llamar AMBOS: nativo (Activity) + Flutter (SystemChrome).
    try {
      await _chan.invokeMethod('forceLandscape');
    } catch (_) {}
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _resetOrientation() async {
    try {
      await _chan.invokeMethod('resetOrientation');
    } catch (_) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _orientationTimer?.cancel();
    _hideTimer?.cancel();
    _loadTimer?.cancel();
    _progressTimer?.cancel();
    unawaited(_persistPlaybackProgress(force: true));
    _resetOrientation();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Overlay show / auto-hide
  // -----------------------------------------------------------------------

  void _reveal() {
    setState(() => _showUI = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_isDraggingSlider) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDraggingSlider) setState(() => _showUI = false);
    });
  }

  void _startProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (!mounted || _wvc == null) return;
      unawaited(_syncPlaybackState());
    });
  }

  Future<void> _syncPlaybackState() async {
    // Throttle cleanup JS — solo cada ~3s (tick*4) en vez de cada 750ms.
    _progressTick++;
    if (_progressTick % 4 == 0) {
      unawaited(_injectCleanupJS());
    }
    final info = await _getPlaybackInfo();
    if (!mounted || info.isEmpty) return;

    final playing = info['playing'] == true;
    final muted = info['muted'] == true;
    final position = (info['currentTime'] as num?)?.toDouble() ?? 0;
    final duration = (info['duration'] as num?)?.toDouble() ?? 0;
    final bufferedEnd = (info['bufferedEnd'] as num?)?.toDouble() ?? 0;

    final safePos = position.isFinite && position >= 0 ? position : 0.0;
    final safeDur = duration.isFinite && duration > 0 ? duration : 0.0;
    final safeBuf = bufferedEnd.isFinite && bufferedEnd > 0 ? bufferedEnd : 0.0;
    final inIntro = _introStart != null &&
        _introEnd != null &&
        safePos >= _introStart! &&
        safePos <= _introEnd!;

    // Actualiza campos internos SIN setState cuando no hay UI visible:
    // evita rebuilds del WebView mientras el usuario solo está mirando.
    // Durante el cooldown post-seek, no pisamos _videoPosition con la
    // posición vieja que aún devuelve el video hasta que confirme el salto.
    final seekActive = DateTime.now().difference(_lastSeekAt) < _kSeekCooldown;
    final seekLanded = seekActive && (safePos - _videoPosition).abs() < 2.0;
    if (!seekActive || seekLanded) {
      _videoPosition = safePos;
      if (seekLanded) {
        _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    _videoDuration = safeDur;
    _videoBufferedEnd = safeBuf;
    _isPlaying = playing;
    _isMuted = muted;

    // Si el video está reproduciéndose de verdad, marca este servidor como
    // el preferido para este episodio. La próxima vez que el usuario abra
    // el mismo episodio, empezaremos por este antes de rotar.
    if (playing && !_bestServerRecorded) {
      _bestServerRecorded = true;
      final enlace = _vidUrl;
      if (enlace.isNotEmpty) {
        unawaited(saveBestServer(_episodeUrl, enlace));
        setAnimePreferredServer(widget.animeUrl, _srvName);
      }
    }

    final shouldRebuild =
        _showUI || _showSkipIntro != inIntro || (playing && _showTapToPlay);

    if (shouldRebuild) {
      setState(() {
        _showSkipIntro = inIntro;
        if (playing) _showTapToPlay = false;
      });
    } else {
      _showSkipIntro = inIntro;
    }

    unawaited(_handleNearEndCompletion(
      position: safePos,
      duration: _videoDuration,
    ));
    unawaited(_persistPlaybackProgress());
  }

  Future<void> _handleNearEndCompletion({
    required double position,
    required double duration,
  }) async {
    final episodeUrl = _episodeUrl;
    if (_markedWatched || episodeUrl.isEmpty || duration <= 0) return;

    final remaining = duration - position;
    final nearEndByRatio = (position / duration) >= 0.90;
    final nearEndByTime = remaining <= 60;
    if (!nearEndByRatio && !nearEndByTime) return;

    _markedWatched = true;
    await WatchHistory.markEpisodeWatched(episodeUrl);
    await WatchHistory.handleEpisodeFinished(
      widget.animeUrl,
      animeIsFinished: _animeIsFinished,
    );
    await WatchHistory.clearEpisodeProgress(episodeUrl);
  }

  // -----------------------------------------------------------------------
  // Load / retry / server / episode
  // -----------------------------------------------------------------------

  void _load(String url) {
    _loadTimer?.cancel();
    _progressTimer?.cancel();
    _retries = 0;
    _bestServerRecorded = false;
    _syncAllowed();
    setState(() {
      _loading = true;
      _error = null;
      _showTapToPlay = false;
      _isPlaying = false;
      _isMuted = false;
      _videoPosition = 0;
      _videoDuration = 0;
      _videoBufferedEnd = 0;
      _markedWatched = false;
      _lastSavedProgress = -1;
      _showSkipIntro = false;
    });
    _wvc?.stopLoading();
    _wvc?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    _loadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_loading) return;
      _tryNext('Servidor tardó demasiado.');
    });
  }

  void _reload() {
    _load(_vidUrl);
    _scheduleHide();
  }

  void _tryNext(String reason) {
    if (_servers.length > 1 && _retries < _servers.length - 1) {
      _retries++;
      _srvIdx = (_srvIdx + 1) % _servers.length;
      _syncAllowed();
      setState(() {
        _loading = true;
        _error = null;
      });
      _wvc?.stopLoading();
      _wvc?.loadUrl(urlRequest: URLRequest(url: WebUri(_vidUrl)));
      _loadTimer?.cancel();
      _loadTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted || !_loading) return;
        _tryNext(reason);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$reason Probando $_srvName...'),
          duration: const Duration(seconds: 2),
        ));
      }
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$reason Prueba otro servidor.';
        });
      }
    }
  }

  void _cycleServer() {
    if (_servers.length <= 1) return;
    unawaited(_persistPlaybackProgress(force: true));
    _srvIdx = (_srvIdx + 1) % _servers.length;
    _load(_vidUrl);
    _scheduleHide();
  }

  Future<void> _handleLoadStop() async {
    _loadTimer?.cancel();
    if (!mounted) return;

    unawaited(_injectCleanupJS());
    if (_isFitted) {
      unawaited(_applyFitToVideo());
    }
    // WebView puede sacar al sistema del immersive mode; re-forzar.
    unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));

    setState(() {
      _loading = true;
      _showTapToPlay = false;
    });

    final played = await _waitForNaturalPlayback();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _showTapToPlay = !played;
    });

    _startProgressPolling();
    unawaited(_syncPlaybackState());
    unawaited(_restoreSavedProgress());
  }

  Future<void> _handleTapToPlay() async {
    if (_attemptingPlay || !mounted) return;

    final played = await _forcePlayback();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _showTapToPlay = !played;
    });

    unawaited(_syncPlaybackState());
    unawaited(_restoreSavedProgress());
  }

  Future<bool> _waitForNaturalPlayback() async {
    if (_wvc == null) return false;

    await _attemptPlayOnce();

    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (await _isVideoPlaying()) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return await _isVideoPlaying();
  }

  Future<bool> _forcePlayback() async {
    if (_wvc == null) return false;
    if (_attemptingPlay) return false;

    _attemptingPlay = true;
    try {
      await _attemptPlayOnce();

      final deadline = DateTime.now().add(const Duration(seconds: 6));
      while (mounted && DateTime.now().isBefore(deadline)) {
        if (await _isVideoPlaying()) return true;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      return await _isVideoPlaying();
    } finally {
      _attemptingPlay = false;
    }
  }

  Future<bool> _isVideoPlaying() async {
    final status = await _getVideoStatus();
    return status == 'playing';
  }

  Future<void> _restoreSavedProgress() async {
    final resumePosition = await WatchHistory.getEpisodeProgress(_episodeUrl);
    if (!mounted || resumePosition == null || resumePosition <= 5) return;

    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final info = await _getPlaybackInfo();
      if (!mounted || info.isEmpty) return;

      final duration = (info['duration'] as num?)?.toDouble() ?? 0;
      if (duration <= 0) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }

      final isNearEnd = resumePosition >= duration * 0.95 ||
          (duration - resumePosition) <= 10;
      if (isNearEnd) return;

      await _seekVideoTo(resumePosition);
      return;
    }
  }

  Future<Map<String, dynamic>> _getPlaybackInfo() async {
    final result = await _runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) {
    return JSON.stringify({ playing: false, muted: true, currentTime: 0, duration: 0, bufferedEnd: 0 });
  }

  let bufferedEnd = 0;
  try {
    if (video.buffered && video.buffered.length > 0) {
      bufferedEnd = video.buffered.end(video.buffered.length - 1);
      if (!Number.isFinite(bufferedEnd) || bufferedEnd < 0) {
        bufferedEnd = 0;
      }
    }
  } catch (_) {
    bufferedEnd = 0;
  }

  return JSON.stringify({
    playing: !video.paused && !video.ended && video.readyState >= 2,
    muted: !!video.muted,
    currentTime: Number.isFinite(video.currentTime) ? video.currentTime : 0,
    duration: Number.isFinite(video.duration) ? video.duration : 0,
    bufferedEnd: bufferedEnd,
  });
})()
''');

    final text = result?.toString().trim() ?? '';
    if (text.isEmpty) return {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  Future<void> _attemptPlayOnce() async {
    final shouldForceMute = _isMuted;
    await _runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) return 'no-video';

  try {
    video.autoplay = true;
    video.playsInline = true;
    video.setAttribute('playsinline', 'true');
    video.setAttribute('webkit-playsinline', 'true');
    // Intentar sin mute; si falla, mute + play + desmutear
    video.muted = false;
    if ($shouldForceMute) {
      video.muted = true;
      video.setAttribute('muted', 'true');
    }
  } catch (_) {}

  try {
    const promise = video.play();
    if (promise && typeof promise.then === 'function') {
      promise.then(() => {
        // Si arrancó muteado, desmutear con volumen alto
        if (video.muted) {
          video.muted = false;
          video.volume = 1.0;
        }
      }).catch(() => {
        // Autoplay bloqueado sin mute → intentar con mute + desmutear luego
        video.muted = true;
        const retry = video.play();
        if (retry && typeof retry.then === 'function') {
          retry.then(() => {
            setTimeout(() => { video.muted = false; video.volume = 1.0; }, 500);
          }).catch(() => null);
        }
      });
    }
    return 'play-requested';
  } catch (error) {
    return 'blocked:' + (error?.message || String(error));
  }
})();
''');
  }

  Future<void> _persistPlaybackProgress({bool force = false}) async {
    final episodeUrl = _episodeUrl;
    final duration = _videoDuration;
    final position = _videoPosition;

    if (episodeUrl.isEmpty || duration <= 0) return;

    final difference = (position - _lastSavedProgress).abs();
    final shouldSave = force ||
        _lastSavedProgress < 0 ||
        (_isPlaying && difference >= 5) ||
        (!_isPlaying && difference >= 0.5);
    if (!shouldSave) return;

    _lastSavedProgress = position;
    // The DB layer ignores near-start/near-end positions automatically,
    // so it's safe to call this with any value — no data will be lost.
    await WatchHistory.saveEpisodeProgress(
      episodeUrl: episodeUrl,
      position: position,
      duration: duration,
    );
  }

  Future<void> _toggleMute() async {
    await _runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) return 'no-video';
  try {
    video.muted = !video.muted;
    if (!video.muted && video.volume < 0.8) {
      video.volume = 0.8;
    }
    return video.muted ? 'muted' : 'unmuted';
  } catch (error) {
    return 'blocked:' + (error?.message || String(error));
  }
})();
''');
    unawaited(_syncPlaybackState());
    _scheduleHide();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _runVideoScript('''
(() => {
  const applyRate = (video) => {
    try { video.playbackRate = $speed; } catch (_) {}
  };

  const direct = Array.from(document.querySelectorAll('video'));
  direct.forEach(applyRate);

  const frames = Array.from(document.querySelectorAll('iframe'));
  for (const frame of frames) {
    try {
      const doc = frame.contentDocument || frame.contentWindow?.document;
      if (!doc) continue;
      const nested = doc.querySelectorAll('video');
      nested.forEach(applyRate);
    } catch (_) {}
  }
})();
''');
    if (mounted) setState(() {});
  }

  Future<void> _applyFitToVideo() async {
    await _runVideoScript('''
(() => {
  const fit = ${_isFitted ? "'cover'" : "'contain'"};
  const applyFit = (video) => {
    try { video.style.setProperty('object-fit', fit, 'important'); } catch (_) {}
  };

  const direct = Array.from(document.querySelectorAll('video'));
  direct.forEach(applyFit);

  const frames = Array.from(document.querySelectorAll('iframe'));
  for (const frame of frames) {
    try {
      const doc = frame.contentDocument || frame.contentWindow?.document;
      if (!doc) continue;
      const nested = doc.querySelectorAll('video');
      nested.forEach(applyFit);
    } catch (_) {}
  }
})();
''');
  }

  Future<void> _toggleFit() async {
    _isFitted = !_isFitted;
    await _applyFitToVideo();
    if (mounted) setState(() {});
    _scheduleHide();
  }

  Future<String> _getVideoStatus() async {
    final result = await _runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) return 'no-video';
  if (video.ended) return 'ended';
  if (!video.paused && video.readyState >= 2) return 'playing';
  if (video.paused) return 'paused';
  return 'loading';
})();
''');
    return result?.toString().trim() ?? '';
  }

  Future<dynamic> _runVideoScript(String script) async {
    return _wvc?.evaluateJavascript(source: script);
  }

  /// Limpia el WebView: quita controles nativos del <video>, oculta player UIs
  /// embebidos (Plyr, JW, VideoJS…) y overlays de ads grandes.
  Future<void> _injectCleanupJS() async {
    await _runVideoScript(r'''
(() => {
  /* ── 0. Anti-popup (una sola vez por documento) ── */
  if (!window.__apop) {
    window.__apop = true;
    const here = () => location.hostname;
    const sameOrigin = (u) => {
      try { return new URL(u, location.href).hostname === here(); }
      catch (_) { return true; }
    };
    /* Neutralizar APIs que disparan popups/diálogos */
    try { window.open = function(){ return null; }; } catch (_) {}
    try { window.alert = function(){}; } catch (_) {}
    try { window.confirm = function(){ return false; }; } catch (_) {}
    try { window.prompt  = function(){ return null; }; } catch (_) {}
    try {
      window.addEventListener('beforeunload', e => { e.stopImmediatePropagation(); }, true);
    } catch (_) {}
    /* Quitar target=_blank de todo <a> (y neutralizar clics a dominios externos) */
    const scrub = (root) => {
      const scope = root && root.querySelectorAll ? root : document;
      scope.querySelectorAll('a[target]').forEach(a => {
        const t = (a.getAttribute('target') || '').toLowerCase();
        if (t === '_blank' || t === 'blank') a.removeAttribute('target');
      });
      scope.querySelectorAll('form[target]').forEach(f => {
        const t = (f.getAttribute('target') || '').toLowerCase();
        if (t === '_blank' || t === 'blank') f.removeAttribute('target');
      });
    };
    scrub(document);
    /* Captura en fase temprana: bloquea clics/touch que llevan fuera del host */
    const block = (e) => {
      let n = e.target;
      while (n && n !== document.body && n.nodeType === 1) {
        if (n.tagName === 'A') {
          const href = n.getAttribute('href') || '';
          if (href && !href.startsWith('#') &&
              !href.toLowerCase().startsWith('javascript:') &&
              !sameOrigin(href)) {
            e.preventDefault();
            e.stopImmediatePropagation();
            return;
          }
          break;
        }
        n = n.parentElement;
      }
    };
    ['click','mousedown','mouseup','auxclick','pointerdown','touchstart','touchend']
      .forEach(ev => document.addEventListener(ev, block, true));
    /* Observador: limpia elementos añadidos dinámicamente (popunders tardíos) */
    const adRe = /popup|popunder|modal|overlay|banner|\bads?\b|promo|interstitial|sponsor/i;
    const adSrcRe = /pop|ads?[-_.]|banner|propeller|hilltop|clickadu|adsterra|trafficjunky|exoclick|juicyads|monetag/i;
    const mo = new MutationObserver(muts => {
      muts.forEach(m => {
        m.addedNodes.forEach(n => {
          if (!n || n.nodeType !== 1) return;
          /* iframes sospechosos fuera del video */
          if (n.tagName === 'IFRAME') {
            const src = (n.src || n.getAttribute('src') || '').toLowerCase();
            if (src && adSrcRe.test(src) && !sameOrigin(src)) {
              n.remove();
              return;
            }
          }
          /* scripts publicitarios inyectados */
          if (n.tagName === 'SCRIPT') {
            const src = (n.src || '').toLowerCase();
            if (src && adSrcRe.test(src)) { n.remove(); return; }
          }
          /* nodos con clases/ids que delatan ad */
          const cls = (n.className && n.className.baseVal) || n.className || '';
          const id  = n.id || '';
          if ((cls && adRe.test(String(cls))) || (id && adRe.test(id))) {
            /* no borrar si contiene el <video> */
            if (!(n.querySelector && n.querySelector('video'))) n.remove();
          }
        });
      });
      scrub(document);
    });
    try {
      mo.observe(document.documentElement || document, {
        childList: true, subtree: true, attributes: true, attributeFilter: ['target','href'],
      });
    } catch (_) {}
  }

  /* ── 1. Inyectar CSS persistente (una sola vez) ── */
  if (!document.getElementById('__acss')) {
    const s = document.createElement('style');
    s.id = '__acss';
    s.textContent = `
      /* — Ocultar controles nativos de <video> — */
      video::-webkit-media-controls,
      video::-webkit-media-controls-enclosure,
      video::-webkit-media-controls-panel,
      video::-webkit-media-controls-overlay-play-button,
      video::-webkit-media-controls-start-playback-button {
        display:none!important; -webkit-appearance:none!important;
      }

      /* — Player UIs conocidos — */
      .plyr__controls,.plyr__control,.plyr__menu,.plyr__poster,
      .plyr__captions,.plyr--full-ui .plyr__video-wrapper::after,
      .jw-controls,.jw-controlbar,.jw-display,.jw-logo,.jw-title,
      .jw-dock,.jw-nextup-container,.jw-overlays,.jw-icon,.jw-slider-time,
      .vjs-control-bar,.vjs-loading-spinner,.vjs-big-play-button,.vjs-poster,
      .vjs-text-track-display,.vjs-modal-dialog,
      .fp-controls,.fp-ui,.fp-logo,
      .bmpui-ui-container,.op-controls,.op-overlay,
      .mejs__controls,.mejs__overlay,
      .html5-video-player .ytp-chrome-bottom,
      [class*="player-controls"],[class*="player-ui"],[class*="player-overlay"],
      [class*="control-bar"],[class*="controlbar"],[class*="controls-wrapper"],
      [class*="play-button"],[class*="play_button"],[class*="play-btn"],
      [class*="video-overlay"],[class*="video_overlay"],
      [class*="ad-overlay"],[class*="ad_overlay"],
      [class*="popup"],[class*="modal"],[class*="banner"],[class*="close-btn"] {
        display:none!important;opacity:0!important;
        visibility:hidden!important;pointer-events:none!important;
      }

      /* — Video a pantalla completa — */
      video {
        width:100vw!important;height:100vh!important;
        object-fit:contain!important;
        position:fixed!important;top:0!important;left:0!important;
        z-index:2147483647!important;background:#000!important;
      }

      html,body {
        margin:0!important;padding:0!important;
        overflow:hidden!important;background:#000!important;
      }
    `;
    (document.head || document.documentElement).appendChild(s);
  }

  /* ── 2. Strip atributo controls ── */
  document.querySelectorAll('video').forEach(v => {
    v.controls = false;
    v.removeAttribute('controls');
  });

  /* ── 3. Ocultar overlays grandes fixed/absolute (ads) ── */
  const vidAnc = new Set();
  document.querySelectorAll('video').forEach(v => {
    let p = v.parentElement;
    while (p) { vidAnc.add(p); p = p.parentElement; }
  });
  document.querySelectorAll('div,aside,section,nav').forEach(el => {
    if (vidAnc.has(el) || el.querySelector('video')) return;
    const cs = window.getComputedStyle(el);
    if (cs.position !== 'fixed' && cs.position !== 'absolute') return;
    const r = el.getBoundingClientRect();
    if (r.width > window.innerWidth * 0.3 && r.height > window.innerHeight * 0.2) {
      el.style.setProperty('display','none','important');
    }
  });
})();
''');
  }

  Future<void> _showSettingsSheet() async {
    final qualities = await _getAvailableQualities();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.dns_rounded,
                              color: VoidTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Servidor',
                              style: GoogleFonts.sora(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._servers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final srv = entry.value;
                      final label = (srv['servidor'] ?? 'Servidor').toString();
                      final active = idx == _srvIdx;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: active ? VoidTheme.primary : Colors.white38,
                          size: 20,
                        ),
                        title: Text(label,
                            style: GoogleFonts.sora(
                              color: active ? VoidTheme.primary : Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w400,
                            )),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_srvIdx != idx) {
                            unawaited(_persistPlaybackProgress(force: true));
                            setState(() => _srvIdx = idx);
                            _load(_vidUrl);
                          }
                        },
                      );
                    }),
                    const Divider(
                        color: Colors.white12,
                        height: 24,
                        indent: 20,
                        endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text('Audio',
                              style: GoogleFonts.sora(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        _isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: _isMuted ? VoidTheme.pink : VoidTheme.cyan,
                        size: 20,
                      ),
                      title: Text(
                        _isMuted ? 'Silenciado' : 'Sonido activado',
                        style: GoogleFonts.sora(
                          color: _isMuted ? VoidTheme.pink : VoidTheme.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () async {
                        await _toggleMute();
                        setSheetState(() {});
                      },
                    ),
                    const Divider(
                        color: Colors.white12,
                        height: 24,
                        indent: 20,
                        endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.hd_rounded,
                              color: VoidTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Calidad',
                              style: GoogleFonts.sora(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (qualities.isEmpty)
                      ListTile(
                        dense: true,
                        title: Text('No disponible',
                            style: GoogleFonts.sora(
                                color: Colors.white54, fontSize: 13)),
                      )
                    else
                      ...qualities.map((q) {
                        final label = (q['label'] ?? '?').toString();
                        final active = q['active'] == true;
                        final idx = q['index'] as int? ?? 0;
                        final type = q['type']?.toString() ?? 'hls';
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            active
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: active ? VoidTheme.primary : Colors.white38,
                            size: 20,
                          ),
                          title: Text(label,
                              style: GoogleFonts.sora(
                                color:
                                    active ? VoidTheme.primary : Colors.white,
                                fontSize: 13,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w400,
                              )),
                          onTap: () {
                            Navigator.pop(ctx);
                            _setQuality(idx, type);
                          },
                        );
                      }),
                    const Divider(
                        color: Colors.white12,
                        height: 24,
                        indent: 20,
                        endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded,
                              color: VoidTheme.cyan, size: 20),
                          const SizedBox(width: 8),
                          Text('Velocidad',
                              style: GoogleFonts.sora(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      final active = _playbackSpeed == speed;
                      final label = speed == 1.0 ? 'Normal' : '${speed}x';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: active ? VoidTheme.cyan : Colors.white38,
                          size: 20,
                        ),
                        title: Text(label,
                            style: GoogleFonts.sora(
                              color: active ? VoidTheme.cyan : Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w400,
                            )),
                        onTap: () async {
                          await _setPlaybackSpeed(speed);
                          setSheetState(() {});
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Quality selector
  // -----------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getAvailableQualities() async {
    final result = await _runVideoScript('''
(() => {
  // 1) hls.js
  const video = document.querySelector('video');
  if (video) {
    const hls = Object.values(video).find(v => v && v.levels);
    if (hls && hls.levels && hls.levels.length > 1) {
      const levels = hls.levels.map((l, i) => ({
        index: i,
        height: l.height || 0,
        label: l.height ? l.height + 'p' : 'Level ' + i,
        type: 'hls',
        active: hls.currentLevel === i,
      }));
      return JSON.stringify([{ index: -1, height: 0, label: 'Auto', type: 'hls', active: hls.currentLevel === -1 }, ...levels]);
    }
  }

  // 2) JWPlayer
  if (typeof jwplayer === 'function') {
    const jw = jwplayer();
    if (jw && jw.getQualityLevels) {
      const levels = jw.getQualityLevels();
      if (levels && levels.length > 1) {
        const current = jw.getCurrentQuality();
        return JSON.stringify(levels.map((l, i) => ({
          index: i,
          height: l.height || 0,
          label: l.label || (l.height ? l.height + 'p' : 'Level ' + i),
          type: 'jw',
          active: current === i,
        })));
      }
    }
  }

  // 3) Plyr
  const plyrEl = document.querySelector('.plyr');
  if (plyrEl && plyrEl.plyr) {
    const p = plyrEl.plyr;
    if (p.options && p.options.quality && p.options.quality.length > 1) {
      return JSON.stringify(p.options.quality.map((q, i) => ({
        index: i,
        height: typeof q === 'number' ? q : 0,
        label: typeof q === 'number' ? q + 'p' : String(q),
        type: 'plyr',
        active: p.quality === q,
      })));
    }
  }

  return '[]';
})();
''');

    final text = result?.toString().trim() ?? '[]';
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _setQuality(int index, String type) async {
    await _runVideoScript('''
(() => {
  const type = '$type';
  const idx = $index;

  if (type === 'hls') {
    const video = document.querySelector('video');
    if (!video) return;
    const hls = Object.values(video).find(v => v && v.levels);
    if (hls) { hls.currentLevel = idx; hls.loadLevel = idx; }
    return;
  }

  if (type === 'jw') {
    if (typeof jwplayer === 'function') {
      jwplayer().setCurrentQuality(idx);
    }
    return;
  }

  if (type === 'plyr') {
    const plyrEl = document.querySelector('.plyr');
    if (plyrEl && plyrEl.plyr && plyrEl.plyr.options && plyrEl.plyr.options.quality) {
      plyrEl.plyr.quality = plyrEl.plyr.options.quality[idx];
    }
    return;
  }
})();
''');
  }

  Future<void> _togglePlayback() async {
    if (_playToggleBusy || !mounted) return;
    _playToggleBusy = true;
    final shouldPlay = !_isPlaying;

    // Optimistic UI: reflect intent instantly, then reconcile with polling.
    setState(() {
      _isPlaying = shouldPlay;
    });
    _scheduleHide();

    try {
      if (shouldPlay) {
        await _forcePlayback();
      } else {
        await _pauseVideo();
      }
    } finally {
      _playToggleBusy = false;
      unawaited(_syncPlaybackState());
    }
  }

  Future<void> _pauseVideo() async {
    await _runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) return 'no-video';
  try {
    video.pause();
    return 'paused';
  } catch (error) {
    return 'blocked:' + (error?.message || String(error));
  }
})();
''');
  }

  Future<void> _seekVideoBy(int seconds) async {
    final target = (_videoPosition + seconds)
        .clamp(0.0, _videoDuration > 0 ? _videoDuration : double.infinity);
    _lastSeekAt = DateTime.now();
    _videoPosition = target.toDouble();
    if (mounted) setState(() {});
    _scheduleHide();
    unawaited(_runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) return 'no-video';
  try {
    video.currentTime = Math.max(0, (video.currentTime || 0) + $seconds);
    return 'seeked';
  } catch (error) {
    return 'blocked:' + (error?.message || String(error));
  }
})();
'''));
    unawaited(_syncPlaybackState());
    return;
  }

  Future<void> _seekVideoTo(double position) async {
    final double safePosition =
        position.isFinite && position >= 0 ? position : 0.0;
    _lastSeekAt = DateTime.now();
    _videoPosition = safePosition;
    if (mounted) setState(() {});
    _scheduleHide();
    unawaited(_runVideoScript('''
(() => {
  const video = (() => {
    const direct = Array.from(document.querySelectorAll('video'));
    if (direct.length > 0) return direct[0];

    const frames = Array.from(document.querySelectorAll('iframe'));
    for (const frame of frames) {
      try {
        const doc = frame.contentDocument || frame.contentWindow?.document;
        if (!doc) continue;
        const nested = doc.querySelector('video');
        if (nested) return nested;
      } catch (_) {}
    }

    return null;
  })();

  if (!video) return 'no-video';
  try {
    video.currentTime = $safePosition;
    return 'seeked';
  } catch (error) {
    return 'blocked:' + (error?.message || String(error));
  }
})();
'''));
    unawaited(_syncPlaybackState());
  }

  // ── Intro skip ────────────────────────────────────────────────────

  Future<void> _loadIntroSkip(String epUrl) async {
    if (epUrl.isEmpty) return;
    final service = ref.read(animeServiceProvider);
    final skip = await service.getIntroSkip(epUrl);
    if (!mounted) return;
    setState(() {
      _introStart = skip?.start;
      _introEnd = skip?.end;
    });
  }

  void _skipIntro() {
    if (_introEnd == null) return;
    unawaited(_seekVideoTo(_introEnd!));
    _scheduleHide();
  }

  Future<void> _changeEp(int d) async {
    final n = _epIdx + d;
    if (n < 0 || n >= widget.episodios.length) return;
    setState(() {
      _fetching = true;
      _loading = true;
      _epIdx = n;
      _introStart = null;
      _introEnd = null;
      _showSkipIntro = false;
    });
    unawaited(_persistPlaybackProgress(force: true));
    try {
      final url = (widget.episodios[n]['url'] ?? '').toString();
      final epName = (widget.episodios[n]['episodio'] ?? 'Episodio').toString();
      await WatchHistory.add(
        titulo: widget.animeTitle,
        url: widget.animeUrl,
        imagen: widget.animeImage,
        lastEpisodeUrl: url,
        lastEpisodeName: epName,
        lastKnownEpisodeCount: widget.episodios.length,
        estado: widget.animeStatus,
      );
      final s = await ref.read(animeServiceProvider).getServidores(url);
      final sorted = AnimeService.sortServersByPriority(s);
      final ordered =
          await applyPreferredServerOrder(sorted, url, widget.animeUrl);
      setState(() {
        _servers = ordered;
        _srvIdx = 0;
        _fetching = false;
        _markedWatched = false;
      });
      if (_servers.isNotEmpty) _load(_vidUrl);
      unawaited(_loadIntroSkip(url));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _loading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    _scheduleHide();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---- 1. WebView (fondo, el video real) ----
          // RepaintBoundary aísla al WebView de los repaints de la barra
          // de progreso / controles para evitar lag.
          RepaintBoundary(
            child: AbsorbPointer(
              absorbing: true,
              child: _buildWV(),
            ),
          ),

          // ---- 2. Fallback manual de autoplay ----
          if (_showTapToPlay) _tapToPlayOverlay(),

          // ---- 3. Overlay de controles ----
          if (!_showTapToPlay && _showUI) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showUI = false),
                child: Container(color: const Color(0x44000000)),
              ),
            ),
            _topBar(top),
            _bottomBar(bot),
          ],

          // ---- 4. Botón para mostrar controles (cuando están ocultos) ----
          if (!_showTapToPlay && !_showUI)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _reveal,
              ),
            ),

          // ---- 5. Skip intro ----
          if (!_loading && !_fetching && _error == null)
            SkipIntroButton(
              visible: _showSkipIntro,
              onSkip: _skipIntro,
            ),

          // ---- 6. Loading (fullscreen overlay hasta que el video esté listo) ----
          if (_loading || _fetching)
            Positioned.fill(
              child: Container(
                color: Colors.black, // acts as barrier
                child: const LoadingEpisodeOverlay(),
              ),
            ),

          // ---- 6b. Barra mínima de acceso (visible durante carga / tap-to-play) ----
          if (_loading || _fetching || _showTapToPlay) _accessBar(top),

          // ---- 7. Error ----
          if (_error != null) _errorOverlay(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // WebView – render con autoplay controlado por JS
  // -----------------------------------------------------------------------

  Widget _buildWV() {
    return InAppWebView(
      key: _wvKey,
      initialUrlRequest: URLRequest(url: WebUri(_vidUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useShouldOverrideUrlLoading: true,
        useShouldInterceptRequest: true,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        allowsBackForwardNavigationGestures: false,
        geolocationEnabled: false,
        transparentBackground: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        cacheEnabled: true,
        userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/124.0.0.0 Mobile Safari/537.36',
      ),
      onWebViewCreated: (c) => _wvc = c,
      shouldInterceptRequest: (_, req) async {
        if (_isAd(req.url.toString())) {
          return WebResourceResponse(
            contentType: 'text/plain',
            contentEncoding: 'utf-8',
            data: Uint8List(0),
            statusCode: 200,
            reasonPhrase: 'OK',
          );
        }
        return null;
      },
      shouldOverrideUrlLoading: (_, action) async {
        final u = action.request.url?.toString() ?? '';
        if (u.isEmpty) return NavigationActionPolicy.ALLOW;
        final h = _host(u);
        if (h.isNotEmpty && !_isAd(u) && !_navBlock.any((b) => h.contains(b))) {
          _allowed.add(_root(h));
        }
        return _navOk(u)
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (_, __) async => false,
      onLoadStop: (_, __) => _handleLoadStop(),
      onReceivedError: (_, req, err) {
        if (req.isForMainFrame ?? false) {
          _loadTimer?.cancel();
          if (mounted) _tryNext('Error: ${err.description}.');
        }
      },
      onReceivedHttpError: (_, req, res) {
        if (req.isForMainFrame ?? false) {
          _loadTimer?.cancel();
          if (mounted) _tryNext('Error HTTP ${res.statusCode}.');
        }
      },
    );
  }

  Widget _tapToPlayOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0x99000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_handleTapToPlay()),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VoidTheme.primary.withOpacity(0.15),
                        border:
                            Border.all(color: VoidTheme.primary, width: 2.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 14),
                    Text('Toca para reproducir',
                        style: GoogleFonts.sora(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_servers.length > 1)
                TextButton.icon(
                  onPressed: _showSettingsSheet,
                  icon: const Icon(Icons.dns_rounded,
                      color: VoidTheme.primary, size: 18),
                  label: Text('Cambiar servidor ($_srvName)',
                      style: GoogleFonts.sora(
                        color: VoidTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Barra de acceso mínima visible durante carga y tap-to-play,
  // para poder volver, recargar o abrir ajustes (cambiar servidor)
  // sin quedar atrapado si el servidor actual no responde.
  Widget _accessBar(double top) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(top: top + 4, left: 4, right: 8, bottom: 20),
        child: SafeArea(
          bottom: false,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white70, size: 22),
              tooltip: 'Recargar',
              onPressed: _reload,
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded,
                  color: Colors.white70, size: 22),
              tooltip: 'Ajustes',
              onPressed: _showSettingsSheet,
            ),
          ]),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Top bar: estilo nativo
  // -----------------------------------------------------------------------

  Widget _topBar(double top) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(top: top + 4, left: 4, right: 8, bottom: 20),
        child: SafeArea(
          bottom: false,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.animeTitle,
                      style:
                          GoogleFonts.sora(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_epName,
                      style: GoogleFonts.sora(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white70, size: 22),
              tooltip: 'Recargar',
              onPressed: _reload,
            ),
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded,
                  color: Colors.white70, size: 22),
              tooltip: 'Ajustar pantalla',
              onPressed: _toggleFit,
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded,
                  color: Colors.white70, size: 22),
              tooltip: 'Ajustes',
              onPressed: _showSettingsSheet,
            ),
          ]),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Bottom bar: estilo nativo (timeline + transporte)
  // -----------------------------------------------------------------------

  Widget _bottomBar(double bot) {
    final hasPrev = _epIdx > 0;
    final hasNext = _epIdx < widget.episodios.length - 1;
    final duration = _videoDuration;
    final position = _videoPosition.clamp(0.0, duration > 0 ? duration : 1.0);
    final maxVal = duration > 0 ? duration : 1.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(bottom: bot + 8, left: 12, right: 12, top: 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: GoogleFonts.sora(
                      color: VoidTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: VoidTheme.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: VoidTheme.primary,
                          overlayColor: VoidTheme.primary.withOpacity(0.2),
                          secondaryActiveTrackColor: Colors.white30,
                        ),
                        child: Slider(
                          min: 0,
                          max: maxVal,
                          value: position.clamp(0.0, maxVal),
                          secondaryTrackValue:
                              _videoBufferedEnd.clamp(0.0, maxVal),
                          onChangeStart: duration > 0
                              ? (_) {
                                  _hideTimer?.cancel();
                                  setState(() => _isDraggingSlider = true);
                                }
                              : null,
                          onChanged: duration > 0
                              ? (v) => setState(() => _videoPosition = v)
                              : null,
                          onChangeEnd: duration > 0
                              ? (v) {
                                  setState(() => _isDraggingSlider = false);
                                  unawaited(_seekVideoTo(v));
                                  _scheduleHide();
                                }
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    duration > 0 ? _formatDuration(duration) : '--:--',
                    style: GoogleFonts.sora(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded,
                          color: hasPrev ? Colors.white : Colors.white24,
                          size: 32),
                      onPressed: hasPrev ? () => _changeEp(-1) : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.fast_rewind_rounded,
                          color: Colors.white, size: 32),
                      onPressed: () => _seekVideoBy(-10),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: _togglePlayback,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.fast_forward_rounded,
                          color: Colors.white, size: 32),
                      onPressed: () => _seekVideoBy(10),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded,
                          color: hasNext ? Colors.white : Colors.white24,
                          size: 32),
                      onPressed: hasNext ? () => _changeEp(1) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(num seconds) {
    final value = seconds.toDouble();
    if (!value.isFinite || value < 0) return '00:00';
    final total = value.floor();
    final minutes = total ~/ 60;
    final remaining = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  // -----------------------------------------------------------------------
  // Error
  // -----------------------------------------------------------------------

  Widget _errorOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: VoidTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoidTheme.cardBorder),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: VoidTheme.pink, size: 44),
          const SizedBox(height: 12),
          Text('No se pudo reproducir',
              style: GoogleFonts.sora(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_error!,
              style: GoogleFonts.sora(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _error = null);
                _load(_vidUrl);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
            ),
            if (_servers.length > 1) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _error = null);
                  _cycleServer();
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Otro servidor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VoidTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

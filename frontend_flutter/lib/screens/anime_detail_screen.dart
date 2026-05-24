import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/anime_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/my_list_provider.dart';
import '../services/watch_history.dart';
import '../theme.dart';
import '../widgets/resilient_cached_image.dart';
import '../widgets/skeletons.dart';
import '../widgets/states.dart' show ShimmerBox, TappableScale;
import 'episodios_screen.dart';

// ---------------------------------------------------------------------------
// Pantalla de ficha / detalle de un anime
// ---------------------------------------------------------------------------

const _kImageHeaders = {
  'Referer': 'https://demo.local/',
  'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36'
      ' (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
};

String _normalizeAnimeUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return '';
  if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('demo://')) {
    url = 'demo://anime/';
  }
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

class AnimeDetailScreen extends ConsumerStatefulWidget {
  const AnimeDetailScreen({
    super.key,
    required this.animeTitle,
    required this.animeUrl,
    this.animeImage = '',
  });

  final String animeTitle;
  final String animeUrl;
  final String animeImage;

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen> {
  bool _synopsisExpanded = false;
  late final String _normalizedAnimeUrl;

  @override
  void initState() {
    super.initState();
    _normalizedAnimeUrl = _normalizeAnimeUrl(widget.animeUrl);
  }

  Future<void> _refreshDetail() async {
    ref.invalidate(detailProvider(_normalizedAnimeUrl));
    try {
      await ref.read(detailProvider(_normalizedAnimeUrl).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(detailProvider(_normalizedAnimeUrl));
    final episodeCountAsync =
        ref.watch(episodeCountProvider(_normalizedAnimeUrl));

    // Silently refresh the stored cover in Mi Lista when the detail loads.
    // Prefer the provider image over AniList HD, which uses fuzzy matching
    // and can return the wrong cover for sequels/related entries.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      detailProvider(_normalizedAnimeUrl),
      (_, next) {
        next.whenData((data) {
          final providerImage = (data['imagen'] ?? '').toString();
          final hd = (data['imagen_hd'] ?? '').toString();
          final best = providerImage.isNotEmpty ? providerImage : hd;
          if (best.isEmpty) return;
          WatchHistory.updateMyListImage(_normalizedAnimeUrl, best);
        });
      },
    );

    // Show placeholder data immediately (title + image from previous screen)
    // while the provider loads. No blank screen.
    final info = detailAsync.valueOrNull ??
        {
          'titulo': widget.animeTitle,
          'imagen': widget.animeImage,
          'imagen_hd': '',
          'banner': '',
          'tipo': '',
          'estado': '',
          'sinopsis': '',
          'rating': '',
          'proximo': '',
          'episodios_count': 0,
          'tags': <dynamic>[],
          'relaciones': <dynamic>[],
        };

    // Show spinner overlay only on the initial load (no data yet).
    final loading = detailAsync.isLoading && detailAsync.valueOrNull == null;

    final mergedInfo = Map<String, dynamic>.from(info);
    final liveCount = episodeCountAsync.valueOrNull;
    if (liveCount != null && liveCount > 0) {
      mergedInfo['episodios_count'] = liveCount;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: loading ? 0.6 : 1.0,
            child: RefreshIndicator(
              onRefresh: _refreshDetail,
              color: VoidTheme.primary,
              backgroundColor: VoidTheme.surface,
              child: loading && info['sinopsis'].toString().isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [DetailHeaderSkeleton()],
                    )
                  : _Body(
                      info: mergedInfo,
                      animeUrl: _normalizedAnimeUrl,
                      fallbackImage: widget.animeImage,
                      synopsisExpanded: _synopsisExpanded,
                      loading: loading,
                      detailError: detailAsync.hasError,
                      onRetryDetail: _refreshDetail,
                      onEpisodesClosed: () {
                        ref.invalidate(
                            episodeCountProvider(_normalizedAnimeUrl));
                        ref.invalidate(
                            detailProvider(_normalizedAnimeUrl));
                      },
                      onToggleSynopsis: () => setState(
                        () => _synopsisExpanded = !_synopsisExpanded,
                      ),
                    ),
            ),
          ),
          if (loading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: VoidTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.info,
    required this.animeUrl,
    required this.fallbackImage,
    required this.synopsisExpanded,
    required this.loading,
    required this.detailError,
    required this.onRetryDetail,
    required this.onEpisodesClosed,
    required this.onToggleSynopsis,
  });

  final Map<String, dynamic> info;
  final String animeUrl;
  final String fallbackImage;
  final bool synopsisExpanded;
  final bool loading;
  final bool detailError;
  final Future<void> Function() onRetryDetail;
  final VoidCallback onEpisodesClosed;
  final VoidCallback onToggleSynopsis;

  @override
  Widget build(BuildContext context) {
    final titulo = (info['titulo'] ?? '').toString();
    final imagenHd = (info['imagen_hd'] ?? '').toString();
    final imagen = imagenHd.isNotEmpty
        ? imagenHd
        : (info['imagen'] ?? fallbackImage).toString();
    final banner = (info['banner'] ?? '').toString();
    final tipo = (info['tipo'] ?? '').toString();
    final estado = (info['estado'] ?? '').toString();
    final sinopsis = (info['sinopsis'] ?? '').toString();
    final rating = (info['rating'] ?? '').toString();
    final proximo = (info['proximo'] ?? '').toString();
    final epsCount = (info['episodios_count'] as num?)?.toInt() ?? 0;
    final tags = (info['tags'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final relaciones = (info['relaciones'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Use banner for hero if available, otherwise fall back to cover
    final heroImage = banner.isNotEmpty ? banner : imagen;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Hero Image ──
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          stretch: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VoidTheme.bg.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: VoidTheme.cardBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (imagen.isNotEmpty)
                  Hero(
                    tag: 'anime-cover-$animeUrl',
                    child: ResilientCachedImage(
                      imageUrl: heroImage,
                      fit: BoxFit.cover,
                      httpHeaders: _kImageHeaders,
                      placeholder: const ShimmerBox(radius: 0),
                      fallback: const ColoredBox(color: VoidTheme.card),
                    ),
                  )
                else
                  const ColoredBox(color: VoidTheme.card),
                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.35, 0.75, 1.0],
                      colors: [
                        Color(0x2006060C),
                        Color(0x5006060C),
                        Color(0xAA06060C),
                        Color(0xFF06060C),
                      ],
                    ),
                  ),
                ),
                // Title content at bottom
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (estado.isNotEmpty)
                            _GlassBadge(
                              text: estado,
                              color: estado.toLowerCase().contains('emisi')
                                  ? VoidTheme.emerald
                                  : VoidTheme.amber,
                            ),
                          if (tipo.isNotEmpty)
                            _GlassBadge(text: tipo, color: VoidTheme.primary),
                          if (!loading || epsCount > 0)
                            _GlassBadge(
                                text: '$epsCount eps', color: VoidTheme.cyan),
                          if (proximo.isNotEmpty && proximo.length >= 4)
                            _GlassBadge(
                                text: proximo.substring(0, 4),
                                color: VoidTheme.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        titulo,
                        style: GoogleFonts.sora(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (detailError)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VoidTheme.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: VoidTheme.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: VoidTheme.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No se pudo cargar la ficha completa. Puedes reintentar o abrir los episodios igualmente.',
                        style: GoogleFonts.sora(
                          color: VoidTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetryDetail,
                      style: TextButton.styleFrom(
                        foregroundColor: VoidTheme.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'Reintentar',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Rating ──
        if (rating.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: VoidTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VoidTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: VoidTheme.amber, size: 20),
                        const SizedBox(width: 6),
                        Text(rating,
                            style: GoogleFonts.sora(
                              color: VoidTheme.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            )),
                        Text(' / 5',
                            style: GoogleFonts.sora(
                                color: VoidTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Calificación',
                      style: GoogleFonts.sora(
                          color: VoidTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ),

        // ── Synopsis ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sinopsis',
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 8),
                if (loading && sinopsis.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(height: 13, radius: 6),
                      const SizedBox(height: 6),
                      ShimmerBox(height: 13, radius: 6),
                      const SizedBox(height: 6),
                      ShimmerBox(height: 13, width: 200, radius: 6),
                    ],
                  )
                else
                  Text(
                    sinopsis.isNotEmpty ? sinopsis : 'Sin sinopsis disponible.',
                    maxLines: synopsisExpanded ? 100 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        color: VoidTheme.textSecondary,
                        fontSize: 13,
                        height: 1.6),
                  ),
                if (sinopsis.length > 120)
                  GestureDetector(
                    onTap: onToggleSynopsis,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        synopsisExpanded ? 'Mostrar menos' : 'Leer más',
                        style: GoogleFonts.sora(
                          color: VoidTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Tags ──
        if (loading && tags.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShimmerBox(width: 80, height: 28, radius: 20),
                  ShimmerBox(width: 110, height: 28, radius: 20),
                  ShimmerBox(width: 65, height: 28, radius: 20),
                  ShimmerBox(width: 95, height: 28, radius: 20),
                ],
              ),
            ),
          ),
        if (tags.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: VoidTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: VoidTheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(t,
                              style: GoogleFonts.sora(
                                color: VoidTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              )),
                        ))
                    .toList(),
              ),
            ),
          ),

        // ── Próximo episodio ──
        if (proximo.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: VoidTheme.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VoidTheme.emerald.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: VoidTheme.emerald, size: 18),
                    const SizedBox(width: 10),
                    Text('Próximo episodio: $proximo',
                        style: GoogleFonts.sora(
                          color: VoidTheme.emerald,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
          ),

        // ── MI LISTA CONTROLS ──
        if (!loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _MyListControls(
                animeUrl: animeUrl,
                titulo: titulo,
                imagen: imagen,
                epsCount: epsCount,
              ),
            ),
          ),

        // ── VER EPISODIOS ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: VoidTheme.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: VoidTheme.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EpisodiosScreen(
                        animeTitle: titulo,
                        animeUrl: animeUrl,
                        animeImage: imagen,
                        animeStatus: estado,
                      ),
                    ),
                  );
                  onEpisodesClosed();
                },
                icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
                label: Text(
                  loading && epsCount == 0
                      ? 'VER EPISODIOS'
                      : 'VER EPISODIOS ($epsCount)',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ),

        // ── Relaciones ──
        if (relaciones.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text('Animes Relacionados',
                      style: GoogleFonts.sora(
                        color: VoidTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: relaciones.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final r = relaciones[i];
                      final rTitulo = (r['titulo'] ?? '').toString();
                      final rUrl = (r['url'] ?? '').toString();
                      final rTipo = (r['relacion'] ?? '').toString();
                      final rImagenHd = (r['imagen_hd'] ?? '').toString();
                      final rImagen = rImagenHd.isNotEmpty
                          ? rImagenHd
                          : (r['imagen'] ?? '').toString();

                      return _RelatedAnimeCard(
                        title: rTitulo,
                        url: rUrl,
                        relationType: rTipo,
                        image: rImagen,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text,
          style: GoogleFonts.sora(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _RelatedAnimeCard extends ConsumerWidget {
  const _RelatedAnimeCard({
    required this.title,
    required this.url,
    required this.relationType,
    required this.image,
  });

  final String title;
  final String url;
  final String relationType;
  final String image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedUrl = _normalizeAnimeUrl(url);
    final needsFallback = image.isEmpty && url.isNotEmpty;
    final detailAsync =
        needsFallback ? ref.watch(detailProvider(normalizedUrl)) : null;

    final fallbackImage = detailAsync?.maybeWhen(
          data: (data) {
            final hd = (data['imagen_hd'] ?? '').toString();
            if (hd.isNotEmpty) return hd;
            final normal = (data['imagen'] ?? '').toString();
            if (normal.isNotEmpty) return normal;
            return (data['banner'] ?? '').toString();
          },
          orElse: () => '',
        ) ??
        '';

    final finalImage = image.isNotEmpty ? image : fallbackImage;

    return TappableScale(
      onTap: normalizedUrl.isEmpty
          ? () {}
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimeDetailScreen(
                    animeTitle: title,
                    animeUrl: normalizedUrl,
                    animeImage: finalImage,
                  ),
                ),
              ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VoidTheme.cardBorder,
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (finalImage.isNotEmpty)
                    ResilientCachedImage(
                      imageUrl: finalImage,
                      fit: BoxFit.cover,
                      httpHeaders: _kImageHeaders,
                      placeholder: const ColoredBox(color: VoidTheme.card),
                      fallback: const ColoredBox(color: VoidTheme.card),
                    )
                  else
                    const ColoredBox(color: VoidTheme.card),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xCC06060C),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                color: VoidTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (relationType.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.link_rounded,
                      color: VoidTheme.textMuted, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      relationType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        color: VoidTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyListControls extends ConsumerWidget {
  const _MyListControls({
    required this.animeUrl,
    required this.titulo,
    required this.imagen,
    required this.epsCount,
  });

  final String animeUrl;
  final String titulo;
  final String imagen;
  final int epsCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If guest, maybe hide or show login wall? The user didn't specify for details,
    // but guest logic previously hid Continuar Viendo.
    // Let's allow guest to see it but prompt if they tap (or just let authgate handle later, but better block guests).
    final isGuest = ref.watch(authProvider).isGuest;
    final statusAsync = ref.watch(animeMyListStatusProvider(animeUrl));

    final currentStatus = statusAsync.valueOrNull;
    final isInList = currentStatus != null;

    final Map<String, String> statusNames = {
      'en_proceso': 'En proceso',
      'planeado': 'Planeado',
      'completado': 'Completado',
    };

    Future<void> updateList(String? newStatus) async {
      if (isGuest) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inicia sesión para usar Mi Lista.',
              style: GoogleFonts.sora(color: VoidTheme.text),
            ),
            backgroundColor: VoidTheme.card,
          ),
        );
        return;
      }

      if (newStatus == null) {
        // Toggle heart (remove or add default)
        if (isInList) {
          await WatchHistory.removeFromMyList(animeUrl);
        } else {
          await WatchHistory.saveToMyList(
            animeUrl: animeUrl,
            titulo: titulo,
            imagen: imagen,
            status: 'planeado', // default when tapping heart without status
            episodesWatched: 0,
            totalEpisodes: epsCount,
          );
        }
      } else {
        // Change from dropdown
        await WatchHistory.saveToMyList(
          animeUrl: animeUrl,
          titulo: titulo,
          imagen: imagen,
          status: newStatus,
          // If we change status, we keep existing watched count if it exists, otherwise 0.
          // For simplicity we use 0 here, or we'd need to fetch full entry.
          // A proper robust implementation would fetch first.
          episodesWatched: 0,
          totalEpisodes: epsCount,
        );
      }
      ref.invalidate(animeMyListStatusProvider(animeUrl));
      ref.invalidate(myListProvider);
    }

    return Row(
      children: [
        // Heart Button
        InkWell(
          onTap: () => updateList(null),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  isInList ? VoidTheme.pink.withOpacity(0.15) : VoidTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isInList
                    ? VoidTheme.pink.withOpacity(0.5)
                    : VoidTheme.cardBorder,
              ),
            ),
            child: Icon(
              isInList ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isInList ? VoidTheme.pink : VoidTheme.textSecondary,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Dropdown
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: VoidTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: VoidTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: isInList && statusNames.containsKey(currentStatus)
                    ? currentStatus
                    : null,
                hint: Text('Añadir a mi lista',
                    style: GoogleFonts.sora(
                        color: VoidTheme.textSecondary, fontSize: 14)),
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: VoidTheme.textSecondary),
                dropdownColor: VoidTheme.card,
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) updateList(val);
                },
                items: statusNames.entries.map((e) {
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: GoogleFonts.sora(
                        color: VoidTheme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


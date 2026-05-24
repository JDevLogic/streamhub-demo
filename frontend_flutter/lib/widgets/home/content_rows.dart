import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/watch_history.dart';
import '../../theme.dart';
import '../resilient_cached_image.dart';
import '../states.dart';

// ── Shared helper ────────────────────────────────────────────────────────────

class _NetImg extends StatelessWidget {
  const _NetImg({required this.url});
  final String url;

  static const _kImageHeaders = {
    'Referer': 'https://demo.local/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  };

  String _normalizeImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'demo://image$value';
    return 'demo://image/$value';
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeImageUrl(url);
    if (normalized.isEmpty) return const ShimmerBox(radius: 0);
    return ResilientCachedImage(
      imageUrl: normalized,
      fit: BoxFit.cover,
      httpHeaders: _kImageHeaders,
      placeholder: const ShimmerBox(radius: 0),
      fallback: const ColoredBox(color: VoidTheme.card),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Últimos Episodios row
// ═══════════════════════════════════════════════════════════════════

class HorizontalEpisodioRow extends StatelessWidget {
  const HorizontalEpisodioRow({
    super.key,
    required this.episodios,
    required this.onTap,
  });

  final List<Map<String, dynamic>> episodios;
  final void Function(Map<String, dynamic>) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: episodios.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final ep       = episodios[i];
          final titulo   = (ep['titulo']    ?? '').toString();
          final episodio = (ep['episodio']  ?? '').toString();
          final imagenHd = (ep['imagen_hd'] ?? '').toString();
          final imagen   = imagenHd.isNotEmpty ? imagenHd : (ep['imagen'] ?? '').toString();

          return TappableScale(
            onTap: () => onTap(ep),
            child: SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'cover-${(ep['url'] ?? '').toString().replaceFirst('/ver/', '/anime/').replaceFirst(RegExp(r'-\d+$'), '')}',
                    child: Container(
                      height: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: VoidTheme.cardBorder, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _NetImg(url: imagen),
                          Positioned(
                            bottom: 0, left: 0, right: 0, height: 70,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xEE06060C), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          if (episodio.isNotEmpty)
                            Positioned(
                              left: 8, bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: VoidTheme.cyan.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  episodio,
                                  style: GoogleFonts.sora(
                                    color: VoidTheme.bg,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 8, bottom: 8,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: VoidTheme.primary.withOpacity(0.85),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      color: VoidTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Recién Agregados / generic content row
// ═══════════════════════════════════════════════════════════════════

class HorizontalContentRow extends StatelessWidget {
  const HorizontalContentRow({
    super.key,
    required this.items,
    required this.onTap,
    this.onRemove,
  });

  final List<Map<String, dynamic>> items;
  final void Function(String titulo, String url, String imagen) onTap;
  final void Function(String url)? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item    = items[i];
          final titulo   = (item['titulo']    ?? '').toString();
          final imagenHd = (item['imagen_hd'] ?? '').toString();
          final imagen   = imagenHd.isNotEmpty ? imagenHd : (item['imagen'] ?? '').toString();
          final url      = (item['url']   ?? '').toString();
          final tipo     = (item['tipo']  ?? '').toString();

          return TappableScale(
            onTap: () => onTap(titulo, url, imagen),
            child: SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'cover-$url',
                    child: Container(
                      height: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: VoidTheme.cardBorder, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _NetImg(url: imagen),
                          Positioned(
                            bottom: 0, left: 0, right: 0, height: 50,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Color(0xCC06060C), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                          if (onRemove != null)
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => onRemove!(url),
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: VoidTheme.bg.withOpacity(0.75),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: VoidTheme.cardBorder, width: 0.5),
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: VoidTheme.textSecondary, size: 14),
                                ),
                              ),
                            ),
                          if (tipo.isNotEmpty)
                            Positioned(
                              left: 8, bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _typeColor(tipo),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tipo.toUpperCase(),
                                  style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      color: VoidTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _typeColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'ova':
      case 'película':
        return VoidTheme.pink;
      case 'tv':
        return VoidTheme.primary;
      default:
        return VoidTheme.primaryDark;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// En Emisión row (pill-style)
// ═══════════════════════════════════════════════════════════════════

class HorizontalEmisionRow extends StatelessWidget {
  const HorizontalEmisionRow({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<Map<String, dynamic>> items;
  final void Function(String titulo, String url, String imagen) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item  = items[i];
          final titulo = (item['titulo'] ?? '').toString();
          final tipo   = (item['tipo']   ?? '').toString();
          final url    = (item['url']    ?? '').toString();

          return TappableScale(
            onTap: () => onTap(titulo, url, ''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: VoidTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VoidTheme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: VoidTheme.emerald,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: VoidTheme.emerald.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    titulo.length > 22
                        ? '${titulo.substring(0, 22)}...'
                        : titulo,
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (tipo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: VoidTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: VoidTheme.primary.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        tipo.toUpperCase(),
                        style: GoogleFonts.sora(
                          color: VoidTheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Continuar Viendo row (with progress bar)
// ═══════════════════════════════════════════════════════════════════

class ContinuarViendoRow extends StatefulWidget {
  const ContinuarViendoRow({
    super.key,
    required this.items,
    required this.onTap,
    this.onRemove,
  });

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> entry) onTap;
  final void Function(String url)? onRemove;

  @override
  State<ContinuarViendoRow> createState() => _ContinuarViendoRowState();
}

class _ContinuarViendoRowState extends State<ContinuarViendoRow> {
  Map<String, Map<String, double>> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(covariant ContinuarViendoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _loadProgress();
    }
  }

  Future<void> _loadProgress() async {
    final progress = await WatchHistory.getAllProgress();
    if (mounted) setState(() => _progressMap = progress);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item        = widget.items[i];
          final titulo       = (item['titulo']       ?? '').toString();
          final imagenHd     = (item['imagen_hd']    ?? '').toString();
          final imagen       = imagenHd.isNotEmpty
              ? imagenHd
              : (item['imagen'] ?? '').toString();
          final url          = (item['url']           ?? '').toString();
          final lastEpName   = (item['lastEpisodeName'] ?? '').toString();
          final lastEpUrl    = (item['lastEpisodeUrl']  ?? '').toString();
          final hasNew       = item['hasNewEpisode'] == true;
          final displayEpName = hasNew
              ? (item['newEpisodeName'] ?? '').toString()
              : lastEpName;

          final prog             = _progressMap[lastEpUrl];
          final position         = prog?['position'] ?? 0.0;
          final duration         = prog?['duration'] ?? 0.0;
          final progressFraction =
              duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
          final remaining        = duration > 0 ? duration - position : 0.0;
          final remainingMins    = (remaining / 60).floor();

          return TappableScale(
            onTap: () => widget.onTap(item),
            child: SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'cover-$url',
                    child: Container(
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: VoidTheme.cardBorder, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _NetImg(url: imagen),
                        Positioned(
                          bottom: 0, left: 0, right: 0, height: 70,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xEE06060C), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                        if (widget.onRemove != null)
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => widget.onRemove!(url),
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: VoidTheme.bg.withOpacity(0.75),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: VoidTheme.cardBorder, width: 0.5),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: VoidTheme.textSecondary, size: 14),
                              ),
                            ),
                          ),
                        if (hasNew)
                          Positioned(
                            top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: VoidTheme.bg.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: VoidTheme.cyan.withOpacity(0.8),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: VoidTheme.cyan.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5, height: 5,
                                    decoration: const BoxDecoration(
                                      color: VoidTheme.cyan,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'SIGUIENTE',
                                    style: GoogleFonts.sora(
                                      color: VoidTheme.cyan,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (displayEpName.isNotEmpty)
                          Positioned(
                            left: 8, bottom: 28,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: VoidTheme.primary.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                displayEpName,
                                style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 8, bottom: 28,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: VoidTheme.primary.withOpacity(0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                        if (progressFraction > 0)
                          Positioned(
                            left: 0, right: 0, bottom: 0, height: 5,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  Container(color: Colors.white12),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progressFraction,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: VoidTheme.gradientPrimary,
                                      ),
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
                  const SizedBox(height: 6),
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      color: VoidTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (progressFraction > 0 && remainingMins > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${remainingMins}min restantes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        color: VoidTheme.primary.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


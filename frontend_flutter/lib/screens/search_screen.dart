import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/anime_providers.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import '../widgets/resilient_cached_image.dart';
import '../widgets/states.dart'
    show AppErrorState, AppEmptyState, ShimmerBox, ShimmerGrid, TappableScale;
import 'anime_detail_screen.dart';

const _kImageHeaders = {
  'Referer': 'https://demo.local/',
  'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36'
      ' (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
};

String _normalizeAnimeUrl(String raw) {
  final url = raw.trim();
  if (url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return 'demo://anime$url';
  return 'demo://anime/$url';
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _historyKey = 'search_history';
  static const _maxHistory = 10;
  static const _debounceMs = 600;

  final _controller = TextEditingController();
  Timer? _debounce;

  Future<List<Map<String, dynamic>>>? _futureResults;
  bool _hasSearched = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    if (mounted) setState(() => _history = list);
  }

  Future<void> _saveToHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > _maxHistory) {
      _history = _history.sublist(0, _maxHistory);
    }
    await prefs.setStringList(_historyKey, _history);
  }

  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _history.remove(query);
    await prefs.setStringList(_historyKey, _history);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() => _history = []);
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _search([String? query]) {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    _controller.text = q;
    // Move cursor to end
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _saveToHistory(q);
    final service = ref.read(animeServiceProvider);
    final future = service.buscarAnimes(q);
    setState(() {
      _hasSearched = true;
      _futureResults = future;
    });
    future.then((results) {
      final urls = results
          .map((a) => (a['url'] ?? '').toString())
          .where((u) => u.isNotEmpty)
          .toList();
      service.prefetch(urls);
      service.prefetchDetailCache(urls, limit: 4);
    }).catchError((_) {});
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _hasSearched = false);
      return;
    }
    // While waiting for debounce, reset so we show suggestions
    if (_hasSearched) setState(() => _hasSearched = false);
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (mounted) _search();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: VoidTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: VoidTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VoidTheme.cardBorder),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: GoogleFonts.sora(color: VoidTheme.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar anime...',
              hintStyle:
                  GoogleFonts.sora(color: VoidTheme.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: VoidTheme.textMuted, size: 18),
                      onPressed: () {
                        _debounce?.cancel();
                        _controller.clear();
                        setState(() => _hasSearched = false);
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: _onChanged,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 8, right: 12),
            decoration: BoxDecoration(
              gradient: VoidTheme.gradientPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 20),
              onPressed: _search,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final typed = _controller.text.trim();
    if (typed.isEmpty) return _buildHistory();
    if (_hasSearched) return _buildResults();
    return _buildSuggestions(typed);
  }

  // ── History view ───────────────────────────────────────────────────────────

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                color: VoidTheme.textMuted.withOpacity(0.5), size: 64),
            const SizedBox(height: 16),
            Text('Busca cualquier anime',
                style:
                    GoogleFonts.sora(color: VoidTheme.textMuted, fontSize: 15)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Text(
                'Búsquedas recientes',
                style: GoogleFonts.sora(
                  color: VoidTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearHistory,
                style: TextButton.styleFrom(
                  foregroundColor: VoidTheme.textMuted,
                  textStyle: GoogleFonts.sora(fontSize: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: const Text('Borrar todo'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _history.length,
            itemBuilder: (context, i) => _HistoryTile(
              query: _history[i],
              onTap: () => _search(_history[i]),
              onRemove: () => _removeFromHistory(_history[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Suggestions view (while typing) ───────────────────────────────────────

  Widget _buildSuggestions(String typed) {
    final suggestions = _history
        .where((h) => h.toLowerCase().contains(typed.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Search for X" row always at top
        _SearchDirectTile(
          query: typed,
          onTap: _search,
        ),
        if (suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Del historial',
              style: GoogleFonts.sora(
                color: VoidTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...suggestions.map(
            (h) => _HistoryTile(
              query: h,
              typed: typed,
              onTap: () => _search(h),
              onRemove: () => _removeFromHistory(h),
            ),
          ),
        ],
      ],
    );
  }

  // ── Results view ───────────────────────────────────────────────────────────

  Widget _buildResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureResults,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ShimmerGrid();
        }
        if (snap.hasError) {
          return AppErrorState(error: snap.error!, onRetry: _search);
        }
        final results = snap.data ?? [];
        if (results.isEmpty) return const AppEmptyState.search();

        return RefreshIndicator(
          onRefresh: () async => _search(),
          color: VoidTheme.primary,
          backgroundColor: VoidTheme.surface,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.52,
            ),
            itemBuilder: (context, index) {
              final anime = results[index];
              final titulo = (anime['titulo'] ?? '').toString();
              final imagenHd = (anime['imagen_hd'] ?? '').toString();
              final imagen = imagenHd.isNotEmpty
                  ? imagenHd
                  : (anime['imagen'] ?? '').toString();
              final tipo = (anime['tipo'] ?? '').toString();
              final url = (anime['url'] ?? '').toString();

              return FadeInEntrance(
                delay: Duration(milliseconds: (index % 12) * 40),
                child: _SearchAnimeTile(
                  title: titulo,
                  image: imagen,
                  type: tipo,
                  url: url,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── History tile ──────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
    this.typed,
  });

  final String query;
  final String? typed;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: VoidTheme.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.history_rounded,
            color: VoidTheme.textMuted, size: 18),
      ),
      title: typed != null && typed!.isNotEmpty
          ? _highlightMatch(query, typed!)
          : Text(query,
              style: GoogleFonts.sora(
                  color: VoidTheme.textSecondary, fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded,
            color: VoidTheme.textMuted, size: 18),
        onPressed: onRemove,
      ),
      onTap: onTap,
    );
  }

  Widget _highlightMatch(String text, String match) {
    final lower = text.toLowerCase();
    final matchLower = match.toLowerCase();
    final start = lower.indexOf(matchLower);
    if (start < 0) {
      return Text(text,
          style:
              GoogleFonts.sora(color: VoidTheme.textSecondary, fontSize: 14));
    }
    final end = start + match.length;
    return RichText(
      text: TextSpan(
        style: GoogleFonts.sora(color: VoidTheme.textSecondary, fontSize: 14),
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: GoogleFonts.sora(
              color: VoidTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

// ── Search direct tile ────────────────────────────────────────────────────────

class _SearchDirectTile extends StatelessWidget {
  const _SearchDirectTile({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: VoidTheme.gradientPrimary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
      ),
      title: RichText(
        text: TextSpan(
          style: GoogleFonts.sora(color: VoidTheme.textSecondary, fontSize: 14),
          children: [
            const TextSpan(text: 'Buscar '),
            TextSpan(
              text: '"$query"',
              style: GoogleFonts.sora(
                color: VoidTheme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _SearchAnimeTile extends ConsumerWidget {
  const _SearchAnimeTile({
    required this.title,
    required this.image,
    required this.type,
    required this.url,
  });

  final String title;
  final String image;
  final String type;
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedUrl = _normalizeAnimeUrl(url);
    final needsFallback = image.isEmpty && url.isNotEmpty;
    final detailAsync =
        needsFallback ? ref.watch(animeDetalleProvider(normalizedUrl)) : null;
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnimeDetailScreen(
            animeTitle: title,
            animeUrl: normalizedUrl,
            animeImage: finalImage,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'anime-cover-$url',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VoidTheme.cardBorder, width: 0.5),
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
                        placeholder: const ShimmerBox(radius: 0),
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
                    if (type.isNotEmpty)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: type == 'OVA' || type == 'Película'
                                ? VoidTheme.pink
                                : VoidTheme.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              color: VoidTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/content_providers.dart';
import '../theme.dart';
import '../widgets/resilient_cached_image.dart';
import '../widgets/search_button.dart';
import '../widgets/states.dart';
import 'detail_screen.dart';

class EmisionScreen extends ConsumerWidget {
  const EmisionScreen({super.key});

  void _openContent(BuildContext context, String titulo, String url,
      String imagen, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          contentTitle: titulo,
          contentUrl: url,
          contentImage: imagen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emisionAsync = ref.watch(onAirProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'En Emisión',
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: VoidTheme.text,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: VoidTheme.textSecondary),
            onPressed: () => ref.invalidate(onAirProvider),
          ),
          const SearchButton(),
        ],
      ),
      body: emisionAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VoidTheme.primary),
        ),
        error: (err, _) => Center(
          child: AppErrorState(
            error: err,
            onRetry: () => ref.invalidate(onAirProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No hay contenido en emisión disponibles.',
                style: GoogleFonts.sora(color: VoidTheme.textSecondary),
              ),
            );
          }

          return RefreshIndicator(
            color: VoidTheme.primary,
            backgroundColor: VoidTheme.surface,
            onRefresh: () async {
              ref.invalidate(onAirProvider);
              await ref.read(onAirProvider.future);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 16,
                mainAxisSpacing: 24,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final titulo = (item['titulo'] ?? '').toString();
                final imagenHd = (item['imagen_hd'] ?? '').toString();
                final imagen = imagenHd.isNotEmpty
                    ? imagenHd
                    : (item['imagen'] ?? '').toString();
                final url = (item['url'] ?? '').toString();
                final tipo = (item['tipo'] ?? '').toString();

                return _EmisionGridItem(
                  titulo: titulo,
                  imagen: imagen,
                  url: url,
                  tipo: tipo,
                  onTap: (resolvedImage) =>
                      _openContent(context, titulo, url, resolvedImage, ref),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmisionGridItem extends ConsumerWidget {
  const _EmisionGridItem({
    required this.titulo,
    required this.imagen,
    required this.url,
    required this.tipo,
    required this.onTap,
  });

  final String titulo;
  final String imagen;
  final String url;
  final String tipo;
  final ValueChanged<String> onTap;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldTryDetailFallback =
        false;
    final detailAsync =
        shouldTryDetailFallback ? ref.watch(detailProvider(url)) : null;

    final detailImage = detailAsync?.maybeWhen(
          data: (data) {
            final hd = (data['imagen_hd'] ?? '').toString();
            if (hd.isNotEmpty) return hd;
            final img = (data['imagen'] ?? '').toString();
            if (img.isNotEmpty) return img;
            return (data['banner'] ?? '').toString();
          },
          orElse: () => '',
        ) ??
        '';

    final finalImage = detailImage.isNotEmpty ? detailImage : imagen;

    return TappableScale(
      onTap: () => onTap(finalImage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Hero(
              tag: 'emision-cover-$url',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VoidTheme.cardBorder, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (finalImage.isNotEmpty)
                      ResilientCachedImage(
                        imageUrl: finalImage,
                        fit: BoxFit.cover,
                        httpHeaders: const {
                          'Referer': 'https://demo.local/',
                          'User-Agent':
                              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36'
                                  ' (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                        },
                        placeholder: const ShimmerBox(radius: 0),
                        fallback: const ColoredBox(color: VoidTheme.card),
                      )
                    else
                      const ColoredBox(color: VoidTheme.card),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
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
                    if (tipo.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _typeColor(tipo).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            tipo.toUpperCase(),
                            style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
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


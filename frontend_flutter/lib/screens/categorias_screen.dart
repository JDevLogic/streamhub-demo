import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/anime_providers.dart';
import '../theme.dart';
import '../widgets/resilient_cached_image.dart';
import '../widgets/search_button.dart';
import '../widgets/states.dart';
import 'anime_detail_screen.dart';

// ── Definición de géneros ─────────────────────────────────────────────────────

class _Genero {
  const _Genero(this.slug, this.nombre, this.icon, this.color);
  final String slug;
  final String nombre;
  final IconData icon;
  final Color color;
}

const _kGeneros = [
  _Genero('accion', 'Acción', Icons.flash_on_rounded, Color(0xFFFF3E8A)),
  _Genero('aventura', 'Aventura', Icons.explore_rounded, Color(0xFFF59E0B)),
  _Genero(
      'fantasia', 'Fantasía', Icons.auto_awesome_rounded, Color(0xFFA855F7)),
  _Genero('comedia', 'Comedia', Icons.sentiment_very_satisfied_rounded,
      Color(0xFF10B981)),
  _Genero('drama', 'Drama', Icons.theater_comedy_rounded, Color(0xFF00F0FF)),
  _Genero('romance', 'Romance', Icons.favorite_rounded, Color(0xFFFF3E8A)),
  _Genero('ciencia-ficcion', 'Ciencia Ficción', Icons.rocket_launch_rounded,
      Color(0xFF00F0FF)),
  _Genero(
      'sobrenatural', 'Sobrenatural', Icons.blur_on_rounded, Color(0xFF7C3AED)),
  _Genero(
      'misterio', 'Misterio', Icons.help_outline_rounded, Color(0xFF6B7280)),
  _Genero('terror', 'Terror', Icons.nightlight_round, Color(0xFFDC2626)),
  _Genero('psicologico', 'Psicológico', Icons.psychology_rounded,
      Color(0xFF8B5CF6)),
  _Genero('shounen', 'Shounen', Icons.sports_martial_arts_rounded,
      Color(0xFFF59E0B)),
  _Genero('seinen', 'Seinen', Icons.person_rounded, Color(0xFFA855F7)),
  _Genero('shoujo', 'Shoujo', Icons.local_florist_rounded, Color(0xFFFF3E8A)),
  _Genero('escolares', 'Escolares', Icons.school_rounded, Color(0xFF10B981)),
  _Genero('mecha', 'Mecha', Icons.precision_manufacturing_rounded,
      Color(0xFF00F0FF)),
  _Genero('magia', 'Magia', Icons.stars_rounded, Color(0xFFA855F7)),
  _Genero(
      'superpoderes', 'Superpoderes', Icons.bolt_rounded, Color(0xFFF59E0B)),
  _Genero(
      'deportes', 'Deportes', Icons.sports_soccer_rounded, Color(0xFF10B981)),
  _Genero(
      'historico', 'Histórico', Icons.history_edu_rounded, Color(0xFFF59E0B)),
  _Genero('musica', 'Música', Icons.music_note_rounded, Color(0xFF00F0FF)),
  _Genero('recuentos-de-la-vida', 'Slice of Life', Icons.wb_sunny_rounded,
      Color(0xFFF59E0B)),
  _Genero('demonios', 'Demonios', Icons.whatshot_rounded, Color(0xFFEF4444)),
  _Genero('juegos', 'Juegos', Icons.sports_esports_rounded, Color(0xFF10B981)),
  _Genero('harem', 'Harem', Icons.people_rounded, Color(0xFFFF3E8A)),
  _Genero('militar', 'Militar', Icons.security_rounded, Color(0xFF6B7280)),
  _Genero('vampiros', 'Vampiros', Icons.dark_mode_rounded, Color(0xFFDC2626)),
  _Genero('ecchi', 'Ecchi', Icons.spa_rounded, Color(0xFFFF3E8A)),
];

// ── Pantalla principal de Categorías ─────────────────────────────────────────

class CategoriasScreen extends StatelessWidget {
  const CategoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Categorías',
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const AnimeSearchButton(margin: EdgeInsets.zero),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Text(
                'Explora anime por género',
                style: GoogleFonts.sora(
                  color: VoidTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _kGeneros.length,
                itemBuilder: (context, i) {
                  final genero = _kGeneros[i];
                  return _GeneroCard(
                    genero: genero,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _GeneroAnimesScreen(genero: genero),
                      ),
                    ),
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

// ── Tarjeta de género ─────────────────────────────────────────────────────────

class _GeneroCard extends StatelessWidget {
  const _GeneroCard({required this.genero, required this.onTap});

  final _Genero genero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: VoidTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: genero.color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: genero.color.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: genero.color.withOpacity(0.12),
              ),
              child: Icon(genero.icon, color: genero.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                genero.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  color: VoidTheme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ── Sub-pantalla: animes del género ──────────────────────────────────────────

class _GeneroAnimesScreen extends ConsumerWidget {
  const _GeneroAnimesScreen({required this.genero});

  final _Genero genero;

  void _openAnime(BuildContext context, Map<String, dynamic> anime) {
    final titulo = (anime['titulo'] ?? '').toString();
    final imagenHd = (anime['imagen_hd'] ?? '').toString();
    final imagen =
        imagenHd.isNotEmpty ? imagenHd : (anime['imagen'] ?? '').toString();
    final url = (anime['url'] ?? '').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimeDetailScreen(
          animeTitle: titulo,
          animeUrl: url,
          animeImage: imagen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animesAsync = ref.watch(animesporGeneroProvider(genero.slug));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: VoidTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: genero.color.withOpacity(0.15),
              ),
              child: Icon(genero.icon, color: genero.color, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              genero.nombre,
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: VoidTheme.text,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: VoidTheme.textSecondary),
            onPressed: () =>
                ref.invalidate(animesporGeneroProvider(genero.slug)),
          ),
          const AnimeSearchButton(),
        ],
      ),
      body: animesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: VoidTheme.primary),
        ),
        error: (err, _) => Center(
          child: AppErrorState(
            error: err,
            onRetry: () => ref.invalidate(animesporGeneroProvider(genero.slug)),
          ),
        ),
        data: (animes) {
          if (animes.isEmpty) {
            return Center(
              child: Text(
                'No se encontraron animes en esta categoría.',
                style: GoogleFonts.sora(color: VoidTheme.textSecondary),
              ),
            );
          }

          return RefreshIndicator(
            color: VoidTheme.primary,
            backgroundColor: VoidTheme.surface,
            onRefresh: () async {
              ref.invalidate(animesporGeneroProvider(genero.slug));
              await ref.read(animesporGeneroProvider(genero.slug).future);
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
              itemCount: animes.length,
              itemBuilder: (context, i) {
                final anime = animes[i];
                final titulo = (anime['titulo'] ?? '').toString();
                final imagenHd = (anime['imagen_hd'] ?? '').toString();
                final imagen = imagenHd.isNotEmpty
                    ? imagenHd
                    : (anime['imagen'] ?? '').toString();
                final tipo = (anime['tipo'] ?? '').toString();

                return _AnimeGridItem(
                  titulo: titulo,
                  imagen: imagen,
                  tipo: tipo,
                  accentColor: genero.color,
                  onTap: () => _openAnime(context, anime),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Item de grid de anime ─────────────────────────────────────────────────────

class _AnimeGridItem extends StatelessWidget {
  const _AnimeGridItem({
    required this.titulo,
    required this.imagen,
    required this.tipo,
    required this.accentColor,
    required this.onTap,
  });

  final String titulo;
  final String imagen;
  final String tipo;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
                  if (imagen.isNotEmpty)
                    ResilientCachedImage(
                      imageUrl: imagen,
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
                  // Gradient overlay at bottom
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
                          color: accentColor.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
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

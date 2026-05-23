import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme.dart';
import '../states.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.ep, required this.onTap});
  final Map<String, dynamic> ep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titulo    = (ep['titulo']    ?? '').toString();
    final episodio  = (ep['episodio']  ?? '').toString();
    final imagenHd  = (ep['imagen_hd'] ?? '').toString();
    final imagen    = imagenHd.isNotEmpty ? imagenHd : (ep['imagen'] ?? '').toString();

    return TappableScale(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 200,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoidTheme.primary.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagen.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imagen,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: VoidTheme.card),
                errorWidget: (_, __, ___) => const ColoredBox(color: VoidTheme.card),
              ),
            // Bottom gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [Color(0x3006060C), Color(0x7006060C), Color(0xEE06060C)],
                ),
              ),
            ),
            // Left vignette
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.6],
                  colors: [Color(0x7006060C), Colors.transparent],
                ),
              ),
            ),
            // Text content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: VoidTheme.gradientPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NUEVO',
                      style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: VoidTheme.text,
                      height: 1.2,
                    ),
                  ),
                  if (episodio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episodio,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: VoidTheme.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Play FAB
            Positioned(
              right: 20,
              bottom: 20,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: VoidTheme.gradientPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: VoidTheme.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

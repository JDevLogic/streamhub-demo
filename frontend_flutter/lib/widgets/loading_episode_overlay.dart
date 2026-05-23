import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class LoadingEpisodeOverlay extends StatelessWidget {
  const LoadingEpisodeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: VoidTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VoidTheme.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: VoidTheme.primary.withOpacity(0.15),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: VoidTheme.cyan,
                strokeWidth: 3.0,
              ),
            ),
            const SizedBox(height: 24),
            Material(
              type: MaterialType.transparency,
              child: Text(
                'Preparando episodio...',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  color: VoidTheme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

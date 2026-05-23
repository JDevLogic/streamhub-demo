import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class SkipIntroButton extends StatelessWidget {
  const SkipIntroButton({
    super.key,
    required this.visible,
    required this.onSkip,
    this.bottom = 140,
  });

  final bool visible;
  final VoidCallback onSkip;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      right: 24,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCirc,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0.2, 0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCirc,
          child: IgnorePointer(
            ignoring: !visible,
            child: GestureDetector(
              onTap: onSkip,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: VoidTheme.primary.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: VoidTheme.cyan.withOpacity(0.15),
                      blurRadius: 10,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: VoidTheme.card.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: VoidTheme.primary.withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Saltar intro',
                            style: GoogleFonts.sora(
                              color: VoidTheme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.fast_forward_rounded,
                            color: VoidTheme.cyan,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

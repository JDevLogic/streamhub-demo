import 'package:flutter/material.dart';

/// Design tokens – "Void Neon" palette.
class VoidTheme {
  VoidTheme._();

  // ── Background layers ──
  static const bg = Color(0xFF06060C);
  static const surface = Color(0xFF0E0E1A);
  static const card = Color(0xFF141428);
  static const cardBorder = Color(0xFF1F1F3A);
  static const elevated = Color(0xFF1A1A32);

  // ── Primary palette ──
  static const primary = Color(0xFFA855F7);
  static const primaryDark = Color(0xFF7C3AED);

  // ── Accent palette ──
  static const cyan = Color(0xFF00F0FF);
  static const pink = Color(0xFFFF3E8A);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);

  // ── Text hierarchy ──
  static const text = Color(0xFFECECF0);
  static const textSecondary = Color(0xFF8585A0);
  static const textMuted = Color(0xFF4E4E6A);

  // ── Gradient presets ──
  static const gradientPrimary = LinearGradient(
    colors: [primary, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientPink = LinearGradient(
    colors: [pink, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xDD06060C)],
  );
}

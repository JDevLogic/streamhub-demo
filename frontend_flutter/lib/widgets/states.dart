import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'skeletons.dart';

// ── TappableScale ─────────────────────────────────────────────────────────────
/// Wraps any widget with a press-to-scale animation for immediate tap feedback.

class TappableScale extends StatefulWidget {
  const TappableScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.93,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scale;

  @override
  State<TappableScale> createState() => _TappableScaleState();
}

class _TappableScaleState extends State<TappableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _anim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(scale: _anim, child: widget.child),
    );
  }
}

// ── ShimmerBox ────────────────────────────────────────────────────────────────
/// Single animated shimmer rectangle. Use as CachedNetworkImage placeholder
/// or as a skeleton line/block anywhere in the UI.

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: gradient,
        ),
      ),
    );
  }
}

// ── Error message parser ──────────────────────────────────────────────────────

String parseErrorMessage(Object error) {
  final s = error.toString();
  if (s.contains('API_KEY no configurada') ||
      s.contains('--dart-define=API_KEY') ||
      (s.contains('Bad state') && s.contains('API_KEY'))) {
    return 'Falta configurar la clave de la app.\nRecompila con --dart-define=API_KEY=...';
  }
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused') ||
      s.contains('NetworkException') ||
      s.contains('HandshakeException')) {
    return 'Sin conexión al servidor.\nComprueba tu red.';
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return 'El servidor tardó demasiado.\nInténtalo de nuevo.';
  }
  if (s.contains('FormatException') || s.contains('type \'Null\'')) {
    return 'Respuesta inesperada del servidor.';
  }

  // Extrae el primer código HTTP que aparezca (ej. "HTTP 502")
  final httpMatch = RegExp(r'HTTP\s*(\d{3})').firstMatch(s);
  final code = httpMatch != null ? int.tryParse(httpMatch.group(1)!) : null;
  if (code != null) {
    if (code == 401 || code == 403) {
      return 'La app no está autorizada para usar este servidor.\nInstala la última versión o revisa la configuración.';
    }
    if (code == 404) return 'Contenido no encontrado.';
    if (code == 408) return 'El servidor tardó demasiado.\nInténtalo de nuevo.';
    if (code == 429) return 'Demasiadas peticiones.\nEspera un momento.';
    if (code >= 500 && code < 600) {
      return 'El servidor no responde (HTTP $code).\nInténtalo de nuevo.';
    }
    if (code >= 400 && code < 500) {
      return 'Petición inválida (HTTP $code).';
    }
  }

  return 'Algo salió mal.\nInténtalo de nuevo.';
}

IconData _errorIcon(Object error) {
  final s = error.toString();
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Connection refused')) {
    return Icons.wifi_off_rounded;
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return Icons.timer_off_rounded;
  }
  return Icons.error_outline_rounded;
}

// ── AppErrorState ─────────────────────────────────────────────────────────────

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.slim = false,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Compact inline version for home section rows.
  final bool slim;

  @override
  Widget build(BuildContext context) {
    final message = parseErrorMessage(error);
    final icon = _errorIcon(error);

    if (slim) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: VoidTheme.textMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.replaceAll('\n', ' '),
                style: GoogleFonts.sora(
                  color: VoidTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: VoidTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  textStyle: GoogleFonts.sora(fontSize: 12),
                ),
                child: const Text('Reintentar'),
              ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: VoidTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: VoidTheme.cardBorder),
              ),
              child: Icon(icon, color: VoidTheme.textMuted, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                color: VoidTheme.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: VoidTheme.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Reintentar',
                        style: GoogleFonts.sora(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── AppEmptyState ─────────────────────────────────────────────────────────────

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    required this.icon,
    this.subtitle,
  });

  final String message;
  final IconData icon;
  final String? subtitle;

  const AppEmptyState.episodes({super.key})
      : message = 'No hay episodios disponibles',
        icon = Icons.video_library_outlined,
        subtitle = null;

  const AppEmptyState.search({super.key})
      : message = 'Sin resultados',
        icon = Icons.search_off_rounded,
        subtitle = 'Prueba con otro título';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: VoidTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: VoidTheme.cardBorder),
              ),
              child: Icon(icon,
                  color: VoidTheme.textMuted.withOpacity(0.7), size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                color: VoidTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: GoogleFonts.sora(
                  color: VoidTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shimmer base ──────────────────────────────────────────────────────────────

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.builder});
  final Widget Function(LinearGradient gradient) builder;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => widget.builder(
        LinearGradient(
          begin: Alignment(-1.5 + 3.0 * _c.value, 0),
          end: Alignment(1.5 + 3.0 * _c.value, 0),
          colors: [
            VoidTheme.card,
            VoidTheme.primary.withOpacity(0.1),
            VoidTheme.elevated,
            VoidTheme.primary.withOpacity(0.1),
            VoidTheme.card,
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        ),
      ),
    );
  }
}

/// A leaf skeleton element that uses the shared shimmer gradient.
class SkeletonLeaf extends StatelessWidget {
  const SkeletonLeaf({
    super.key,
    this.width,
    this.height,
    this.radius = 4,
    required this.gradient,
  });

  final double? width;
  final double? height;
  final double radius;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── ShimmerListTiles (episodios) ──────────────────────────────────────────────

class ShimmerListTiles extends StatelessWidget {
  const ShimmerListTiles({super.key, this.count = 7});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      builder: (gradient) => Column(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _box(32, 32, gradient, radius: 8),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(14, double.infinity, gradient, radius: 4),
                      const SizedBox(height: 6),
                      _box(11, 80, gradient, radius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _box(36, 36, gradient, radius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _box(double h, double w, LinearGradient g,
      {required double radius}) {
    return Container(
      height: h,
      width: w == double.infinity ? null : w,
      decoration: BoxDecoration(
        gradient: g,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── ShimmerGrid (búsqueda) ────────────────────────────────────────────────────

class ShimmerGrid extends StatelessWidget {
  const ShimmerGrid({super.key, this.count = 9});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.52,
      ),
      itemBuilder: (_, __) => const CardSkeleton(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/appearance_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/search_button.dart';

// ── Ajustes Screen ─────────────────────────────────────────────────────────────

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final appearance = ref.watch(appearanceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Ajustes',
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const SearchButton(margin: EdgeInsets.zero),
                ],
              ),
              const SizedBox(height: 28),

              // ── User card ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VoidTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VoidTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: auth.isGuest
                            ? null
                            : const LinearGradient(
                                colors: [
                                  VoidTheme.primaryDark,
                                  VoidTheme.primary
                                ],
                              ),
                        color: auth.isGuest ? VoidTheme.surface : null,
                        border: Border.all(
                          color: auth.isGuest
                              ? VoidTheme.cardBorder
                              : VoidTheme.primary.withOpacity(0.4),
                        ),
                      ),
                      child: Icon(
                        auth.isGuest
                            ? Icons.person_off_outlined
                            : Icons.person_rounded,
                        color:
                            auth.isGuest ? VoidTheme.textMuted : Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.isGuest
                                ? 'Modo Invitado'
                                : (auth.username ?? 'Usuario'),
                            style: GoogleFonts.sora(
                              color: VoidTheme.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.isGuest
                                ? 'Sin sesión activa'
                                : (auth.email ?? 'Sesión activa'),
                            style: GoogleFonts.sora(
                              color: VoidTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (auth.isGuest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: VoidTheme.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: VoidTheme.amber.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Invitado',
                          style: GoogleFonts.sora(
                            color: VoidTheme.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (auth.isAuthenticated) ...[
                const SizedBox(height: 16),
                _SyncStatusCard(
                  isSyncing: auth.isSyncing,
                  lastSyncAt: auth.lastSyncAt,
                  error: auth.lastSyncError,
                  onSync: () async {
                    final ok = await ref.read(authProvider.notifier).syncNow();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Progreso sincronizado.'
                              : ref.read(authProvider).lastSyncError ??
                                  'No se pudo sincronizar.',
                        ),
                        backgroundColor:
                            ok ? Colors.green.shade700 : VoidTheme.pink,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 28),

              // ── Settings list (placeholder) ───────────────────────────────
              Text(
                'GENERAL',
                style: GoogleFonts.sora(
                  color: VoidTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Notificaciones',
                subtitle: 'Próximamente',
                onTap: null,
              ),
              _SettingsTile(
                icon: Icons.palette_outlined,
                label: 'Apariencia',
                subtitle: _appearanceSummary(appearance),
                onTap: () => _showAppearanceSheet(context),
              ),
              _SettingsTile(
                icon: Icons.language_outlined,
                label: 'Idioma',
                subtitle: 'Español',
                onTap: null,
              ),

              const Spacer(),

              // ── Logout / Login button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VoidTheme.pink, width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(
                    auth.isGuest ? Icons.login_rounded : Icons.logout_rounded,
                    color: VoidTheme.pink,
                    size: 18,
                  ),
                  label: Text(
                    auth.isGuest ? 'Iniciar Sesión' : 'Cerrar Sesión',
                    style: GoogleFonts.sora(
                      color: VoidTheme.pink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoidTheme.surface,
    builder: (_) => const _AppearanceSheet(),
  );
}

String _appearanceSummary(AppearanceState state) {
  return '${_themeLabel(state.visualTheme)} · '
      '${_motionLabel(state.motionMode)} · '
      '${_episodeViewLabel(state.episodeView)}';
}

String _themeLabel(AppVisualTheme value) {
  switch (value) {
    case AppVisualTheme.voidNeon:
      return 'Void Neon';
    case AppVisualTheme.amoled:
      return 'Negro AMOLED';
  }
}

String _motionLabel(AppMotionMode value) {
  switch (value) {
    case AppMotionMode.normal:
      return 'Animaciones normales';
    case AppMotionMode.reduced:
      return 'Animaciones reducidas';
  }
}

String _episodeViewLabel(EpisodeViewPreference value) {
  switch (value) {
    case EpisodeViewPreference.automatic:
      return 'Vista automática';
    case EpisodeViewPreference.list:
      return 'Vista lista';
    case EpisodeViewPreference.grid:
      return 'Vista cuadrícula';
  }
}

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: VoidTheme.gradientPrimary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apariencia',
                        style: GoogleFonts.sora(
                          color: VoidTheme.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ajustes visuales de la app',
                        style: GoogleFonts.sora(
                          color: VoidTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _AppearanceSection(
              title: 'Tema',
              children: [
                _AppearanceRadio<AppVisualTheme>(
                  title: 'Void Neon',
                  subtitle: 'Morado, cian y fondos oscuros',
                  value: AppVisualTheme.voidNeon,
                  groupValue: appearance.visualTheme,
                  onChanged: notifier.setVisualTheme,
                ),
                _AppearanceRadio<AppVisualTheme>(
                  title: 'Negro AMOLED',
                  subtitle: 'Más oscuro para pantallas OLED',
                  value: AppVisualTheme.amoled,
                  groupValue: appearance.visualTheme,
                  onChanged: notifier.setVisualTheme,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AppearanceSection(
              title: 'Animaciones',
              children: [
                _AppearanceRadio<AppMotionMode>(
                  title: 'Normales',
                  subtitle: 'Transiciones y movimientos completos',
                  value: AppMotionMode.normal,
                  groupValue: appearance.motionMode,
                  onChanged: notifier.setMotionMode,
                ),
                _AppearanceRadio<AppMotionMode>(
                  title: 'Reducidas',
                  subtitle: 'Menos movimiento en navegación y sistema',
                  value: AppMotionMode.reduced,
                  groupValue: appearance.motionMode,
                  onChanged: notifier.setMotionMode,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AppearanceSection(
              title: 'Vista de episodios',
              children: [
                _AppearanceRadio<EpisodeViewPreference>(
                  title: 'Automática',
                  subtitle: 'Lista o cuadrícula según cantidad',
                  value: EpisodeViewPreference.automatic,
                  groupValue: appearance.episodeView,
                  onChanged: notifier.setEpisodeView,
                ),
                _AppearanceRadio<EpisodeViewPreference>(
                  title: 'Lista',
                  subtitle: 'Tarjetas amplias con estado',
                  value: EpisodeViewPreference.list,
                  groupValue: appearance.episodeView,
                  onChanged: notifier.setEpisodeView,
                ),
                _AppearanceRadio<EpisodeViewPreference>(
                  title: 'Cuadrícula',
                  subtitle: 'Números compactos para series largas',
                  value: EpisodeViewPreference.grid,
                  groupValue: appearance.episodeView,
                  onChanged: notifier.setEpisodeView,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.sora(
            color: VoidTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: VoidTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VoidTheme.cardBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _AppearanceRadio<T> extends StatelessWidget {
  const _AppearanceRadio({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final Future<void> Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(selected),
                color: selected ? VoidTheme.cyan : VoidTheme.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sora(
                      color: VoidTheme.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.sora(
                      color: VoidTheme.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.isSyncing,
    required this.lastSyncAt,
    required this.error,
    required this.onSync,
  });

  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? error;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoidTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? VoidTheme.pink.withValues(alpha: 0.45)
              : VoidTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (hasError ? VoidTheme.pink : VoidTheme.cyan)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isSyncing
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: VoidTheme.cyan,
                    ),
                  )
                : Icon(
                    hasError
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_done_rounded,
                    color: hasError ? VoidTheme.pink : VoidTheme.cyan,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sincronización',
                  style: GoogleFonts.sora(
                    color: VoidTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasError ? error! : _formatSyncTime(lastSyncAt),
                  style: GoogleFonts.sora(
                    color: hasError ? VoidTheme.pink : VoidTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: isSyncing ? null : onSync,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: VoidTheme.cyan, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(
              isSyncing ? 'Sync...' : 'Forzar',
              style: GoogleFonts.sora(
                color: VoidTheme.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSyncTime(DateTime? value) {
  if (value == null) return 'Aún no se ha sincronizado en este dispositivo.';
  final local = value.toLocal();
  final now = DateTime.now();
  final time = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Última sync hoy a las $time';
  }
  return 'Última sync ${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} a las $time';
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VoidTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoidTheme.cardBorder),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: VoidTheme.textSecondary, size: 22),
        title: Text(
          label,
          style: GoogleFonts.sora(
            color: VoidTheme.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: GoogleFonts.sora(
                  color: VoidTheme.textMuted,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: VoidTheme.textMuted,
          size: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

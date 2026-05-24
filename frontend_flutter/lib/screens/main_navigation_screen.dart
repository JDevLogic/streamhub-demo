import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/content_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/my_list_provider.dart';
import '../theme.dart';
import 'categorias_screen.dart';
import 'emision_screen.dart';
import 'home_screen.dart';
import 'mi_lista_screen.dart';
import 'settings_screen.dart';

// ── Page index helper ─────────────────────────────────────────────────────────

enum _NavPage { inicio, emision, miLista, categorias, ajustes }

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  _NavPage _current = _NavPage.inicio;

  static const _items = [
    _BottomItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    _BottomItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Emisión',
    ),
    _BottomItem(
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
      label: 'Mi Lista',
    ),
    _BottomItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Categorías',
    ),
    _BottomItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Ajustes',
    ),
  ];

  Widget _buildPage(_NavPage page) {
    final authState = ref.read(authProvider);
    switch (page) {
      case _NavPage.inicio:
        return const HomeScreen();
      case _NavPage.emision:
        return const EmisionScreen();
      case _NavPage.miLista:
        return MiListaScreen(isGuest: authState.isGuest);
      case _NavPage.categorias:
        return const CategoriasScreen();
      case _NavPage.ajustes:
        return const AjustesScreen();
    }
  }

  void _onTabTap(int index) {
    final page = _NavPage.values[index];

    // Block guest access to Mi Lista
    if (page == _NavPage.miLista && ref.read(authProvider).isGuest) {
      _showGuestBlockedSnack();
      return;
    }

    if (page == _NavPage.inicio) {
      ref.read(homeTabRefreshProvider.notifier).update((s) => s + 1);
    }

    if (page == _NavPage.miLista && !ref.read(authProvider).isGuest) {
      ref.invalidate(myListProvider);
      ref.read(miListaTabRefreshProvider.notifier).update((s) => s + 1);
    }

    setState(() => _current = page);
  }

  void _showGuestBlockedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: VoidTheme.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Inicia sesión para acceder a Mi Lista',
                style: GoogleFonts.sora(color: VoidTheme.text, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ref.read(authProvider.notifier).logout();
              },
              child: Text('Acceder',
                  style: GoogleFonts.sora(
                      color: VoidTheme.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        backgroundColor: VoidTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _NavPage.values.indexOf(_current);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: currentIndex,
        children: _NavPage.values.map(_buildPage).toList(),
      ),
      bottomNavigationBar: _VoidBottomBar(
        currentIndex: currentIndex,
        items: _items,
        onTap: _onTabTap,
      ),
    );
  }
}

// ── Custom Bottom Navigation Bar ──────────────────────────────────────────────

class _BottomItem {
  const _BottomItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _VoidBottomBar extends StatelessWidget {
  const _VoidBottomBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<_BottomItem> items;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: VoidTheme.surface,
        border: const Border(
          top: BorderSide(color: VoidTheme.cardBorder, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final item = items[i];
            final isActive = i == currentIndex;

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: _BottomBarItem(
                  item: item,
                  isActive: isActive,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({required this.item, required this.isActive});

  final _BottomItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? VoidTheme.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isActive ? item.activeIcon : item.icon,
            color: isActive ? VoidTheme.primary : VoidTheme.textMuted,
            size: 22,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.sora(
            color: isActive ? VoidTheme.primary : VoidTheme.textMuted,
            fontSize: 10.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}

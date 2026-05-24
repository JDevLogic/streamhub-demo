import 'package:flutter/material.dart';

import '../screens/search_screen.dart';
import '../theme.dart';

class SearchButton extends StatelessWidget {
  const SearchButton({super.key, this.onReturn, this.margin});

  final VoidCallback? onReturn;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: VoidTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoidTheme.cardBorder),
      ),
      child: IconButton(
        icon: const Icon(Icons.search_rounded,
            color: VoidTheme.textSecondary, size: 22),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ).then((_) => onReturn?.call()),
      ),
    );
  }
}

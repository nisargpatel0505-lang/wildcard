import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

enum WildcardCardAccent { neutral, mint, gold, violet, rare, danger }

/// Compact reusable card surface for stats, Jokers and menu-adjacent content.
class WildcardCard extends StatelessWidget {
  const WildcardCard({
    required this.child,
    this.accent = WildcardCardAccent.neutral,
    this.padding = const EdgeInsets.all(12),
    this.radius = 14,
    this.onTap,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final WildcardCardAccent accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool selected;

  Color _accent(WildcardThemeTokens tokens) => switch (accent) {
    WildcardCardAccent.neutral => tokens.line,
    WildcardCardAccent.mint => tokens.mint,
    WildcardCardAccent.gold => tokens.gold,
    WildcardCardAccent.violet => tokens.violet,
    WildcardCardAccent.rare => tokens.rare,
    WildcardCardAccent.danger => tokens.coral,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final accentColor = _accent(tokens);
    final contents = Padding(padding: padding, child: child);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected ? tokens.cream : accentColor.withValues(alpha: 0.82),
          width: selected ? 2.5 : 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tokens.panel, accentColor, 0.08)!,
            tokens.panelStrong,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: selected ? 0.25 : 0.08),
            blurRadius: selected ? 18 : 10,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? contents
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: contents),
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// Reusable translucent panel used by overlays and secondary screens.
class WildcardPanel extends StatelessWidget {
  const WildcardPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.radius = 20,
    this.borderWidth = 2,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final double radius;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? tokens.line.withValues(alpha: 0.88),
        width: borderWidth,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tokens.panel, tokens.panelStrong],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x8A000000),
          blurRadius: 28,
          offset: Offset(0, 16),
        ),
      ],
    );

    final contents = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: decoration,
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

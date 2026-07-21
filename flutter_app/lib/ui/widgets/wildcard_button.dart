import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

enum WildcardButtonVariant { primary, secondary, ghost, danger }

/// Large, phone-first WILDCARD action button.
class WildcardButton extends StatelessWidget {
  const WildcardButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = WildcardButtonVariant.secondary,
    this.minHeight = 54,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.textAlign = TextAlign.left,
    this.fontSize,
    this.expand = true,
    this.showIconFrame = true,
    this.attention = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final WildcardButtonVariant variant;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final TextAlign textAlign;
  final double? fontSize;
  final bool expand;
  final bool showIconFrame;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final enabled = onPressed != null;
    final foreground = switch (variant) {
      WildcardButtonVariant.primary => const Color(0xFF251505),
      WildcardButtonVariant.secondary ||
      WildcardButtonVariant.ghost => tokens.cream,
      WildcardButtonVariant.danger => const Color(0xFF3D0F08),
    };
    final border = switch (variant) {
      WildcardButtonVariant.primary => const Color(0xFFFFE69A),
      WildcardButtonVariant.secondary => tokens.mint.withValues(alpha: 0.76),
      WildcardButtonVariant.ghost => tokens.violet.withValues(alpha: 0.72),
      WildcardButtonVariant.danger => tokens.coral,
    };
    final gradient = switch (variant) {
      WildcardButtonVariant.primary => const [
        Color(0xFFFFD15D),
        Color(0xFFF2A33D),
      ],
      WildcardButtonVariant.secondary => const [
        Color(0xF0173D43),
        Color(0xF0271245),
      ],
      WildcardButtonVariant.ghost => const [
        Color(0xF0211441),
        Color(0xF00B1822),
      ],
      WildcardButtonVariant.danger => [
        tokens.coral,
        Color.lerp(tokens.coral, Colors.black, 0.22)!,
      ],
    };
    final shadowColor = switch (variant) {
      WildcardButtonVariant.primary => const Color(0xFF9C5A19),
      WildcardButtonVariant.secondary => const Color(0xFF102B31),
      WildcardButtonVariant.ghost => const Color(0xFF251345),
      WildcardButtonVariant.danger => const Color(0xFF8A2C1F),
    };

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: enabled ? 1 : 0.42,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: border, width: 1.4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.94),
                offset: const Offset(0, 5),
              ),
              const BoxShadow(
                color: Color(0x70000000),
                blurRadius: 14,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: padding,
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      _IconFrame(
                        color: foreground,
                        borderColor: border,
                        framed: showIconFrame,
                        attention: attention,
                        child: icon!,
                      ),
                      const SizedBox(width: 11),
                    ],
                    Flexible(
                      fit: expand ? FlexFit.tight : FlexFit.loose,
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
                        style: TextStyle(
                          color: foreground,
                          fontFamily: 'Bungee',
                          fontSize: fontSize ?? 14,
                          height: 1.2,
                          letterSpacing: 0.25,
                          shadows: variant == WildcardButtonVariant.primary
                              ? null
                              : const [
                                  Shadow(
                                    color: Color(0xB0000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 2,
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}

class _IconFrame extends StatelessWidget {
  const _IconFrame({
    required this.child,
    required this.color,
    required this.borderColor,
    required this.framed,
    required this.attention,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final bool framed;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.merge(
      data: IconThemeData(color: color, size: 20),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color, fontFamily: 'Bungee', fontSize: 17),
        child: Center(child: child),
      ),
    );
    if (!framed) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: borderColor, width: 1.5),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x22FFFFFF), Color(0x2E000000)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x52000000), blurRadius: 4),
            ],
          ),
          child: icon,
        ),
        if (attention)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: context.wildcard.gold,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF281500), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: context.wildcard.gold.withValues(alpha: 0.7),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Small square control used for sound, music and scoring pace on the menu.
class WildcardSquareButton extends StatelessWidget {
  const WildcardSquareButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = 50,
    this.active = true,
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xD20C1020),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? tokens.violet.withValues(alpha: 0.78)
                    : tokens.line.withValues(alpha: 0.58),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x61000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: IconTheme(
                  data: IconThemeData(
                    color: active ? tokens.creamDim : tokens.line,
                    size: size * 0.43,
                  ),
                  child: Center(child: icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

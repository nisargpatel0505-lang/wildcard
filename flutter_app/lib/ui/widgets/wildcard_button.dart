import 'package:flutter/material.dart';

import '../wildcard_theme.dart';
import 'springy.dart';

enum WildcardButtonVariant { primary, secondary, ghost, danger, success }

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
    this.fontFamily,
    super.key,
  });

  /// Overrides the default Bungee display face. Bungee is very heavy, which
  /// reads as chunky on dense in-run controls like Play/Discard, so those pass
  /// the lighter UI face instead.
  final String? fontFamily;

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
      WildcardButtonVariant.primary => tokens.onSecondaryAccent,
      WildcardButtonVariant.secondary ||
      WildcardButtonVariant.ghost => tokens.cream,
      WildcardButtonVariant.danger => tokens.onDangerAccent,
      WildcardButtonVariant.success => tokens.onPrimaryAccent,
    };
    final border = switch (variant) {
      WildcardButtonVariant.primary => Color.lerp(
        tokens.gold,
        tokens.cream,
        .42,
      )!,
      WildcardButtonVariant.secondary => tokens.mint.withValues(alpha: 0.76),
      WildcardButtonVariant.ghost => tokens.violet.withValues(alpha: 0.72),
      WildcardButtonVariant.danger => tokens.coral,
      WildcardButtonVariant.success => Color.lerp(
        tokens.mint,
        tokens.cream,
        .36,
      )!,
    };
    final gradient = switch (variant) {
      WildcardButtonVariant.primary => [
        Color.lerp(tokens.gold, tokens.cream, .14)!,
        Color.lerp(tokens.gold, tokens.ink, .18)!,
      ],
      WildcardButtonVariant.secondary => [
        Color.alphaBlend(
          tokens.mint.withValues(alpha: .16),
          tokens.surfaceStrong,
        ),
        Color.alphaBlend(
          tokens.violet.withValues(alpha: .16),
          tokens.surfaceStrong,
        ),
      ],
      WildcardButtonVariant.ghost => [
        Color.alphaBlend(
          tokens.violet.withValues(alpha: .19),
          tokens.surfaceStrong,
        ),
        tokens.surfaceStrong,
      ],
      WildcardButtonVariant.danger => [
        tokens.coral,
        Color.lerp(tokens.coral, Colors.black, 0.22)!,
      ],
      // Play Hand: a confident green, so the primary table action reads as
      // "go" against the red Discard beside it.
      WildcardButtonVariant.success => [
        tokens.mint,
        Color.lerp(tokens.mint, tokens.ink, .34)!,
      ],
    };
    final shadowColor = switch (variant) {
      WildcardButtonVariant.primary => Color.lerp(
        tokens.gold,
        tokens.ink,
        .52,
      )!,
      WildcardButtonVariant.secondary => Color.lerp(
        tokens.mint,
        tokens.ink,
        .72,
      )!,
      WildcardButtonVariant.ghost => Color.lerp(
        tokens.violet,
        tokens.ink,
        .68,
      )!,
      WildcardButtonVariant.danger => Color.lerp(
        tokens.coral,
        tokens.ink,
        .50,
      )!,
      WildcardButtonVariant.success => Color.lerp(
        tokens.mint,
        tokens.ink,
        .50,
      )!,
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
              BoxShadow(
                color: tokens.shadow,
                blurRadius: 14,
                offset: const Offset(0, 9),
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
                          fontFamily: fontFamily ?? 'Bungee',
                          fontWeight: fontFamily == null
                              ? FontWeight.w400
                              : FontWeight.w700,
                          fontSize: fontSize ?? 14,
                          height: 1.2,
                          letterSpacing: fontFamily == null ? 0.25 : 0.6,
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

    // A spring press-squish makes every tap feel physical instead of inert.
    final pressable = PressableScale(enabled: enabled, child: button);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: expand
            ? SizedBox(width: double.infinity, child: pressable)
            : pressable,
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
              color: tokens.surfaceStrong,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? tokens.violet.withValues(alpha: 0.78)
                    : tokens.line.withValues(alpha: 0.58),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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

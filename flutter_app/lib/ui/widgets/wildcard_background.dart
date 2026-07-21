import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

enum WildcardRoom { themedHome, palace, shop, vault, endless, house }

/// Full-bleed illustrated room with the restrained v7.1.0 readability tint.
class WildcardBackground extends StatelessWidget {
  const WildcardBackground({
    required this.child,
    this.room = WildcardRoom.themedHome,
    this.asset,
    this.alignment = Alignment.topCenter,
    this.tintStrength = 1,
    super.key,
  });

  final Widget child;
  final WildcardRoom room;
  final String? asset;
  final Alignment alignment;
  final double tintStrength;

  String _assetFor(WildcardThemeTokens tokens) {
    if (asset != null) return asset!;
    return switch (room) {
      WildcardRoom.themedHome => tokens.homeBackgroundAsset,
      WildcardRoom.palace => WildcardThemeTokens.palaceBackground,
      WildcardRoom.shop =>
        'assets/art/backgrounds/wildcard-sly-shop-backroom.webp',
      WildcardRoom.vault =>
        'assets/art/backgrounds/wildcard-royal-vault-chest-room.webp',
      WildcardRoom.endless => WildcardThemeTokens.cosmicBackground,
      WildcardRoom.house =>
        'assets/art/backgrounds/wildcard-the-house-boss-room.webp',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final strength = tintStrength.clamp(0.0, 1.5).toDouble();
    final backgroundAsset = _assetFor(tokens);
    Color tint(Color color) => color.withValues(
      alpha: (color.a * strength).clamp(0.0, 1.0).toDouble(),
    );

    return ColoredBox(
      color: const Color(0xFF080414),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: ValueKey('wildcard-static-background-$backgroundAsset'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    backgroundAsset,
                    alignment: alignment,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: tokens.ink),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          tint(tokens.artTintTop),
                          tint(tokens.artTintMiddle),
                          tint(tokens.artTintBottom),
                        ],
                        stops: const [0, 0.58, 1],
                      ),
                    ),
                  ),
                  // A cheap edge vignette preserves the detail in the centre
                  // without the runtime blur used by the old WebView client.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.16),
                        radius: 1.18,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                        stops: const [0.56, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// Widget tests pump-and-settle whole screens, so the perpetual drift ticker
/// must never run under `flutter test`; on a device this is always false.
final bool _inWidgetTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

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
                  Builder(
                    builder: (context) {
                      // Decode at the physical width the screen can actually
                      // show, capped at the source's 1080px. On a 720p phone
                      // this roughly halves the resident texture memory.
                      final media = MediaQuery.maybeOf(context);
                      final decodeWidth = media == null
                          ? null
                          : math.min(
                              1080,
                              (media.size.width * media.devicePixelRatio)
                                  .ceil(),
                            );
                      return Image.asset(
                        backgroundAsset,
                        alignment: alignment,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: decodeWidth,
                        errorBuilder: (context, error, stackTrace) =>
                            ColoredBox(color: tokens.ink),
                      );
                    },
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
          // The WebView rooms breathed: three light blobs drifted slowly over
          // the art (`drift1..3`). The blobs are constant subtrees moved by a
          // compositor transform, so the drift costs no repaint of the room.
          const Positioned.fill(
            child: IgnorePointer(child: _AmbientDrift()),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientDrift extends StatefulWidget {
  const _AmbientDrift();

  @override
  State<_AmbientDrift> createState() => _AmbientDriftState();
}

class _AmbientDriftState extends State<_AmbientDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled =
        _inWidgetTest || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (disabled) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        _inWidgetTest || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (disabled) return const SizedBox.shrink();
    final tokens = context.wildcard;
    final size = MediaQuery.sizeOf(context);
    Widget blob(Color color, double diameter) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
      child: SizedBox.square(dimension: diameter),
    );
    return RepaintBoundary(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          // Both blobs are constant subtrees; only their transforms change.
          child: null,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            // Fixed Positioned anchors + varying Transform offsets keep each
            // blob's raster cached; the drift is pure compositor work.
            return Stack(
              children: [
                Positioned(
                  left: size.width * 0.06,
                  top: size.height * 0.10,
                  child: Transform.translate(
                    offset: Offset(math.sin(t) * 34, math.cos(t * 0.8) * 26),
                    child: RepaintBoundary(
                      child: blob(
                        tokens.violet.withValues(alpha: 0.075),
                        size.width * 0.9,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: size.width * 0.02,
                  bottom: size.height * 0.06,
                  child: Transform.translate(
                    offset: Offset(math.cos(t * 0.7) * 30, math.sin(t * 0.9) * 24),
                    child: RepaintBoundary(
                      child: blob(
                        tokens.gold.withValues(alpha: 0.05),
                        size.width * 0.74,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

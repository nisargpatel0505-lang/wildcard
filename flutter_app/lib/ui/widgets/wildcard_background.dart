import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../effects_profile.dart';
import '../wildcard_theme.dart';

/// Widget tests pump-and-settle whole screens, so the perpetual drift ticker
/// must never run under `flutter test`; on a device this is always false.
final bool _inWidgetTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

enum WildcardRoom { themedHome, runSetup, palace, shop, vault, endless, house }

/// Full-bleed illustrated room with the restrained v7.1.0 readability tint.
class WildcardBackground extends StatelessWidget {
  const WildcardBackground({
    required this.child,
    this.room = WildcardRoom.themedHome,
    this.asset,
    this.alignment = Alignment.topCenter,
    this.tintStrength = 1,
    this.energy = 0,
    this.modifierActive = false,
    this.houseActive = false,
    this.momentPulse = 0,
    super.key,
  });

  final Widget child;
  final WildcardRoom room;
  final String? asset;
  final Alignment alignment;
  final double tintStrength;
  final double energy;
  final bool modifierActive;
  final bool houseActive;
  final double momentPulse;

  String? _assetFor(WildcardThemeTokens tokens) {
    if (asset != null) return asset!;
    return switch (room) {
      WildcardRoom.themedHome => tokens.homeBackgroundAsset,
      WildcardRoom.runSetup => null,
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
    final effects = EffectsProfile.resolve(context);
    final strength = tintStrength.clamp(0.0, 1.5).toDouble();
    final atmosphereEnergy = energy.clamp(0.0, 1.25).toDouble();
    final backgroundAsset = _assetFor(tokens);
    final quietRunSetup = room == WildcardRoom.runSetup;
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
                  if (backgroundAsset == null)
                    const _RunSetupBackdrop()
                  else
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
                        colors: quietRunSetup
                            ? const [
                                Color(0x8A020504),
                                Color(0x54030907),
                                Color(0xD9020303),
                              ]
                            : [
                                tint(tokens.artTintTop),
                                tint(tokens.artTintMiddle),
                                tint(tokens.artTintBottom),
                              ],
                        stops: const [0, 0.58, 1],
                      ),
                    ),
                  ),
                  if (atmosphereEnergy > 0 ||
                      modifierActive ||
                      houseActive ||
                      momentPulse > 0)
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _RoomStatePainter(
                          energy: atmosphereEnergy,
                          modifierActive: modifierActive,
                          houseActive: houseActive,
                          momentPulse: momentPulse.clamp(0.0, 1.0).toDouble(),
                          mint: tokens.mint,
                          gold: tokens.gold,
                          violet: tokens.violet,
                          glowScale: effects.glowScale,
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
          Positioned.fill(
            child: IgnorePointer(
              child: _AmbientDrift(
                enabled: effects.backgroundMotion && !quietRunSetup,
                intensity: effects.glowScale,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A restrained poker-room surface for setup screens. It is intentionally
/// asset-free, static and almost black so controls remain the visual priority.
class _RunSetupBackdrop extends StatelessWidget {
  const _RunSetupBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -0.08),
        radius: 1.02,
        colors: [Color(0xFF16231E), Color(0xFF090E0C), Color(0xFF030505)],
        stops: [0, .58, 1],
      ),
    ),
    child: CustomPaint(painter: _RunSetupPokerPainter()),
  );
}

class _RunSetupPokerPainter extends CustomPainter {
  const _RunSetupPokerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final table = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .53),
      width: size.width * 1.18,
      height: size.height * .54,
    );
    canvas.drawOval(
      table,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x331E5B46), Color(0x071E5B46)],
          stops: [0, 1],
        ).createShader(table),
    );
    canvas.drawOval(
      table,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x2459B995),
    );
    canvas.drawOval(
      table.deflate(9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1559B995),
    );

    // Four tiny card pips give the room a poker identity without becoming a
    // patterned or animated backdrop.
    final pip = Paint()..color = const Color(0x1559B995);
    final pipSize = math.min(size.width, size.height) * .022;
    for (final point in <Offset>[
      Offset(size.width * .18, size.height * .29),
      Offset(size.width * .82, size.height * .29),
      Offset(size.width * .18, size.height * .77),
      Offset(size.width * .82, size.height * .77),
    ]) {
      final diamond = Path()
        ..moveTo(point.dx, point.dy - pipSize)
        ..lineTo(point.dx + pipSize * .72, point.dy)
        ..lineTo(point.dx, point.dy + pipSize)
        ..lineTo(point.dx - pipSize * .72, point.dy)
        ..close();
      canvas.drawPath(diamond, pip);
    }
  }

  @override
  bool shouldRepaint(covariant _RunSetupPokerPainter oldDelegate) => false;
}

class _AmbientDrift extends StatefulWidget {
  const _AmbientDrift({required this.enabled, required this.intensity});

  final bool enabled;
  final double intensity;

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
        !widget.enabled ||
        _inWidgetTest ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
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
        !widget.enabled ||
        _inWidgetTest ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (disabled) return const SizedBox.shrink();
    final tokens = context.wildcard;
    final size = MediaQuery.sizeOf(context);
    Widget blob(Color color, double diameter) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
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
                        tokens.violet.withValues(
                          alpha: 0.075 * widget.intensity,
                        ),
                        size.width * 0.9,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: size.width * 0.02,
                  bottom: size.height * 0.06,
                  child: Transform.translate(
                    offset: Offset(
                      math.cos(t * 0.7) * 30,
                      math.sin(t * 0.9) * 24,
                    ),
                    child: RepaintBoundary(
                      child: blob(
                        tokens.gold.withValues(alpha: 0.05 * widget.intensity),
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

  @override
  void didUpdateWidget(covariant _AmbientDrift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (!widget.enabled) {
      _c.stop();
    } else if (!_inWidgetTest &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _c.repeat();
    }
  }
}

/// A static, allocation-free reaction layer. It is repainted only when the
/// committed Heat state changes, never on every scoring beat.
class _RoomStatePainter extends CustomPainter {
  const _RoomStatePainter({
    required this.energy,
    required this.modifierActive,
    required this.houseActive,
    required this.momentPulse,
    required this.mint,
    required this.gold,
    required this.violet,
    required this.glowScale,
  });

  final double energy;
  final bool modifierActive;
  final bool houseActive;
  final double momentPulse;
  final Color mint;
  final Color gold;
  final Color violet;
  final double glowScale;

  @override
  void paint(Canvas canvas, Size size) {
    final warmth = ((energy - .42) / .58).clamp(0.0, 1.0);
    if (warmth > 0 || momentPulse > 0) {
      final alpha = (.06 + warmth * .11 + momentPulse * .08) * glowScale;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, .36),
            radius: 1.02,
            colors: [
              Color.lerp(
                mint,
                gold,
                warmth,
              )!.withValues(alpha: alpha.clamp(0.0, .24)),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size),
      );
    }

    if (!modifierActive && !houseActive) return;
    final accent = houseActive ? gold : violet;
    final line = Paint()
      ..color = accent.withValues(alpha: houseActive ? .10 : .065)
      ..strokeWidth = houseActive ? 1.4 : 1;
    final spacing = houseActive ? 54.0 : 68.0;
    for (var y = size.height * .12; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Four fixed suit seals provide modifier atmosphere without permanent
    // suit rain or a ticker.
    const suits = <String>['♠', '♥', '♦', '♣'];
    final painter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < suits.length; index++) {
      painter.text = TextSpan(
        text: suits[index],
        style: TextStyle(
          color: accent.withValues(alpha: houseActive ? .13 : .09),
          fontSize: size.shortestSide * .105,
          fontWeight: FontWeight.w700,
        ),
      );
      painter.layout();
      final left = index.isEven ? size.width * .05 : size.width * .82;
      final top = size.height * (.2 + index * .18);
      painter.paint(canvas, Offset(left, top));
    }
  }

  @override
  bool shouldRepaint(covariant _RoomStatePainter oldDelegate) =>
      oldDelegate.energy != energy ||
      oldDelegate.modifierActive != modifierActive ||
      oldDelegate.houseActive != houseActive ||
      oldDelegate.momentPulse != momentPulse ||
      oldDelegate.glowScale != glowScale ||
      oldDelegate.mint != mint ||
      oldDelegate.gold != gold ||
      oldDelegate.violet != violet;
}

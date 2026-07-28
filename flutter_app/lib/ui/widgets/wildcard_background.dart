import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../effects_profile.dart';
import '../wildcard_theme.dart';
import 'sly_sprite.dart';

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
    this.surface,
    this.asset,
    this.alignment = Alignment.topCenter,
    this.tintStrength = 1,
    this.energy = 0,
    this.modifierActive = false,
    this.houseActive = false,
    this.momentPulse = 0,
    this.runSetupMotionInTests = false,
    super.key,
  });

  final Widget child;
  final WildcardRoom room;
  final WildcardUiSurface? surface;
  final String? asset;
  final Alignment alignment;
  final double tintStrength;
  final double energy;
  final bool modifierActive;
  final bool houseActive;
  final double momentPulse;

  /// Allows the run-setup ticker to run in a focused widget test.
  ///
  /// Production callers must leave this false. Widget tests otherwise keep
  /// perpetual background tickers stopped so whole-screen `pumpAndSettle`
  /// calls remain deterministic.
  @visibleForTesting
  final bool runSetupMotionInTests;

  String? _assetFor(WildcardThemeTokens tokens) {
    if (asset != null) return asset!;
    if (surface case final themedSurface?) {
      return tokens.backgroundAssetFor(themedSurface);
    }
    return switch (room) {
      WildcardRoom.themedHome => tokens.homeBackgroundAsset,
      WildcardRoom.runSetup => null,
      WildcardRoom.palace => WildcardThemeTokens.palaceBackground,
      WildcardRoom.shop =>
        'assets/art/backgrounds/wildcard-sly-shop-backroom.webp',
      WildcardRoom.vault => 'assets/art/chests/wildcard-sly-vault-room.webp',
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
    final quietRunSetup = surface != null
        ? WildcardThemeCoverage.forSurface(surface!).backdrop ==
              WildcardBackdropRole.runSetup
        : room == WildcardRoom.runSetup;
    Color tint(Color color) => color.withValues(
      alpha: (color.a * strength).clamp(0.0, 1.0).toDouble(),
    );

    return ColoredBox(
      key: ValueKey(
        'wildcard-surface-${surface?.name ?? 'legacy-${room.name}'}',
      ),
      color: tokens.pageBackground,
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
                    _RunSetupBackdrop(tokens: tokens)
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
                            ? [
                                tokens.ink.withValues(alpha: .54),
                                tokens.felt.withValues(alpha: .34),
                                tokens.ink.withValues(alpha: .86),
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
          if (quietRunSetup)
            Positioned.fill(
              child: IgnorePointer(
                child: _RunSetupAtmosphere(
                  motionEnabled:
                      runSetupMotionInTests || effects.backgroundMotion,
                  glowScale: effects.glowScale,
                  runInWidgetTests: runSetupMotionInTests,
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
  const _RunSetupBackdrop({required this.tokens});

  final WildcardThemeTokens tokens;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.08),
        radius: 1.02,
        colors: [tokens.feltHighlight, tokens.ink, tokens.panelStrong],
        stops: const [0, .58, 1],
      ),
    ),
    child: CustomPaint(
      painter: _RunSetupPokerPainter(
        line: tokens.line,
        accent: tokens.mint,
        felt: tokens.felt,
      ),
    ),
  );
}

class _RunSetupPokerPainter extends CustomPainter {
  const _RunSetupPokerPainter({
    required this.line,
    required this.accent,
    required this.felt,
  });

  final Color line;
  final Color accent;
  final Color felt;

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
        ..shader = RadialGradient(
          colors: [felt.withValues(alpha: .30), felt.withValues(alpha: .04)],
          stops: const [0, 1],
        ).createShader(table),
    );
    canvas.drawOval(
      table,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = line.withValues(alpha: .30),
    );
    canvas.drawOval(
      table.deflate(9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: .18),
    );

    // Four tiny card pips give the room a poker identity without becoming a
    // patterned or animated backdrop.
    final pip = Paint()..color = accent.withValues(alpha: .18);
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
  bool shouldRepaint(covariant _RunSetupPokerPainter oldDelegate) =>
      oldDelegate.line != line ||
      oldDelegate.accent != accent ||
      oldDelegate.felt != felt;
}

/// Lightweight native atmosphere for the Choose Run screen.
///
/// The room art stays in its own static repaint boundary above. This layer only
/// moves cached suit glyphs and one cached Sly silhouette with compositor
/// transforms, so the long mode-picker list is never repainted by the motion.
class _RunSetupAtmosphere extends StatefulWidget {
  const _RunSetupAtmosphere({
    required this.motionEnabled,
    required this.glowScale,
    required this.runInWidgetTests,
  });

  final bool motionEnabled;
  final double glowScale;
  final bool runInWidgetTests;

  @override
  State<_RunSetupAtmosphere> createState() => _RunSetupAtmosphereState();
}

class _RunSetupAtmosphereState extends State<_RunSetupAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  bool get _motionDisabled =>
      !widget.motionEnabled ||
      (_inWidgetTest && !widget.runInWidgetTests) ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _RunSetupAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motionEnabled != widget.motionEnabled ||
        oldWidget.runInWidgetTests != widget.runInWidgetTests) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (_motionDisabled) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return ExcludeSemantics(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final shortest = size.shortestSide;
            final compact = shortest < 350 || size.height < 620;
            final tablet = shortest >= 600;
            final suitCount = compact ? 5 : (tablet ? 10 : 8);
            final slySize = math
                .min(size.width * (tablet ? .50 : .70), size.height * .38)
                .clamp(170.0, 460.0)
                .toDouble();
            final staticProgress = compact ? .16 : .11;

            return SizedBox.expand(
              key: const ValueKey('run-setup-atmosphere'),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: -slySize * (compact ? .05 : .07),
                    right: -slySize * (compact ? .16 : .14),
                    child: _RunSetupSlySilhouette(
                      animation: _controller,
                      motionDisabled: _motionDisabled,
                      staticProgress: staticProgress,
                      compact: compact,
                      size: slySize,
                      glowScale: widget.glowScale,
                      color: Color.lerp(tokens.violet, tokens.mint, .22)!,
                    ),
                  ),
                  Positioned.fill(
                    key: const ValueKey('run-setup-floating-suits'),
                    child: Stack(
                      children: [
                        for (var index = 0; index < suitCount; index++)
                          _floatingSuit(
                            context,
                            size,
                            _runSetupSuits[index],
                            index,
                            compact: compact,
                            staticProgress: staticProgress,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _floatingSuit(
    BuildContext context,
    Size room,
    _RunSetupSuitSpec spec,
    int index, {
    required bool compact,
    required double staticProgress,
  }) {
    final tokens = context.wildcard;
    final base = switch (spec.glyph) {
      '♥' => tokens.coral,
      '♦' => tokens.gold,
      '♣' => tokens.mint,
      _ => tokens.violet,
    };
    final fontSize = (room.shortestSide * spec.sizeFactor)
        .clamp(22.0, 58.0)
        .toDouble();
    final left = (spec.anchor.x + 1) * .5 * room.width - fontSize * .5;
    final top = (spec.anchor.y + 1) * .5 * room.height - fontSize * .6;

    return Positioned(
      left: left,
      top: top,
      child: _RunSetupFloatingSuit(
        key: ValueKey('run-setup-suit-$index'),
        animation: _controller,
        motionDisabled: _motionDisabled,
        staticProgress: staticProgress,
        room: room,
        spec: spec,
        compact: compact,
        glowScale: widget.glowScale,
        color: base,
        fontSize: fontSize,
      ),
    );
  }
}

class _RunSetupSlySilhouette extends StatelessWidget {
  const _RunSetupSlySilhouette({
    required this.animation,
    required this.motionDisabled,
    required this.staticProgress,
    required this.compact,
    required this.size,
    required this.glowScale,
    required this.color,
  });

  final Animation<double> animation;
  final bool motionDisabled;
  final double staticProgress;
  final bool compact;
  final double size;
  final double glowScale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: Opacity(
        opacity: (compact ? .073 : .102) * glowScale.clamp(.55, 1.12),
        child: RepaintBoundary(
          key: const ValueKey('run-setup-sly-silhouette'),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: SlySprite(
              expression: SlyExpression.thoughtful,
              size: size,
              animate: false,
              semanticLabel: '',
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final progress = motionDisabled ? staticProgress : animation.value;
        final radians = progress * math.pi * 2;
        return Transform.translate(
          key: const ValueKey('run-setup-sly-motion'),
          offset: Offset(
            math.sin(radians * .72) * (compact ? 3 : 7),
            math.cos(radians * .58) * (compact ? 2 : 5),
          ),
          child: Transform.rotate(
            angle: -.035 + math.sin(radians * .44) * .012,
            child: Transform.scale(
              scale: 1 + math.sin(radians * .64) * (compact ? .006 : .012),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _RunSetupFloatingSuit extends StatelessWidget {
  const _RunSetupFloatingSuit({
    required this.animation,
    required this.motionDisabled,
    required this.staticProgress,
    required this.room,
    required this.spec,
    required this.compact,
    required this.glowScale,
    required this.color,
    required this.fontSize,
    super.key,
  });

  final Animation<double> animation;
  final bool motionDisabled;
  final double staticProgress;
  final Size room;
  final _RunSetupSuitSpec spec;
  final bool compact;
  final double glowScale;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final alpha =
        spec.opacity * glowScale.clamp(.55, 1.12) * (compact ? .78 : 1);
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(
        child: Text(
          spec.glyph,
          style: TextStyle(
            color: color.withValues(alpha: alpha.clamp(0.0, .2)),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
      builder: (context, child) {
        final progress = motionDisabled ? staticProgress : animation.value;
        final radians = progress * math.pi * 2;
        final wave = radians + spec.phase * math.pi * 2;
        final x = math.sin(wave * spec.speed) * room.width * spec.travelX;
        final y =
            math.cos(wave * (spec.speed * .78)) * room.height * spec.travelY;
        final scale = 1 + math.sin(wave * .66) * (compact ? .018 : .035);
        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.rotate(
            angle: spec.tilt + math.sin(wave * .54) * .10,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

@immutable
class _RunSetupSuitSpec {
  const _RunSetupSuitSpec({
    required this.glyph,
    required this.anchor,
    required this.sizeFactor,
    required this.phase,
    required this.speed,
    required this.travelX,
    required this.travelY,
    required this.opacity,
    required this.tilt,
  });

  final String glyph;
  final Alignment anchor;
  final double sizeFactor;
  final double phase;
  final double speed;
  final double travelX;
  final double travelY;
  final double opacity;
  final double tilt;
}

const List<_RunSetupSuitSpec> _runSetupSuits = [
  _RunSetupSuitSpec(
    glyph: '♠',
    anchor: Alignment(-.82, -.72),
    sizeFactor: .105,
    phase: .04,
    speed: .72,
    travelX: .025,
    travelY: .018,
    opacity: .13,
    tilt: -.14,
  ),
  _RunSetupSuitSpec(
    glyph: '♥',
    anchor: Alignment(.78, -.62),
    sizeFactor: .082,
    phase: .22,
    speed: .88,
    travelX: .022,
    travelY: .024,
    opacity: .12,
    tilt: .12,
  ),
  _RunSetupSuitSpec(
    glyph: '♦',
    anchor: Alignment(-.70, -.18),
    sizeFactor: .072,
    phase: .40,
    speed: .64,
    travelX: .030,
    travelY: .017,
    opacity: .14,
    tilt: -.08,
  ),
  _RunSetupSuitSpec(
    glyph: '♣',
    anchor: Alignment(.84, .02),
    sizeFactor: .095,
    phase: .58,
    speed: .80,
    travelX: .018,
    travelY: .022,
    opacity: .115,
    tilt: .10,
  ),
  _RunSetupSuitSpec(
    glyph: '♠',
    anchor: Alignment(-.86, .52),
    sizeFactor: .080,
    phase: .74,
    speed: .91,
    travelX: .024,
    travelY: .019,
    opacity: .105,
    tilt: .16,
  ),
  _RunSetupSuitSpec(
    glyph: '♥',
    anchor: Alignment(.71, .68),
    sizeFactor: .068,
    phase: .91,
    speed: .70,
    travelX: .027,
    travelY: .016,
    opacity: .115,
    tilt: -.11,
  ),
  _RunSetupSuitSpec(
    glyph: '♦',
    anchor: Alignment(-.35, .86),
    sizeFactor: .058,
    phase: .13,
    speed: .84,
    travelX: .018,
    travelY: .014,
    opacity: .10,
    tilt: .08,
  ),
  _RunSetupSuitSpec(
    glyph: '♣',
    anchor: Alignment(.28, -.88),
    sizeFactor: .064,
    phase: .31,
    speed: .76,
    travelX: .020,
    travelY: .016,
    opacity: .095,
    tilt: -.12,
  ),
  _RunSetupSuitSpec(
    glyph: '♠',
    anchor: Alignment(-.18, .24),
    sizeFactor: .050,
    phase: .49,
    speed: .82,
    travelX: .014,
    travelY: .012,
    opacity: .075,
    tilt: .06,
  ),
  _RunSetupSuitSpec(
    glyph: '♦',
    anchor: Alignment(.40, .42),
    sizeFactor: .052,
    phase: .67,
    speed: .68,
    travelX: .016,
    travelY: .014,
    opacity: .08,
    tilt: -.06,
  ),
];

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

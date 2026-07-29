import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// The WebView's arcade "GAME OVER / RUN TERMINATED" pull-over (`#deathfx`),
/// rebuilt with more punch.
///
/// A red wash paints down over the whole screen, the title slams in with a
/// white impact flash and a decaying screen shake, holds with an arcade
/// flicker over drifting scanlines, then fades — shown the instant a run ends,
/// before the ad.
class DeathScreenOverlay extends StatefulWidget {
  const DeathScreenOverlay({
    required this.terminated,
    required this.onFinished,
    super.key,
  });

  /// `true` when the player folded/abandoned, `false` on a genuine defeat.
  final bool terminated;
  final VoidCallback onFinished;

  static const Duration total = Duration(milliseconds: 3200);

  @override
  State<DeathScreenOverlay> createState() => _DeathScreenOverlayState();
}

class _DeathScreenOverlayState extends State<DeathScreenOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: DeathScreenOverlay.total,
  );

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onFinished);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    // Each word on its own line, so a long word like TERMINATED can never wrap
    // its last letter onto a fresh line the way it did before.
    final words = (widget.terminated ? 'RUN TERMINATED' : 'GAME OVER').split(
      ' ',
    );
    final sub = widget.terminated ? 'PLAYER FOLDED' : 'RUN TERMINATED';
    final washColors = widget.terminated
        ? [
            Color.lerp(tokens.ink, tokens.coral, .08)!,
            Color.lerp(tokens.ink, tokens.coral, .45)!,
            Color.lerp(tokens.ink, tokens.coral, .68)!,
          ]
        : [
            Color.lerp(tokens.ink, tokens.coral, .16)!,
            Color.lerp(tokens.ink, tokens.coral, .62)!,
            tokens.coral,
          ];

    // Wrap in a transparent Material so the Text descendants resolve a proper
    // text style instead of the framework's yellow "no Material" underline.
    return Material(
      type: MaterialType.transparency,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Wash fills top→bottom over the first ~0.5s.
            final fill = Curves.easeOutCubic.transform(
              (t / 0.16).clamp(0.0, 1.0),
            );
            // Title slams in at ~520ms.
            const landAt = 0.163;
            final landP = ((t - landAt) / 0.11).clamp(0.0, 1.0);
            final textIn = Curves.easeOutBack.transform(landP);
            // Hard decaying screen shake right after the slam.
            final shakeE = ((t - landAt) / 0.20).clamp(0.0, 1.0);
            final shakeAmp = (1 - shakeE) * 14;
            final shake = Offset(
              math.sin(shakeE * math.pi * 9) * shakeAmp,
              math.cos(shakeE * math.pi * 7) * shakeAmp * 0.6,
            );
            // White impact flash at the moment of landing.
            final flash = landP < 1
                ? (1 - (landP / 0.5).clamp(0.0, 1.0)) * (landP > 0 ? 1 : 0)
                : 0.0;
            // Arcade CRT flicker while it holds.
            final holding = t > 0.30 && t < 0.86;
            final flicker = holding && _rng.nextDouble() < 0.12
                ? 0.82 + _rng.nextDouble() * 0.18
                : 1.0;
            // Slow scanline drift.
            final scanShift = t * 220;
            // Everything fades over the last ~0.4s.
            final fade = 1 - ((t - 0.875) / 0.125).clamp(0.0, 1.0);
            final scale = 2.3 - 1.3 * textIn;

            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: shake,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      key: const ValueKey('wildcard-surface-gameOver'),
                      color: Color.lerp(tokens.ink, tokens.coral, .24)!,
                    ),
                    // The red wash, scaling down from the top edge.
                    Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: fill.clamp(0.0001, 1.0),
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: washColors,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.shadow,
                                blurRadius: 140,
                                spreadRadius: -20,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _ScanlinePainter(shift: scanShift),
                          ),
                        ),
                      ),
                    ),
                    // Title + subtitle.
                    if (textIn > 0)
                      Center(
                        child: Opacity(
                          opacity: (textIn * flicker).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final word in words)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        word,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontFamily: 'Bungee',
                                          fontSize: widget.terminated ? 62 : 72,
                                          height: 1.02,
                                          letterSpacing: 2,
                                          color: tokens.gold,
                                          shadows: [
                                            Shadow(
                                              color: tokens.coral,
                                              blurRadius: 20,
                                            ),
                                            Shadow(
                                              color: tokens.ink,
                                              offset: const Offset(0, 4),
                                            ),
                                            Shadow(
                                              color: tokens.coral.withValues(
                                                alpha: .55,
                                              ),
                                              blurRadius: 50,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Text(
                                    sub,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Bungee',
                                      fontSize: 15,
                                      letterSpacing: 4.5,
                                      color: Color.lerp(
                                        tokens.coral,
                                        tokens.cream,
                                        .58,
                                      ),
                                      shadows: [
                                        Shadow(
                                          color: tokens.coral,
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // White impact flash on landing.
                    if (flash > 0.01)
                      IgnorePointer(
                        child: ColoredBox(
                          color: Colors.white.withValues(
                            alpha: (flash * 0.5).clamp(0.0, 1.0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The arcade CRT scanlines that give the wash its cabinet feel; they drift
/// slowly downward for a live, powered-on look.
class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter({required this.shift});

  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x33000000);
    final start = shift % 4;
    for (var y = start - 4; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) =>
      oldDelegate.shift != shift;
}

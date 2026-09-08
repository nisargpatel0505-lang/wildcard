import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// Decorative, deterministic motion in its own repaint boundary. No game RNG,
/// image decode, blur, saveLayer or widget rebuild is performed per frame.
/// Backgrounds remain static in reduced motion and while the app is hidden.
class LiveThemeAtmosphere extends StatefulWidget {
  const LiveThemeAtmosphere({
    required this.style,
    required this.primary,
    required this.secondary,
    this.motionEnabled = true,
    this.runInWidgetTests = false,
    super.key,
  });

  final WildcardLiveBackdrop style;
  final Color primary;
  final Color secondary;
  final bool motionEnabled;
  @visibleForTesting
  final bool runInWidgetTests;

  @override
  State<LiveThemeAtmosphere> createState() => _LiveThemeAtmosphereState();
}

class _LiveThemeAtmosphereState extends State<LiveThemeAtmosphere>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..addListener(_tick);
  final ValueNotifier<double> _phase = ValueNotifier<double>(.18);
  bool _foreground = true;
  int _lastFrame = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant LiveThemeAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _tick() {
    // At most 30 tiny decorative paints per second, even on a 120Hz screen.
    final frame = (_clock.value * 720).floor();
    if (frame == _lastFrame) return;
    _lastFrame = frame;
    _phase.value = frame / 720;
  }

  void _syncMotion() {
    final test = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    final enabled =
        widget.motionEnabled &&
        widget.style != WildcardLiveBackdrop.none &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        (!test || widget.runInWidgetTests);
    if (enabled) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        key: ValueKey('live-theme-${widget.style.name}'),
        child: ClipRect(
          child: CustomPaint(
            painter: LiveThemePainter(
              phase: _phase,
              style: widget.style,
              primary: widget.primary,
              secondary: widget.secondary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

@visibleForTesting
class LiveThemePainter extends CustomPainter {
  LiveThemePainter({
    required this.phase,
    required this.style,
    required this.primary,
    required this.secondary,
  }) : super(repaint: phase);

  final ValueListenable<double> phase;
  final WildcardLiveBackdrop style;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || style == WildcardLiveBackdrop.none) return;
    final t = phase.value * math.pi * 2;
    switch (style) {
      case WildcardLiveBackdrop.observatory:
        _aurora(canvas, size, t);
        _motes(canvas, size, t, stars: true);
      case WildcardLiveBackdrop.conservatory:
        _lightFan(canvas, size, t, .07);
        _motes(canvas, size, t);
      case WildcardLiveBackdrop.afterhours:
        _rain(canvas, size, t);
      case WildcardLiveBackdrop.theatre:
        _lightFan(canvas, size, t, .045);
        _motes(canvas, size, t);
      case WildcardLiveBackdrop.none:
        break;
    }
  }

  void _aurora(Canvas canvas, Size s, double t) {
    for (var i = 0; i < 3; i++) {
      final y = s.height * (.12 + i * .075);
      final shift = math.sin(t + i) * s.height * .018;
      final path = Path()
        ..moveTo(-20, y + shift)
        ..cubicTo(
          s.width * .30,
          y - s.height * .09,
          s.width * .62,
          y + s.height * .13,
          s.width + 20,
          y - shift,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11 + i * 4
          ..shader = LinearGradient(
            colors: [
              primary.withValues(alpha: 0),
              primary.withValues(alpha: .08),
              secondary.withValues(alpha: .07),
              secondary.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, y - 80, s.width, 160)),
      );
    }
  }

  void _motes(Canvas canvas, Size s, double t, {bool stars = false}) {
    final paint = Paint();
    for (var i = 0; i < 16; i++) {
      // Keep lower-screen movement near the edges, away from scoring and cards.
      final xUnit = ((i * 37 + 11) % 101) / 101;
      final x = s.width * (i < 7 ? xUnit : (i.isEven ? .055 : .945));
      final y = s.height * (.07 + ((i * 19) % 79) / 100);
      final p = Offset(x + math.sin(t + i) * 5, y + math.cos(t + i * 2) * 9);
      final alpha = .10 + (math.sin(t + i * 1.7) + 1) * .09;
      paint.color = secondary.withValues(alpha: alpha);
      canvas.drawCircle(p, stars ? 1.0 : 1.5, paint);
      if (stars && i % 3 == 0) {
        paint.strokeWidth = .7;
        canvas.drawLine(p - const Offset(3, 0), p + const Offset(3, 0), paint);
        canvas.drawLine(p - const Offset(0, 3), p + const Offset(0, 3), paint);
      }
    }
  }

  void _rain(Canvas canvas, Size s, double t) {
    final paint = Paint()..strokeWidth = .8;
    for (var i = 0; i < 18; i++) {
      final x = s.width * (((i * 29 + 7) % 97) / 97);
      final cycle = (phase.value * 4 + i / 18) % 1;
      final y = cycle * s.height * .55;
      paint.color = (i.isEven ? primary : secondary).withValues(
        alpha: .12 * math.sin(cycle * math.pi),
      );
      canvas.drawLine(Offset(x, y), Offset(x - 2, y + 12), paint);
    }
    final y = s.height * (.24 + math.sin(t) * .015);
    canvas.drawLine(
      Offset(0, y),
      Offset(s.width, y + s.height * .09),
      Paint()
        ..color = primary.withValues(alpha: .045)
        ..strokeWidth = 3,
    );
  }

  void _lightFan(Canvas canvas, Size s, double t, double alpha) {
    for (var i = 0; i < 2; i++) {
      final anchor = Offset(s.width * (i == 0 ? .1 : .9), -20);
      final end = s.width * (.38 + i * .24 + math.sin(t + i) * .08);
      final path = Path()
        ..moveTo(anchor.dx, anchor.dy)
        ..lineTo(end - s.width * .16, s.height * .64)
        ..lineTo(end + s.width * .16, s.height * .64)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              secondary.withValues(alpha: alpha),
              secondary.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, s.width, s.height * .64)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LiveThemePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.style != style ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}

import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// The Heat-opening wash from the WebView build (`#round-intro`).
///
/// The original faded a skewed card over the whole table at the start of every
/// Heat — kicker, HEAT number, and the modifier/target line — held it, then
/// faded out. The Flutter port shipped without it entirely, which is why heats
/// now begin with no sense of occasion.
///
/// Timings mirror the original: 2600ms normal, 2900ms with a modifier, 3200ms
/// on a boss table, with the wash itself easing in over the first ~12%.
class RoundIntroOverlay extends StatefulWidget {
  const RoundIntroOverlay({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.boss,
    required this.onFinished,
    super.key,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final bool boss;
  final VoidCallback onFinished;

  static Duration durationFor({required bool boss, required bool modifier}) =>
      Duration(milliseconds: boss ? 3200 : (modifier ? 2900 : 2600));

  @override
  State<RoundIntroOverlay> createState() => _RoundIntroOverlayState();
}

class _RoundIntroOverlayState extends State<RoundIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RoundIntroOverlay.durationFor(
      boss: widget.boss,
      modifier: widget.subtitle.contains('—'),
    ),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final accent = widget.boss ? tokens.coral : tokens.mint;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          // 0 -> 12% fade in, hold to 70%, then fade out.
          final opacity = t < 0.12
              ? (t / 0.12)
              : t < 0.70
              ? 1.0
              : (1 - (t - 0.70) / 0.30).clamp(0.0, 1.0);
          // The card settles from a slight rise, like the original transform.
          final rise =
              (1 - Curves.easeOutCubic.transform((t / 0.25).clamp(0, 1))) * 26;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.58 * opacity),
              alignment: Alignment.center,
              child: Transform.translate(offset: Offset(0, rise), child: child),
            ),
          );
        },
        child: Transform(
          transform: Matrix4.skewX(-0.05),
          alignment: Alignment.center,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: 0.76),
                width: 2,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF5140830), Color(0xF5050C18)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 46,
                ),
                const BoxShadow(
                  color: Color(0xBF000000),
                  blurRadius: 70,
                  offset: Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.kicker,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'Bungee',
                    fontSize: 11,
                    letterSpacing: 2.4,
                    shadows: wildcardTextOutline,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.cream,
                    fontFamily: 'Bungee',
                    fontSize: 34,
                    height: 1,
                    letterSpacing: 1.1,
                    shadows: wildcardTextOutline,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.creamDim,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

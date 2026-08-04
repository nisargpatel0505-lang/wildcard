import 'dart:async';

import 'package:flutter/material.dart';

import 'sly_sprite.dart';

/// The WebView's `playSlyStageFX`: Sly steps on stage to deal a new Heat and
/// to celebrate a cleared one. The stage sprite atlas shipped with the port
/// but was never instantiated, so both moments played to an empty room.
///
/// Timings mirror the original: the deal beat holds 2500ms with the A→B frame
/// swap at 620ms; victory holds 1700ms and swaps at 520ms. Reduced motion pins
/// the settled B frame with no slide.
class SlyStageFxOverlay extends StatefulWidget {
  const SlyStageFxOverlay.deal({
    this.skin = SlySkin.classic,
    this.onFinished,
    super.key,
  }) : deal = true;
  const SlyStageFxOverlay.victory({
    this.skin = SlySkin.classic,
    this.onFinished,
    super.key,
  }) : deal = false;

  /// `true` for the deal intro, `false` for the victory celebration.
  final bool deal;
  final SlySkin skin;
  final VoidCallback? onFinished;

  @override
  State<SlyStageFxOverlay> createState() => _SlyStageFxOverlayState();
}

class _SlyStageFxOverlayState extends State<SlyStageFxOverlay>
    with SingleTickerProviderStateMixin {
  // The victory cheer now plays centre stage at nearly twice the size, so it
  // gets longer than the WebView's 1700ms to land, be seen and leave.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.deal ? 2500 : 2300),
  );
  Timer? _swap;
  bool _secondFrame = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onFinished?.call();
    });
    _swap = Timer(Duration(milliseconds: widget.deal ? 620 : 520), () {
      if (mounted) setState(() => _secondFrame = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled && !_secondFrame) {
      _swap?.cancel();
      _secondFrame = true;
    }
  }

  @override
  void dispose() {
    _swap?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pose = widget.deal
        ? (_secondFrame ? SlyStagePose.dealFinish : SlyStagePose.dealStart)
        : (_secondFrame
              ? SlyStagePose.victoryFinish
              : SlyStagePose.victoryStart);
    final screen = MediaQuery.sizeOf(context);
    // The cheer is the reward beat for clearing a Heat, so it plays large and
    // centre stage. Dealing stays lower and smaller: it introduces the table
    // rather than interrupting it, and must not cover the Heat intro card.
    final size = widget.deal
        ? (screen.width * 0.52).clamp(150.0, 230.0)
        : (screen.width * 0.78).clamp(240.0, 400.0);
    return IgnorePointer(
      child: Align(
        alignment: widget.deal
            ? Alignment.bottomCenter
            // Slightly above true centre so he reads against the shop panels
            // instead of sitting on the buttons.
            : const Alignment(0, -0.12),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            // Rise in over the first 18%, hold, fall away over the last 18%.
            final enter = Curves.easeOutCubic.transform(
              (t / 0.18).clamp(0.0, 1.0),
            );
            final exit = Curves.easeInCubic.transform(
              ((t - 0.82) / 0.18).clamp(0.0, 1.0),
            );
            // The cheer travels further and lands with a small overshoot, so
            // it feels like he leaps up rather than slides on.
            final travel = widget.deal ? size * 0.55 : size * 0.75;
            final rise = disabled ? 0.0 : (1 - enter) * travel;
            final drop = disabled ? 0.0 : exit * travel * 1.1;
            final pop = widget.deal || disabled
                ? 1.0
                : 0.86 + 0.14 * Curves.easeOutBack.transform(enter);
            return Opacity(
              opacity: (enter * (1 - exit)).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, rise + drop),
                child: Transform.scale(scale: pop, child: child),
              ),
            );
          },
          child: SlyStageSprite(pose: pose, skin: widget.skin, size: size),
        ),
      ),
    );
  }
}

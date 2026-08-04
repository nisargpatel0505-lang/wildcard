import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Drives a value toward [target] with a real spring simulation.
///
/// Unlike an `AnimatedFoo` (fixed duration + canned curve), this overshoots,
/// settles, and — crucially — is interruptible: retargeting mid-flight carries
/// the current velocity, so motion feels physical instead of mechanical. This
/// is the thing that makes native motion feel better than a CSS transition,
/// and it is what the first port was missing.
class SpringValue extends StatefulWidget {
  const SpringValue({
    required this.target,
    required this.builder,
    this.stiffness = 360,
    this.damping = 0.62,
    this.child,
    super.key,
  });

  final double target;

  /// Higher = snappier. Lower = looser.
  final double stiffness;

  /// Damping ratio: <1 overshoots (bouncy), 1 settles without overshoot.
  final double damping;

  final Widget Function(BuildContext context, double value, Widget? child)
  builder;
  final Widget? child;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.target,
  );
  bool _motion = true;

  void _drive() {
    _c.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: widget.stiffness,
          ratio: widget.damping,
        ),
        _c.value,
        widget.target,
        _c.velocity,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _motion = !disabled;
    if (!_motion) _c.value = widget.target;
  }

  @override
  void didUpdateWidget(covariant SpringValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      if (_motion) {
        _drive();
      } else {
        _c.value = widget.target;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _c.value, child),
  );
}

/// A tactile press-squish for any tappable surface: springs down while held,
/// springs back with a little overshoot on release. Passive — it never
/// consumes the tap, so an [InkWell] inside still handles the action and ripple.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.955,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: widget.enabled ? (_) => _set(false) : null,
      onPointerCancel: widget.enabled ? (_) => _set(false) : null,
      child: SpringValue(
        target: _down ? widget.pressedScale : 1,
        stiffness: 520,
        damping: 0.5,
        child: widget.child,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
      ),
    );
  }
}

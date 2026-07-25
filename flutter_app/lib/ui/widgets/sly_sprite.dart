import 'package:flutter/material.dart';

enum SlyExpression {
  idle,
  impressed,
  laughing,
  scared,
  angry,
  shocked,
  thoughtful,
  triumphant,
  disappointed,
}

enum SlySkin { classic, gold, shadow, robot, king, alien, devil, clown }

enum SlyStagePose { dealStart, dealFinish, victoryStart, victoryFinish }

/// Crops a single frame from the recovered Sly sprite atlases without decoding
/// or copying separate bitmap files for each expression.
///
/// The original WebView build gave Sly a continuous `slyIdle` bob plus a small
/// kick whenever his expression changed. The first port rendered him as a fully
/// static frame, which is why he stopped feeling alive. Both motions are
/// restored here as compositor-only transforms (translate/rotate/scale), so
/// they cost no layout or repaint of the sprite itself.
class SlySprite extends StatefulWidget {
  const SlySprite({
    this.expression = SlyExpression.idle,
    this.skin = SlySkin.classic,
    this.size = 96,
    this.borderRadius = 18,
    this.semanticLabel = 'Sly, your dealer',
    this.animate = true,
    super.key,
  });

  final SlyExpression expression;
  final SlySkin skin;
  final double size;
  final double borderRadius;
  final String semanticLabel;

  /// Allows tests and reduced-motion contexts to pin a static frame.
  final bool animate;

  @override
  State<SlySprite> createState() => _SlySpriteState();
}

class _SlySpriteState extends State<SlySprite> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final AnimationController _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  bool _motionAllowed = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform "remove animations" setting by actually stopping the
    // ticker, not just flattening the transform. A perpetually running
    // controller also never lets a widget test settle.
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _motionAllowed = widget.animate && !disabled;
    _syncIdle();
  }

  void _syncIdle() {
    if (_motionAllowed) {
      if (!_idle.isAnimating) _idle.repeat(reverse: true);
    } else if (_idle.isAnimating) {
      _idle.stop();
    }
  }

  @override
  void didUpdateWidget(covariant SlySprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _motionAllowed = widget.animate && !disabled;
    // A new expression should visibly land, the way the old build popped.
    if (_motionAllowed && oldWidget.expression != widget.expression) {
      _react.forward(from: 0);
    }
    _syncIdle();
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClassic = widget.skin == SlySkin.classic;
    final frame = isClassic ? widget.expression.index : widget.skin.index;
    final columns = isClassic ? 3 : 4;
    final rows = isClassic ? 3 : 2;
    final column = frame % columns;
    final row = frame ~/ columns;
    final sprite = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: _SpriteFrame(
        asset: isClassic
            ? 'assets/art/sly/sly-expression-grid.webp'
            : 'assets/art/sly/sly-skins-grid.webp',
        columns: columns,
        rows: rows,
        column: column,
        row: row,
        width: widget.size,
        height: widget.size,
      ),
    );

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: !_motionAllowed
          ? sprite
          : RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_idle, _react]),
                child: sprite,
                builder: (context, child) {
                  // Gentle breathing bob, mirroring the old CSS keyframes.
                  final t = Curves.easeInOut.transform(_idle.value);
                  final lift = -2.2 * t;
                  final tilt = (-0.012 + 0.024 * t);
                  // Expression change lands with a short overshoot.
                  final kick = 1 - Curves.easeOutBack.transform(_react.value);
                  return Transform.translate(
                    offset: Offset(0, lift - 4 * kick),
                    child: Transform.rotate(
                      angle: tilt,
                      child: Transform.scale(
                        scale: 1 + 0.06 * kick,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class SlyStageSprite extends StatelessWidget {
  const SlyStageSprite({required this.pose, this.size = 260, super.key});

  final SlyStagePose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index = pose.index;
    return ExcludeSemantics(
      child: _SpriteFrame(
        asset: 'assets/art/sly/sly-stage-actions-grid.webp',
        columns: 2,
        rows: 2,
        column: index % 2,
        row: index ~/ 2,
        width: size,
        height: size,
      ),
    );
  }
}

class _SpriteFrame extends StatelessWidget {
  const _SpriteFrame({
    required this.asset,
    required this.columns,
    required this.rows,
    required this.column,
    required this.row,
    required this.width,
    required this.height,
  });

  final String asset;
  final int columns;
  final int rows;
  final int column;
  final int row;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    assert(column >= 0 && column < columns);
    assert(row >= 0 && row < rows);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * columns * devicePixelRatio).ceil();
    final cacheHeight = (height * rows * devicePixelRatio).ceil();
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width * columns,
          maxWidth: width * columns,
          minHeight: height * rows,
          maxHeight: height * rows,
          child: Transform.translate(
            offset: Offset(-column * width, -row * height),
            child: Image.asset(
              asset,
              width: width * columns,
              height: height * rows,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
            ),
          ),
        ),
      ),
    );
  }
}

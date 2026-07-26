import 'dart:math' as math;

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

enum SlySkin {
  classic,
  gold,
  shadow,
  robot,
  king,
  alien,
  devil,
  clown,
  blockDrop,
  abyssal,
  desertMirage,
}

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
    this.reactionActive = false,
    this.size = 96,
    this.borderRadius = 18,
    this.semanticLabel = 'Sly, your dealer',
    this.animate = true,
    super.key,
  });

  final SlyExpression expression;
  final SlySkin skin;

  /// Legacy premium Sly cosmetics are single-frame portraits. They stay
  /// equipped during reactions and use character motion plus mood-specific
  /// accents. Classic and the three new themed looks use complete nine-frame
  /// facial-expression atlases.
  final bool reactionActive;

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
    if (_motionAllowed &&
        (oldWidget.expression != widget.expression ||
            oldWidget.skin != widget.skin ||
            oldWidget.reactionActive != widget.reactionActive)) {
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
    final themedExpressionAsset = slyExpressionAssetForSkin(widget.skin);
    final hasExpressionAtlas = isClassic || themedExpressionAsset != null;
    final frame = hasExpressionAtlas
        ? slyExpressionFrameIndex(widget.expression)
        : widget.skin.index;
    final columns = hasExpressionAtlas ? 3 : 4;
    final rows = hasExpressionAtlas ? 3 : 2;
    final column = frame % columns;
    final row = frame ~/ columns;
    final asset =
        themedExpressionAsset ??
        (isClassic ? slyExpressionSpriteAsset : slySkinSpriteAsset);
    final frameKey = isClassic
        ? ValueKey('sly-expression-frame-${widget.expression.name}')
        : hasExpressionAtlas
        ? ValueKey(
            'sly-themed-expression-frame-'
            '${widget.skin.name}-${widget.expression.name}',
          )
        : ValueKey('sly-skin-frame-${widget.skin.name}');
    final premiumReaction =
        !hasExpressionAtlas &&
        widget.reactionActive &&
        widget.expression != SlyExpression.idle;
    final sprite = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: _motionAllowed
                ? const Duration(milliseconds: 120)
                : Duration.zero,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [...previousChildren, ?currentChild],
            ),
            child: ClipRRect(
              key: frameKey,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: _SpriteFrame(
                asset: asset,
                columns: columns,
                rows: rows,
                column: column,
                row: row,
                width: widget.size,
                height: widget.size,
              ),
            ),
          ),
          if (premiumReaction)
            IgnorePointer(
              child: CustomPaint(
                key: ValueKey('sly-premium-reaction-${widget.expression.name}'),
                painter: _PremiumReactionPainter(widget.expression),
              ),
            ),
        ],
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
                  var lift = -2.2 * t;
                  var slide = 0.0;
                  var tilt = (-0.012 + 0.024 * t);
                  // Expression change lands with a short overshoot.
                  final kick = 1 - Curves.easeOutBack.transform(_react.value);
                  var scaleX = 1 + 0.06 * kick;
                  var scaleY = scaleX;
                  if (premiumReaction) {
                    final shake =
                        math.sin(_react.value * math.pi * 5) *
                        (1 - _react.value);
                    switch (widget.expression) {
                      case SlyExpression.impressed:
                        lift -= 4 * kick;
                        scaleX += 0.04 * kick;
                        scaleY += 0.04 * kick;
                      case SlyExpression.laughing:
                        tilt += 0.075 * shake;
                        scaleY += 0.045 * kick;
                      case SlyExpression.scared:
                        slide += 4.4 * shake;
                        scaleX -= 0.035 * kick;
                        scaleY += 0.065 * kick;
                      case SlyExpression.angry:
                        lift += 1.5 * kick;
                        scaleX += 0.075 * kick;
                        scaleY -= 0.025 * kick;
                        tilt -= 0.025 * kick;
                      case SlyExpression.shocked:
                        lift -= 5 * kick;
                        scaleX += 0.095 * kick;
                        scaleY += 0.095 * kick;
                      case SlyExpression.thoughtful:
                        slide -= 1.5 * kick;
                        tilt -= 0.055 * kick;
                      case SlyExpression.triumphant:
                        lift -= 7 * kick;
                        scaleX += 0.075 * kick;
                        scaleY += 0.075 * kick;
                      case SlyExpression.disappointed:
                        lift += 4 * kick;
                        scaleX -= 0.035 * kick;
                        scaleY -= 0.055 * kick;
                      case SlyExpression.idle:
                        break;
                    }
                  }
                  return Transform.translate(
                    offset: Offset(slide, lift - 4 * kick),
                    child: Transform.rotate(
                      angle: tilt,
                      child: Transform.scale(
                        scaleX: scaleX,
                        scaleY: scaleY,
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

/// Premium skins only have one authored frame each. This painter makes that
/// equipped portrait read clearly as impressed, angry, shocked, and so on
/// without replacing it with the Classic artwork. It deliberately uses simple
/// strokes and fills so reactions remain cheap on the raster thread.
class _PremiumReactionPainter extends CustomPainter {
  const _PremiumReactionPainter(this.expression);

  final SlyExpression expression;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _reactionColor(expression);
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.shortestSide * 0.025)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.shortestSide * 0.16),
      ).deflate(stroke.strokeWidth / 2),
      Paint()
        ..color = color.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth,
    );

    switch (expression) {
      case SlyExpression.impressed:
        _drawSpark(
          canvas,
          Offset(size.width * 0.18, size.height * 0.21),
          7,
          fill,
        );
        _drawSpark(
          canvas,
          Offset(size.width * 0.82, size.height * 0.29),
          5,
          fill,
        );
      case SlyExpression.laughing:
        _drawTear(
          canvas,
          Offset(size.width * 0.36, size.height * 0.49),
          size.shortestSide * 0.07,
          fill,
        );
        _drawTear(
          canvas,
          Offset(size.width * 0.69, size.height * 0.49),
          size.shortestSide * 0.07,
          fill,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.52, size.height * 0.57),
            width: size.width * 0.32,
            height: size.height * 0.25,
          ),
          0.12,
          math.pi - 0.24,
          false,
          stroke,
        );
      case SlyExpression.scared:
        _drawTear(
          canvas,
          Offset(size.width * 0.79, size.height * 0.24),
          size.shortestSide * 0.11,
          fill,
        );
        for (var i = 0; i < 3; i++) {
          final y = size.height * (0.38 + i * 0.12);
          canvas.drawLine(
            Offset(size.width * 0.08, y),
            Offset(size.width * (0.17 + i * 0.015), y),
            stroke,
          );
        }
      case SlyExpression.angry:
        _drawAngerMark(
          canvas,
          Offset(size.width * 0.77, size.height * 0.22),
          size.shortestSide * 0.105,
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.31, size.height * 0.36),
          Offset(size.width * 0.44, size.height * 0.4),
          stroke,
        );
        canvas.drawLine(
          Offset(size.width * 0.7, size.height * 0.36),
          Offset(size.width * 0.57, size.height * 0.4),
          stroke,
        );
      case SlyExpression.shocked:
        final center = Offset(size.width * 0.51, size.height * 0.45);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final inner = size.shortestSide * 0.36;
          final outer = size.shortestSide * 0.44;
          canvas.drawLine(
            center + Offset(math.cos(angle), math.sin(angle)) * inner,
            center + Offset(math.cos(angle), math.sin(angle)) * outer,
            stroke,
          );
        }
        canvas.drawCircle(center, size.shortestSide * 0.32, stroke);
      case SlyExpression.thoughtful:
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(
              size.width * (0.73 + i * 0.075),
              size.height * (0.33 - i * 0.085),
            ),
            size.shortestSide * (0.024 + i * 0.008),
            fill,
          );
        }
      case SlyExpression.triumphant:
        _drawSpark(
          canvas,
          Offset(size.width * 0.18, size.height * 0.2),
          7,
          fill,
        );
        _drawSpark(
          canvas,
          Offset(size.width * 0.82, size.height * 0.2),
          7,
          fill,
        );
        _drawSpark(
          canvas,
          Offset(size.width * 0.51, size.height * 0.11),
          5,
          fill,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.51, size.height * 0.47),
            width: size.width * 0.7,
            height: size.height * 0.68,
          ),
          math.pi * 1.12,
          math.pi * 0.76,
          false,
          stroke,
        );
      case SlyExpression.disappointed:
        for (var i = 0; i < 3; i++) {
          final x = size.width * (0.23 + i * 0.27);
          canvas.drawLine(
            Offset(x, size.height * 0.15),
            Offset(x - size.width * 0.04, size.height * 0.27),
            stroke,
          );
        }
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(size.width * 0.51, size.height * 0.7),
            width: size.width * 0.3,
            height: size.height * 0.2,
          ),
          math.pi * 1.12,
          math.pi * 0.76,
          false,
          stroke,
        );
      case SlyExpression.idle:
        break;
    }
  }

  static Color _reactionColor(SlyExpression expression) => switch (expression) {
    SlyExpression.impressed ||
    SlyExpression.triumphant => const Color(0xFFFFC857),
    SlyExpression.laughing => const Color(0xFF59F1D7),
    SlyExpression.scared ||
    SlyExpression.disappointed => const Color(0xFF72B7FF),
    SlyExpression.angry => const Color(0xFFFF625D),
    SlyExpression.shocked => const Color(0xFFF9F1FF),
    SlyExpression.thoughtful => const Color(0xFFB788FF),
    SlyExpression.idle => Colors.transparent,
  };

  static void _drawSpark(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.28, center.dy - radius * 0.28)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.28, center.dy - radius * 0.28)
      ..close();
    canvas.drawPath(path, paint);
  }

  static void _drawTear(Canvas canvas, Offset top, double radius, Paint paint) {
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(
        top.dx + radius,
        top.dy + radius,
        top.dx,
        top.dy + radius * 1.8,
      )
      ..quadraticBezierTo(top.dx - radius, top.dy + radius, top.dx, top.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  static void _drawAngerMark(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx - radius * 0.25, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.25, center.dy),
      Offset(center.dx - radius * 0.25, center.dy - radius),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius, center.dy),
      Offset(center.dx + radius * 0.25, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.25, center.dy),
      Offset(center.dx + radius * 0.25, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumReactionPainter oldDelegate) =>
      oldDelegate.expression != expression;
}

const String slyExpressionSpriteAsset =
    'assets/art/sly/sly-expression-grid.webp';
const String slySkinSpriteAsset = 'assets/art/sly/sly-skins-grid.webp';
const String slyBlockDropExpressionSpriteAsset =
    'assets/art/sly/sly-block-drop-expression-grid.webp';
const String slyAbyssalExpressionSpriteAsset =
    'assets/art/sly/sly-abyssal-expression-grid.webp';
const String slyDesertExpressionSpriteAsset =
    'assets/art/sly/sly-desert-expression-grid.webp';

String? slyExpressionAssetForSkin(SlySkin skin) => switch (skin) {
  SlySkin.blockDrop => slyBlockDropExpressionSpriteAsset,
  SlySkin.abyssal => slyAbyssalExpressionSpriteAsset,
  SlySkin.desertMirage => slyDesertExpressionSpriteAsset,
  _ => null,
};

/// The atlas is deliberately mapped by name rather than enum ordinal so adding
/// a future expression cannot silently point every later mood at the wrong
/// face.
int slyExpressionFrameIndex(SlyExpression expression) => switch (expression) {
  SlyExpression.idle => 0,
  SlyExpression.impressed => 1,
  SlyExpression.laughing => 2,
  SlyExpression.scared => 3,
  SlyExpression.angry => 4,
  SlyExpression.shocked => 5,
  SlyExpression.thoughtful => 6,
  SlyExpression.triumphant => 7,
  SlyExpression.disappointed => 8,
};

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

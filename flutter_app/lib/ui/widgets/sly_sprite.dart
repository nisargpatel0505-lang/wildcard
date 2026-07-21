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
class SlySprite extends StatelessWidget {
  const SlySprite({
    this.expression = SlyExpression.idle,
    this.skin = SlySkin.classic,
    this.size = 96,
    this.borderRadius = 18,
    this.semanticLabel = 'Sly, your dealer',
    super.key,
  });

  final SlyExpression expression;
  final SlySkin skin;
  final double size;
  final double borderRadius;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isClassic = skin == SlySkin.classic;
    final frame = isClassic ? expression.index : skin.index;
    final columns = isClassic ? 3 : 4;
    final rows = isClassic ? 3 : 2;
    final column = frame % columns;
    final row = frame ~/ columns;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _SpriteFrame(
          asset: isClassic
              ? 'assets/art/sly/sly-expression-grid.webp'
              : 'assets/art/sly/sly-skins-grid.webp',
          columns: columns,
          rows: rows,
          column: column,
          row: row,
          width: size,
          height: size,
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

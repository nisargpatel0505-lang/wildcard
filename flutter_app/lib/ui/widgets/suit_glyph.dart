import 'package:flutter/material.dart';

import '../../domain/cards.dart';

/// A deterministic playing-card suit drawn from simple vector geometry.
///
/// Neither Bungee nor Space Grotesk contains the four suit code points, so a
/// text glyph silently falls back to a device font. Drawing the marks here
/// keeps their shape, weight and alignment identical on every Android device.
class SuitGlyph extends StatelessWidget {
  const SuitGlyph({
    required this.suit,
    required this.color,
    required this.size,
    super.key,
  });

  final CardSuit suit;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SuitGlyphPainter(suit: suit, color: color),
      ),
    );
  }
}

class _SuitGlyphPainter extends CustomPainter {
  const _SuitGlyphPainter({required this.suit, required this.color});

  final CardSuit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    final scale = size.shortestSide;
    final offset = Offset((size.width - scale) / 2, (size.height - scale) / 2);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);

    switch (suit) {
      case CardSuit.hearts:
        canvas.drawPath(_heartPath(), paint);
      case CardSuit.diamonds:
        canvas.drawPath(_diamondPath(), paint);
      case CardSuit.spades:
        canvas.drawPath(_spadePath(), paint);
      case CardSuit.clubs:
        _paintClub(canvas, paint);
    }

    canvas.restore();
  }

  Path _heartPath() => Path()
    ..moveTo(0.5, 0.94)
    ..cubicTo(0.43, 0.82, 0.12, 0.62, 0.12, 0.34)
    ..cubicTo(0.12, 0.15, 0.25, 0.06, 0.39, 0.08)
    ..cubicTo(0.45, 0.09, 0.49, 0.14, 0.5, 0.2)
    ..cubicTo(0.51, 0.14, 0.55, 0.09, 0.61, 0.08)
    ..cubicTo(0.75, 0.06, 0.88, 0.15, 0.88, 0.34)
    ..cubicTo(0.88, 0.62, 0.57, 0.82, 0.5, 0.94)
    ..close();

  Path _diamondPath() => Path()
    ..moveTo(0.5, 0.04)
    ..lineTo(0.9, 0.5)
    ..lineTo(0.5, 0.96)
    ..lineTo(0.1, 0.5)
    ..close();

  Path _spadePath() => Path()
    ..moveTo(0.5, 0.03)
    ..cubicTo(0.43, 0.18, 0.1, 0.39, 0.1, 0.62)
    ..cubicTo(0.1, 0.8, 0.25, 0.89, 0.42, 0.78)
    ..cubicTo(0.42, 0.86, 0.38, 0.92, 0.3, 0.97)
    ..lineTo(0.7, 0.97)
    ..cubicTo(0.62, 0.92, 0.58, 0.86, 0.58, 0.78)
    ..cubicTo(0.75, 0.89, 0.9, 0.8, 0.9, 0.62)
    ..cubicTo(0.9, 0.39, 0.57, 0.18, 0.5, 0.03)
    ..close();

  void _paintClub(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(0.5, 0.27), 0.22, paint);
    canvas.drawCircle(const Offset(0.28, 0.52), 0.22, paint);
    canvas.drawCircle(const Offset(0.72, 0.52), 0.22, paint);
    canvas.drawCircle(const Offset(0.5, 0.52), 0.2, paint);
    canvas.drawPath(
      Path()
        ..moveTo(0.44, 0.54)
        ..cubicTo(0.45, 0.72, 0.43, 0.87, 0.31, 0.96)
        ..lineTo(0.69, 0.96)
        ..cubicTo(0.57, 0.87, 0.55, 0.72, 0.56, 0.54)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SuitGlyphPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

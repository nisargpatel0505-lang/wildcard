import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// Static, paint-only table treatments for the ten collectible felts.
///
/// The painter deliberately uses a small, fixed number of paths and is wrapped
/// in a [RepaintBoundary]. It therefore changes the table's identity without
/// adding images, animation controllers, blur filters or scoring-time work.
enum TableFeltPattern {
  weave,
  grid,
  royal,
  horizon,
  scales,
  waves,
  pinstripe,
  stars,
  circuit,
  petals,
}

@immutable
class TableFeltVisual {
  const TableFeltVisual({
    required this.id,
    required this.primary,
    required this.secondary,
    required this.trim,
    required this.pattern,
  });

  final String id;
  final Color primary;
  final Color secondary;
  final Color trim;
  final TableFeltPattern pattern;
}

const Map<String, TableFeltVisual> tableFeltVisuals = <String, TableFeltVisual>{
  'felt_classic': TableFeltVisual(
    id: 'felt_classic',
    primary: Color(0xFF12372D),
    secondary: Color(0xFF0A211B),
    trim: Color(0xFF45E0C6),
    pattern: TableFeltPattern.weave,
  ),
  'felt_neon': TableFeltVisual(
    id: 'felt_neon',
    primary: Color(0xFF102C43),
    secondary: Color(0xFF080D25),
    trim: Color(0xFF3FF3FF),
    pattern: TableFeltPattern.grid,
  ),
  'felt_royal': TableFeltVisual(
    id: 'felt_royal',
    primary: Color(0xFF5B1828),
    secondary: Color(0xFF260812),
    trim: Color(0xFFF0B94B),
    pattern: TableFeltPattern.royal,
  ),
  'felt_void': TableFeltVisual(
    id: 'felt_void',
    primary: Color(0xFF150A2B),
    secondary: Color(0xFF010208),
    trim: Color(0xFF9B7BFF),
    pattern: TableFeltPattern.horizon,
  ),
  'felt_jade': TableFeltVisual(
    id: 'felt_jade',
    primary: Color(0xFF0B553E),
    secondary: Color(0xFF05261D),
    trim: Color(0xFFE2C768),
    pattern: TableFeltPattern.scales,
  ),
  'felt_ocean': TableFeltVisual(
    id: 'felt_ocean',
    primary: Color(0xFF0A4663),
    secondary: Color(0xFF06182E),
    trim: Color(0xFF62DDF7),
    pattern: TableFeltPattern.waves,
  ),
  'felt_crimson': TableFeltVisual(
    id: 'felt_crimson',
    primary: Color(0xFF76182B),
    secondary: Color(0xFF300812),
    trim: Color(0xFFF4CA64),
    pattern: TableFeltPattern.pinstripe,
  ),
  'felt_galaxy': TableFeltVisual(
    id: 'felt_galaxy',
    primary: Color(0xFF2B0D62),
    secondary: Color(0xFF09031E),
    trim: Color(0xFFC990FF),
    pattern: TableFeltPattern.stars,
  ),
  'felt_circuit': TableFeltVisual(
    id: 'felt_circuit',
    primary: Color(0xFF123F30),
    secondary: Color(0xFF061A13),
    trim: Color(0xFF53F5A8),
    pattern: TableFeltPattern.circuit,
  ),
  'felt_sakura': TableFeltVisual(
    id: 'felt_sakura',
    primary: Color(0xFF6A3153),
    secondary: Color(0xFF251025),
    trim: Color(0xFFFFA5D6),
    pattern: TableFeltPattern.petals,
  ),
};

TableFeltVisual resolveTableFeltVisual(String id) =>
    tableFeltVisuals[id] ?? tableFeltVisuals['felt_classic']!;

class TableFeltSurface extends StatelessWidget {
  const TableFeltSurface({
    required this.feltId,
    required this.child,
    this.width,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
    super.key,
  });

  final String feltId;
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final visual = resolveTableFeltVisual(feltId);
    final tokens = context.wildcard;
    final trim = Color.lerp(visual.trim, tokens.violet, 0.18)!;
    return SizedBox(
      width: width,
      child: RepaintBoundary(
        key: ValueKey('table-felt-${visual.id}'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[visual.primary, visual.secondary],
            ),
            borderRadius: borderRadius,
            border: Border.all(color: trim, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x70000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: CustomPaint(
              painter: _TableFeltPainter(visual),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableFeltPainter extends CustomPainter {
  const _TableFeltPainter(this.visual);

  final TableFeltVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = visual.trim.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final soft = Paint()
      ..color = visual.trim.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    switch (visual.pattern) {
      case TableFeltPattern.weave:
        for (double x = -size.height; x < size.width; x += 22) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            line,
          );
        }
        for (double x = 0; x < size.width + size.height; x += 34) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x - size.height, size.height),
            line,
          );
        }
      case TableFeltPattern.grid:
        for (double x = 18; x < size.width; x += 24) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
        for (double y = 18; y < size.height; y += 24) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
      case TableFeltPattern.royal:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
            const Radius.circular(12),
          ),
          line..strokeWidth = 1.5,
        );
        final center = size.center(Offset.zero);
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 34)
            ..lineTo(center.dx + 58, center.dy)
            ..lineTo(center.dx, center.dy + 34)
            ..lineTo(center.dx - 58, center.dy)
            ..close(),
          line,
        );
      case TableFeltPattern.horizon:
        final center = Offset(size.width / 2, size.height * 0.58);
        for (var index = 1; index <= 4; index++) {
          final width = size.width * index / 4;
          canvas.drawOval(
            Rect.fromCenter(center: center, width: width, height: 18.0 * index),
            line,
          );
        }
      case TableFeltPattern.scales:
        for (double y = 12; y < size.height; y += 20) {
          final row = (y / 20).floor();
          for (double x = row.isEven ? 0 : 14; x < size.width; x += 28) {
            canvas.drawArc(
              Rect.fromCenter(center: Offset(x, y), width: 28, height: 20),
              0,
              math.pi,
              false,
              line,
            );
          }
        }
      case TableFeltPattern.waves:
        for (var row = 0; row < 6; row++) {
          final y = 18.0 + row * 30;
          final path = Path()..moveTo(0, y);
          for (double x = 0; x < size.width; x += 48) {
            path.quadraticBezierTo(x + 12, y - 8, x + 24, y);
            path.quadraticBezierTo(x + 36, y + 8, x + 48, y);
          }
          canvas.drawPath(path, line);
        }
      case TableFeltPattern.pinstripe:
        for (double x = -size.height; x < size.width; x += 27) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            line,
          );
        }
      case TableFeltPattern.stars:
        const stars = <Offset>[
          Offset(0.08, 0.18),
          Offset(0.19, 0.72),
          Offset(0.31, 0.35),
          Offset(0.43, 0.84),
          Offset(0.55, 0.17),
          Offset(0.68, 0.59),
          Offset(0.79, 0.29),
          Offset(0.91, 0.77),
          Offset(0.48, 0.52),
          Offset(0.86, 0.10),
        ];
        for (var index = 0; index < stars.length; index++) {
          canvas.drawCircle(
            Offset(stars[index].dx * size.width, stars[index].dy * size.height),
            index.isEven ? 1.8 : 1.1,
            soft,
          );
        }
      case TableFeltPattern.circuit:
        for (double y = 18; y < size.height; y += 30) {
          final path = Path()
            ..moveTo(0, y)
            ..lineTo(size.width * 0.28, y)
            ..lineTo(size.width * 0.34, y + 9)
            ..lineTo(size.width * 0.72, y + 9)
            ..lineTo(size.width * 0.78, y)
            ..lineTo(size.width, y);
          canvas.drawPath(path, line);
          canvas.drawCircle(Offset(size.width * 0.34, y + 9), 2.2, soft);
          canvas.drawCircle(Offset(size.width * 0.72, y + 9), 2.2, soft);
        }
      case TableFeltPattern.petals:
        const petals = <Offset>[
          Offset(0.12, 0.22),
          Offset(0.28, 0.70),
          Offset(0.48, 0.30),
          Offset(0.66, 0.76),
          Offset(0.84, 0.24),
          Offset(0.91, 0.60),
        ];
        for (final petal in petals) {
          final center = Offset(petal.dx * size.width, petal.dy * size.height);
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate((petal.dx + petal.dy) * math.pi);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 10, height: 5),
            soft,
          );
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(covariant _TableFeltPainter oldDelegate) =>
      oldDelegate.visual != visual;
}

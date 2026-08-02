import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../wildcard_theme.dart';
import 'suit_glyph.dart';

/// Static table treatments for the collectible felts.
///
/// Procedural treatments use batched paths, while the premium texture
/// treatments use cached, repeating assets. The complete surface is wrapped in
/// a [RepaintBoundary], so changing its identity adds no scoring-time work.
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
  herringbone,
  artDecoSunburst,
  honeycomb,
  tartan,
  circuitBoardV2,
  nebula,
  imageTexture,
}

/// How an image-based felt is composed inside the responsive play surface.
///
/// Most premium felts are seamless material tiles. Kingdom felts are authored
/// as one complete surface, so repeating them would duplicate their border and
/// crest whenever the playfield changes size.
enum TableTextureLayout { repeatingTile, coverOnce }

@immutable
class TableFeltVisual {
  const TableFeltVisual({
    required this.id,
    required this.primary,
    required this.secondary,
    required this.trim,
    required this.pattern,
    this.assetPath,
    this.textureLayout = TableTextureLayout.repeatingTile,
    this.watermarkSuit,
  });

  final String id;
  final Color primary;
  final Color secondary;
  final Color trim;
  final TableFeltPattern pattern;
  final String? assetPath;
  final TableTextureLayout textureLayout;
  final CardSuit? watermarkSuit;

  bool get isImageBased => assetPath != null;
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
  'felt_herringbone': TableFeltVisual(
    id: 'felt_herringbone',
    primary: Color(0xFF242631),
    secondary: Color(0xFF0B0D14),
    trim: Color(0xFFC9A85B),
    pattern: TableFeltPattern.herringbone,
  ),
  'felt_art_deco': TableFeltVisual(
    id: 'felt_art_deco',
    primary: Color(0xFF132747),
    secondary: Color(0xFF070D1D),
    trim: Color(0xFFF2C45D),
    pattern: TableFeltPattern.artDecoSunburst,
  ),
  'felt_honeycomb': TableFeltVisual(
    id: 'felt_honeycomb',
    primary: Color(0xFF3D173B),
    secondary: Color(0xFF16091C),
    trim: Color(0xFFFFC64E),
    pattern: TableFeltPattern.honeycomb,
  ),
  'felt_tartan': TableFeltVisual(
    id: 'felt_tartan',
    primary: Color(0xFF3B1721),
    secondary: Color(0xFF090F20),
    trim: Color(0xFFD6B76B),
    pattern: TableFeltPattern.tartan,
  ),
  'felt_circuit_v2': TableFeltVisual(
    id: 'felt_circuit_v2',
    primary: Color(0xFF082E31),
    secondary: Color(0xFF031115),
    trim: Color(0xFF62F7DC),
    pattern: TableFeltPattern.circuitBoardV2,
  ),
  'felt_nebula': TableFeltVisual(
    id: 'felt_nebula',
    primary: Color(0xFF251052),
    secondary: Color(0xFF080516),
    trim: Color(0xFFC9A0FF),
    pattern: TableFeltPattern.nebula,
  ),
  // TODO(final AI art): Replace these seamless placeholders with approved
  // 1024px production tiles after edge, contrast and on-device memory QA.
  'felt_midnight_velvet': TableFeltVisual(
    id: 'felt_midnight_velvet',
    primary: Color(0xFF121B38),
    secondary: Color(0xFF040711),
    trim: Color(0xFF8FA9E8),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/midnight_velvet.webp',
  ),
  'felt_emerald_royale': TableFeltVisual(
    id: 'felt_emerald_royale',
    primary: Color(0xFF0B4A36),
    secondary: Color(0xFF03150F),
    trim: Color(0xFFE8C96D),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/emerald_casino_royale.webp',
  ),
  'felt_neon_grid': TableFeltVisual(
    id: 'felt_neon_grid',
    primary: Color(0xFF11103E),
    secondary: Color(0xFF050516),
    trim: Color(0xFF45E8F2),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/neon_grid.webp',
  ),
  'felt_obsidian_marble': TableFeltVisual(
    id: 'felt_obsidian_marble',
    primary: Color(0xFF17151D),
    secondary: Color(0xFF050507),
    trim: Color(0xFFC5A5F0),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/obsidian_marble.webp',
  ),
  'felt_hearts_kingdom': TableFeltVisual(
    id: 'felt_hearts_kingdom',
    primary: Color(0xFF6B1628),
    secondary: Color(0xFF240711),
    trim: Color(0xFFE4A264),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/kingdom_hearts_felt.webp',
    textureLayout: TableTextureLayout.coverOnce,
    watermarkSuit: CardSuit.hearts,
  ),
  'felt_spades_kingdom': TableFeltVisual(
    id: 'felt_spades_kingdom',
    primary: Color(0xFF17263A),
    secondary: Color(0xFF050A12),
    trim: Color(0xFFB7CEE2),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/kingdom_spades_felt.webp',
    textureLayout: TableTextureLayout.coverOnce,
    watermarkSuit: CardSuit.spades,
  ),
  'felt_diamonds_kingdom': TableFeltVisual(
    id: 'felt_diamonds_kingdom',
    primary: Color(0xFF3D2B0A),
    secondary: Color(0xFF100B03),
    trim: Color(0xFFFFD36A),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/kingdom_diamonds_felt.webp',
    textureLayout: TableTextureLayout.coverOnce,
    watermarkSuit: CardSuit.diamonds,
  ),
  'felt_clubs_kingdom': TableFeltVisual(
    id: 'felt_clubs_kingdom',
    primary: Color(0xFF16432F),
    secondary: Color(0xFF06160F),
    trim: Color(0xFFC7AC62),
    pattern: TableFeltPattern.imageTexture,
    assetPath: 'assets/tables/kingdom_clubs_felt.webp',
    textureLayout: TableTextureLayout.coverOnce,
    watermarkSuit: CardSuit.clubs,
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
    final repeatsTexture =
        visual.textureLayout == TableTextureLayout.repeatingTile;
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (visual.assetPath case final assetPath?)
                        Image.asset(
                          assetPath,
                          key: ValueKey('table-felt-texture-${visual.id}'),
                          fit: repeatsTexture ? BoxFit.none : BoxFit.cover,
                          repeat: repeatsTexture
                              ? ImageRepeat.repeat
                              : ImageRepeat.noRepeat,
                          scale: repeatsTexture ? 2 : 1,
                          cacheWidth: repeatsTexture ? 512 : 1024,
                          cacheHeight: repeatsTexture ? 512 : 1024,
                          filterQuality: repeatsTexture
                              ? FilterQuality.low
                              : FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      if (visual.isImageBased)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                visual.primary.withValues(alpha: .12),
                                visual.secondary.withValues(alpha: .42),
                              ],
                            ),
                          ),
                        ),
                      if (visual.watermarkSuit case final suit?)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final dimension = math
                                .min(
                                  constraints.maxWidth * 0.20,
                                  constraints.maxHeight * 0.30,
                                )
                                .clamp(34.0, 78.0)
                                .toDouble();
                            return Center(
                              child: IgnorePointer(
                                child: SuitGlyph(
                                  suit: suit,
                                  color: visual.trim.withValues(alpha: 0.09),
                                  size: dimension,
                                ),
                              ),
                            );
                          },
                        ),
                      CustomPaint(painter: _TableFeltPainter(visual)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: child),
          ),
        ],
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
      case TableFeltPattern.herringbone:
        const unit = 24.0;
        final path = Path();
        for (double y = -unit; y < size.height + unit; y += unit) {
          for (double x = -unit; x < size.width + unit; x += unit * 2) {
            final shift = ((y / unit).round()).isEven ? 0.0 : unit;
            path
              ..moveTo(x + shift, y)
              ..lineTo(x + shift + unit, y + unit / 2)
              ..lineTo(x + shift, y + unit)
              ..moveTo(x + shift + unit, y + unit / 2)
              ..lineTo(x + shift + unit * 2, y);
          }
        }
        canvas.drawPath(path, line);
      case TableFeltPattern.artDecoSunburst:
        final origin = Offset(size.width / 2, size.height * .92);
        final rays = Path();
        const rayCount = 14;
        for (var index = 0; index <= rayCount; index++) {
          final x = size.width * index / rayCount;
          rays
            ..moveTo(origin.dx, origin.dy)
            ..lineTo(x, 0);
        }
        for (var index = 1; index <= 4; index++) {
          final inset = index * 12.0;
          rays.addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                inset,
                inset,
                math.max(0, size.width - inset * 2),
                math.max(0, size.height - inset * 2),
              ),
              const Radius.circular(10),
            ),
          );
        }
        canvas.drawPath(rays, line);
      case TableFeltPattern.honeycomb:
        const radius = 15.0;
        final columnStep = radius * 1.5;
        final rowStep = radius * 1.74;
        final cells = Path();
        var column = 0;
        for (double x = -radius; x < size.width + radius; x += columnStep) {
          final rowOffset = column.isEven ? 0.0 : rowStep / 2;
          for (
            double y = -radius + rowOffset;
            y < size.height + radius;
            y += rowStep
          ) {
            cells.moveTo(x + radius, y);
            for (var corner = 1; corner <= 6; corner++) {
              final angle = corner * math.pi / 3;
              cells.lineTo(
                x + math.cos(angle) * radius,
                y + math.sin(angle) * radius,
              );
            }
          }
          column++;
        }
        canvas.drawPath(cells, line);
      case TableFeltPattern.tartan:
        final broadStripes = Path();
        for (double x = 18; x < size.width; x += 78) {
          broadStripes.addRect(Rect.fromLTWH(x, 0, 13, size.height));
        }
        for (double y = 18; y < size.height; y += 78) {
          broadStripes.addRect(Rect.fromLTWH(0, y, size.width, 13));
        }
        canvas.drawPath(
          broadStripes,
          Paint()
            ..color = visual.trim.withValues(alpha: .09)
            ..style = PaintingStyle.fill,
        );
        final fineStripes = Path();
        for (double x = 42; x < size.width; x += 78) {
          fineStripes
            ..moveTo(x, 0)
            ..lineTo(x, size.height)
            ..moveTo(x + 4, 0)
            ..lineTo(x + 4, size.height);
        }
        for (double y = 42; y < size.height; y += 78) {
          fineStripes
            ..moveTo(0, y)
            ..lineTo(size.width, y)
            ..moveTo(0, y + 4)
            ..lineTo(size.width, y + 4);
        }
        canvas.drawPath(fineStripes, line);
      case TableFeltPattern.circuitBoardV2:
        final traces = Path();
        const lanes = 7;
        for (var lane = 0; lane < lanes; lane++) {
          final y = size.height * (lane + 1) / (lanes + 1);
          final direction = lane.isEven ? 1.0 : -1.0;
          traces
            ..moveTo(direction > 0 ? 0 : size.width, y)
            ..lineTo(size.width * .20, y)
            ..lineTo(size.width * .28, y + direction * 11)
            ..lineTo(size.width * .56, y + direction * 11)
            ..lineTo(size.width * .64, y - direction * 7)
            ..lineTo(direction > 0 ? size.width : 0, y - direction * 7);
          canvas.drawCircle(
            Offset(size.width * .28, y + direction * 11),
            2.4,
            soft,
          );
          canvas.drawCircle(
            Offset(size.width * .64, y - direction * 7),
            2.4,
            soft,
          );
        }
        canvas.drawPath(traces, line..strokeWidth = 1.2);
      case TableFeltPattern.nebula:
        const clouds = <(Offset, double, Color)>[
          (Offset(.22, .28), .34, Color(0xFFB15CFF)),
          (Offset(.66, .64), .40, Color(0xFF4EDFD0)),
          (Offset(.78, .18), .25, Color(0xFFFF6EBD)),
        ];
        for (final (position, radiusFactor, color) in clouds) {
          final radius = size.shortestSide * radiusFactor;
          final center = Offset(
            position.dx * size.width,
            position.dy * size.height,
          );
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..shader = RadialGradient(
                colors: <Color>[
                  color.withValues(alpha: .16),
                  color.withValues(alpha: .04),
                  Colors.transparent,
                ],
              ).createShader(Rect.fromCircle(center: center, radius: radius)),
          );
        }
        const dust = <Offset>[
          Offset(.08, .72),
          Offset(.17, .19),
          Offset(.31, .55),
          Offset(.48, .24),
          Offset(.57, .82),
          Offset(.70, .41),
          Offset(.84, .69),
          Offset(.92, .16),
        ];
        for (final star in dust) {
          canvas.drawCircle(
            Offset(star.dx * size.width, star.dy * size.height),
            1.25,
            soft,
          );
        }
      case TableFeltPattern.imageTexture:
        if (visual.textureLayout == TableTextureLayout.repeatingTile) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
              const Radius.circular(10),
            ),
            line..strokeWidth = 1.2,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _TableFeltPainter oldDelegate) =>
      oldDelegate.visual != visual;
}

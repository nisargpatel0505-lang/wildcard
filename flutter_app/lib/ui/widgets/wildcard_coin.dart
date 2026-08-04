import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

class WildcardCoinIcon extends StatelessWidget {
  const WildcardCoinIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(size),
      painter: const _WildcardCoinPainter(),
    ),
  );
}

class RunCoinBadge extends StatelessWidget {
  const RunCoinBadge({
    required this.coins,
    this.account = false,
    this.compact = false,
    super.key,
  });

  final int coins;
  final bool account;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      label: '$coins ${account ? 'account' : 'run'} coins',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceStrong,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.gold.withValues(alpha: .62)),
          boxShadow: [
            BoxShadow(color: tokens.gold.withValues(alpha: .11), blurRadius: 8),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 5 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WildcardCoinIcon(size: compact ? 17 : 20),
              const SizedBox(width: 5),
              Text(
                '$coins',
                style: TextStyle(
                  color: tokens.gold,
                  fontFamily: 'Bungee',
                  fontSize: compact ? 11 : 13,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoinPrice extends StatelessWidget {
  const CoinPrice(this.value, {this.label, this.compact = false, super.key});

  final int value;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value coins${label == null ? '' : ', $label'}',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WildcardCoinIcon(size: compact ? 15 : 18),
        const SizedBox(width: 4),
        Text(
          '$value${label == null ? '' : '  $label'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.wildcard.gold,
            fontFamily: 'Bungee',
            fontSize: compact ? 9.5 : 11,
          ),
        ),
      ],
    ),
  );
}

class CoinReward extends CoinPrice {
  const CoinReward(
    super.value, {
    super.label = 'REWARD',
    super.compact,
    super.key,
  });
}

class CoinSellValue extends CoinPrice {
  const CoinSellValue(
    super.value, {
    super.label = 'SELL',
    super.compact,
    super.key,
  });
}

class _WildcardCoinPainter extends CustomPainter {
  const _WildcardCoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.32, -.36),
          radius: .9,
          colors: [Color(0xFFFFF0A4), Color(0xFFF7C548), Color(0xFF9B5512)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      centre,
      radius * .78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .065
        ..color = const Color(0xFF8E4A0B),
    );
    // The currency mark is a real W, not the generic star used by the first
    // Flutter pass. A painted path stays crisp at the tiny shop-price sizes.
    final mark = Path()
      ..moveTo(size.width * .20, size.height * .30)
      ..lineTo(size.width * .33, size.height * .72)
      ..lineTo(size.width * .50, size.height * .49)
      ..lineTo(size.width * .67, size.height * .72)
      ..lineTo(size.width * .80, size.height * .30);
    canvas.drawPath(
      mark.shift(Offset(0, size.height * .045)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x659B5512),
    );
    canvas.drawPath(
      mark,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF6C3308),
    );
    canvas.drawCircle(
      Offset(size.width * .30, size.height * .26),
      size.width * .09,
      Paint()..color = Colors.white.withValues(alpha: .58),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

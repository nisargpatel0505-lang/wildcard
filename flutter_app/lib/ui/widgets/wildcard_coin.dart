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
    // A single stationary medallion shared by the wallet, prices and rewards.
    // Normalized geometry keeps the angular mark clear even at 15 logical px.
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    const centre = Offset(50, 49);
    const rimRect = Rect.fromLTWH(3, 2, 94, 94);

    // The low bronze edge gives thickness without a glow or blurred shadow.
    canvas.drawCircle(
      const Offset(50, 52),
      46,
      Paint()..color = const Color(0xFF885111),
    );
    canvas.drawCircle(
      centre,
      47,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0B3), Color(0xFFE9B53D), Color(0xFFAE6D17)],
          stops: [0, .48, 1],
        ).createShader(rimRect),
    );
    canvas.drawCircle(
      centre,
      46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFCD9635),
    );
    canvas.drawCircle(
      centre,
      39,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBE49A), Color(0xFFEBC04F), Color(0xFFD79927)],
          stops: [0, .55, 1],
        ).createShader(const Rect.fromLTWH(11, 10, 78, 78)),
    );
    canvas.drawCircle(
      centre,
      39,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFB47A21),
    );

    // A short rim reflection replaces the old white glint dot. It never
    // crosses the letter or animates over the player's balance.
    canvas.drawArc(
      const Rect.fromLTWH(6, 5, 88, 88),
      -2.65,
      1.22,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xBFFFF5C9),
    );

    // Filled straight edges stay legible without a font's tiny-size hinting
    // or rounded stroke joins swelling the two valleys into a heavy blob.
    final mark = Path()
      ..moveTo(26, 31)
      ..lineTo(34, 31)
      ..lineTo(41, 58)
      ..lineTo(47, 41)
      ..lineTo(53, 41)
      ..lineTo(59, 58)
      ..lineTo(66, 31)
      ..lineTo(74, 31)
      ..lineTo(63, 70)
      ..lineTo(56, 70)
      ..lineTo(50, 53)
      ..lineTo(44, 70)
      ..lineTo(37, 70)
      ..close();
    if (size.shortestSide >= 28) {
      canvas.drawPath(
        mark.shift(const Offset(0, 1.3)),
        Paint()..color = const Color(0xBFFFF1AE),
      );
    }
    canvas.drawPath(mark, Paint()..color = const Color(0xFF754710));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

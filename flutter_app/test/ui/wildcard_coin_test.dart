import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/wildcard_coin.dart';

void main() {
  testWidgets('coin medallion stays crisp at price, wallet and store sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: Key('coin-medallion-preview'),
            child: SizedBox(
              width: 360,
              height: 220,
              child: Column(
                children: [
                  _CoinSizeStrip(background: Color(0xFF171126)),
                  _CoinSizeStrip(background: Color(0xFFF6EEDC)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final size in [15.0, 20.0, 46.0, 96.0]) {
      final icons = find.byWidgetPredicate(
        (widget) => widget is WildcardCoinIcon && widget.size == size,
      );
      expect(icons, findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        expect(tester.getSize(icons.at(index)), Size.square(size));
      }
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('coin-medallion-preview')),
      matchesGoldenFile('goldens/wildcard_coin_medallion.png'),
    );
  });
}

class _CoinSizeStrip extends StatelessWidget {
  const _CoinSizeStrip({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: const SizedBox(
      width: 360,
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          WildcardCoinIcon(size: 15),
          WildcardCoinIcon(size: 20),
          WildcardCoinIcon(size: 46),
          WildcardCoinIcon(size: 96),
        ],
      ),
    ),
  );
}

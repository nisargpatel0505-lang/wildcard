import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(360, 800),
    Size(390, 844),
    Size(393, 873),
    Size(412, 915),
  ];

  for (final size in phoneSizes) {
    testWidgets('shop reserves themed Next Heat dock at '
        '${size.width.toInt()}x${size.height.toInt()} with 1.3 text', (
      tester,
    ) async {
      await _setPhoneSize(tester, size);
      var nextHeatTaps = 0;

      await tester.pumpWidget(
        _Harness(
          child: BetweenHeatShopScreen(
            stageCleared: 7,
            runCoins: 28,
            heatReward: 8,
            grade: 'A',
            heldJokers: jokerCatalog.take(5).toList(),
            jokerOffers: <JokerShopOffer>[
              JokerShopOffer(joker: jokerCatalog[5]),
              JokerShopOffer(joker: jokerCatalog[8]),
            ],
            supplyOffers: const <SupplyDefinition>[
              SupplyDefinition(SupplyId.scalpel, 'Scalpel', 3),
              SupplyDefinition(SupplyId.dye, 'Dye Kit', 4),
            ],
            supplyLedger: SupplyPurchaseLedger()..record(SupplyId.scalpel, 3),
            purchasedSupplyIdsThisShop: const <SupplyId>{SupplyId.dye},
            onBuyJoker: (_) {},
            onBuySupply: (_) {},
            onReroll: () {},
            onOpenDeck: () {},
            onNextHeat: () => nextHeatTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dock = find.byKey(const Key('shop-exit-dock'));
      final next = find.byKey(const Key('next-heat-button'));
      final deck = find.byKey(const Key('view-shop-deck-button'));
      expect(dock, findsOneWidget);
      expect(next, findsOneWidget);
      expect(
        find.text('READY FOR HEAT 8'),
        findsOneWidget,
        reason: 'The primary action must clearly announce the next Heat.',
      );

      final safeBottom = size.height - 24;
      expect(
        tester.getRect(next).bottom,
        lessThanOrEqualTo(safeBottom),
        reason: 'Next Heat must stay above the simulated gesture inset.',
      );
      expect(tester.getSize(next).height, greaterThanOrEqualTo(58));

      await tester.ensureVisible(deck);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final dockRect = tester.getRect(dock);
      final deckRect = tester.getRect(deck);
      expect(
        deckRect.bottom,
        lessThanOrEqualTo(dockRect.top + .5),
        reason: 'View Deck must never scroll underneath Next Heat.',
      );

      await tester.tap(next);
      await tester.pump();
      expect(nextHeatTaps, 1);
    });
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WildcardTheme.build(themeId: WildcardThemeId.vaporwave),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.3),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
      ),
      child: child!,
    ),
    home: child,
  );
}

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/tutorial_screen.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('card, Joker and deck semantics expose one complete label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    const card = PlayingCard(
      rank: CardRank.ace,
      suit: CardSuit.spades,
      selected: true,
    );
    await tester.pumpWidget(
      const _Harness(
        child: Column(
          children: [
            PlayingCardTile(key: Key('semantic-card'), card: card),
            CompactJokerCard(key: Key('empty-joker')),
          ],
        ),
      ),
    );

    expect(
      tester
          .getSemantics(find.byKey(const Key('semantic-card')))
          .getSemanticsData()
          .label,
      'A of spades, selected',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('empty-joker')))
          .getSemanticsData()
          .label,
      'Empty Joker slot',
    );

    await tester.pumpWidget(
      _Harness(
        child: DeckOverlay(
          allHeatCards: baseCardSet(),
          liveDrawCards: baseCardSet(),
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('deck-cell-spades-ace')))
          .getSemanticsData()
          .label,
      'A of spades, 1 of 1 live',
    );
    semantics.dispose();
  });

  testWidgets('tutorial remains usable at 320x568 with large app text', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      _Harness(
        textScaler: const TextScaler.linear(1.35),
        child: TutorialScreen(onComplete: _complete),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (var page = 0; page < 4; page++) {
      await tester.tap(find.text('NEXT RULE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('DEAL ME IN'), findsOneWidget);
  });

  testWidgets('shop controls fit 320x568 and stay 48dp at large text', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(320, 568));
    await tester.pumpWidget(
      _Harness(
        textScaler: const TextScaler.linear(1.35),
        child: BetweenHeatShopScreen(
          stageCleared: 3,
          runCoins: 28,
          heldJokers: jokerCatalog.take(3).toList(),
          jokerOffers: <JokerShopOffer>[
            JokerShopOffer(joker: jokerCatalog[5]),
            JokerShopOffer(joker: jokerCatalog[8]),
          ],
          supplyOffers: const <SupplyDefinition>[
            SupplyDefinition(SupplyId.scalpel, 'Scalpel', 3),
            SupplyDefinition(SupplyId.dye, 'Dye Kit', 4),
          ],
          supplyLedger: SupplyPurchaseLedger(),
          onBuyJoker: (_) {},
          onBuySupply: (_) {},
          onReroll: () {},
          onOpenDeck: () {},
          onNextHeat: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final supplyButton = find.byKey(const ValueKey('buy-supply-scalpel'));
    await tester.ensureVisible(supplyButton);
    expect(tester.getSize(supplyButton).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _complete() async {}

class _Harness extends StatelessWidget {
  const _Harness({required this.child, this.textScaler = TextScaler.noScaling});

  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WildcardTheme.build(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
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

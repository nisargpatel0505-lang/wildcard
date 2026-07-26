import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('playing card uses vector suits centered on the card', (
    tester,
  ) async {
    for (final suit in CardSuit.values) {
      await tester.pumpWidget(
        _Harness(
          child: Center(
            child: PlayingCardTile(
              key: const Key('card-bounds'),
              card: PlayingCard(rank: CardRank.ace, suit: suit),
              width: 48,
              height: 86,
            ),
          ),
        ),
      );
      await tester.pump();

      final card = tester.getRect(find.byKey(const Key('card-bounds')));
      final centerSuit = tester.getRect(
        find.byKey(const Key('playing-card-center-suit')),
      );

      expect(centerSuit.center.dx, closeTo(card.center.dx, 0.01));
      expect(centerSuit.center.dy, closeTo(card.center.dy, 0.01));
      expect(
        tester
            .widget<SuitGlyph>(
              find.byKey(const Key('playing-card-center-suit')),
            )
            .suit,
        suit,
      );
      expect(find.byType(SuitGlyph), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('default WILDCARD button labels stay crisp Bungee regular', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: Center(
          child: WildcardButton(
            label: 'Play Hand',
            expand: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('PLAY HAND'));
    expect(label.style?.fontFamily, 'Bungee');
    expect(label.style?.fontWeight, FontWeight.w400);
    expect(label.style?.shadows, isNull);
  });

  testWidgets('selected-card lift is opt-in and scoring can pin it', (
    tester,
  ) async {
    const selected = PlayingCard(
      rank: CardRank.king,
      suit: CardSuit.hearts,
      selected: true,
    );
    await tester.pumpWidget(
      const _Harness(
        child: PlayingCardTile(card: selected, liftWhenSelected: true),
      ),
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset.dy,
      -0.075,
    );

    await tester.pumpWidget(
      const _Harness(
        child: PlayingCardTile(card: selected, liftWhenSelected: false),
      ),
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      Offset.zero,
    );
  });

  testWidgets('home status and coin text do not use outline shadows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(child: WildcardHomeScreen(coins: 5268, bestHeat: 21)),
    );
    await tester.pump();

    final bestHeat = tester.widget<Text>(find.text('BEST HEAT 21'));
    final coins = tester.widget<Text>(find.text('5268'));
    expect(bestHeat.style?.shadows, isNull);
    expect(coins.style?.shadows, isNull);
  });

  testWidgets('small in-run shop labels use Space Grotesk bold', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: BetweenHeatShopScreen(
          stageCleared: 3,
          runCoins: 28,
          heatReward: 6,
          grade: 'A',
          heldJokers: jokerCatalog.take(2).toList(),
          jokerOffers: <JokerShopOffer>[JokerShopOffer(joker: jokerCatalog[5])],
          supplyOffers: const <SupplyDefinition>[
            SupplyDefinition(SupplyId.scalpel, 'Scalpel', 3),
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
    await tester.pump();

    for (final label in <String>[
      'JOKER OFFERS',
      'REROLL',
      jokerCatalog[5].name.toUpperCase(),
      'SCALPEL',
    ]) {
      final text = tester.widget<Text>(find.text(label).first);
      expect(text.style?.fontFamily, 'SpaceGrotesk', reason: label);
      expect(text.style?.fontWeight, FontWeight.w700, reason: label);
    }
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WildcardTheme.build(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 834),
          disableAnimations: true,
        ),
        child: Scaffold(body: child),
      ),
    );
  }
}

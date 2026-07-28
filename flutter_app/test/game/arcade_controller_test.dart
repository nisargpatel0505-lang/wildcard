import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/arcade_rules.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/game/arcade_controller.dart';

void main() {
  test('controller deals five and refuses fewer than exactly three', () async {
    final controller = ArcadeController.start(
      ArcadeRunConfig(
        length: ArcadeRunLength.sprint8,
        rngSeed: 17,
        discoveredJokerIds: const <String>{},
        initialDeck: _openingDeck(),
      ),
      wait: (_) async {},
    );
    addTearDown(controller.dispose);

    expect(controller.hand, hasLength(5));
    controller.toggleCard(controller.hand[0].uid!);
    controller.toggleCard(controller.hand[1].uid!);
    expect(controller.canScore, isFalse);
    expect(await controller.scoreSelected(), isFalse);

    controller.toggleCard(controller.hand[2].uid!);
    expect(controller.canScore, isTrue);
  });

  test('a successful third clear opens the quick shop', () async {
    final controller = ArcadeController.start(
      ArcadeRunConfig(
        length: ArcadeRunLength.sprint8,
        rngSeed: 2,
        discoveredJokerIds: const <String>{'copper', 'presser'},
        initialJokerIds: const <String>['devx20'],
        initialDeck: _openingDeck(),
      ),
      wait: (_) async {},
    );
    addTearDown(controller.dispose);

    for (var cleared = 1; cleared <= 3; cleared++) {
      for (final card in controller.hand.take(3)) {
        controller.toggleCard(card.uid!);
      }
      expect(await controller.scoreSelected(), isTrue);
      if (cleared < 3) {
        expect(controller.phase, ArcadePhase.choosing);
      }
    }

    expect(controller.clearedRounds, 3);
    expect(controller.phase, ArcadePhase.shop);
    expect(controller.shopOffers.length, lessThanOrEqualTo(3));
  });

  test('Turbo only changes the presentation wait, not the score', () async {
    final waits = <Duration>[];
    final normal = ArcadeController.start(
      ArcadeRunConfig(
        length: ArcadeRunLength.sprint8,
        rngSeed: 4,
        discoveredJokerIds: const <String>{},
        initialDeck: _openingDeck(),
      ),
      wait: (duration) async => waits.add(duration),
    );
    addTearDown(normal.dispose);
    for (final card in normal.hand.take(3)) {
      normal.toggleCard(card.uid!);
    }
    await normal.scoreSelected();
    final normalScore = normal.totalScore;
    expect(waits.single, const Duration(milliseconds: 1850));

    final turbo = ArcadeController.start(
      ArcadeRunConfig(
        length: ArcadeRunLength.sprint8,
        rngSeed: 4,
        discoveredJokerIds: const <String>{},
        initialDeck: _openingDeck(),
        turbo: true,
      ),
      wait: (duration) async => waits.add(duration),
    );
    addTearDown(turbo.dispose);
    turbo.setTurbo(true);
    for (final card in turbo.hand.take(3)) {
      turbo.toggleCard(card.uid!);
    }
    await turbo.scoreSelected();

    expect(turbo.totalScore, normalScore);
    expect(waits.last, const Duration(milliseconds: 650));
  });

  test('Arcade gates WILD until round 12 and never offers two', () async {
    final controller = ArcadeController.start(
      ArcadeRunConfig(
        length: ArcadeRunLength.endless,
        rngSeed: 22,
        discoveredJokerIds: jokerCatalog.map((joker) => joker.id).toSet(),
        initialJokerIds: const <String>['devx20'],
        initialDeck: _openingDeck(),
      ),
      wait: (_) async {},
    );
    addTearDown(controller.dispose);

    for (var round = 1; round <= 12; round++) {
      for (final card in controller.hand.take(3)) {
        controller.toggleCard(card.uid!);
      }
      await controller.scoreSelected();
      if (controller.phase == ArcadePhase.shop) {
        final wildCount = controller.shopOffers
            .where((joker) => joker.rarity == JokerRarity.wild)
            .length;
        expect(wildCount, lessThanOrEqualTo(1));
        expect(
          controller.shopOffers.where(isPremiumShopOffer).length,
          lessThanOrEqualTo(1),
        );
        if (round < 12) expect(wildCount, 0);
        if (round < 4) {
          expect(controller.shopOffers.where(isHighImpactShopJoker), isEmpty);
        }
        if (round < 12) controller.leaveShop();
      }
    }
  });

  test('Arcade shop RNG is deterministic and discovery-bounded', () async {
    final discoveries = <String>{
      'copper',
      'presser',
      'flushfund',
      'rarity_hunter',
      'trainer',
      'survivor',
    };
    ArcadeController build() => ArcadeController.start(
      ArcadeRunConfig(
        length: ArcadeRunLength.endless,
        rngSeed: 0x85052402,
        discoveredJokerIds: discoveries,
        initialJokerIds: const <String>['devx20'],
        initialDeck: _openingDeck(),
      ),
      wait: (_) async {},
    );

    final first = build();
    final second = build();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    for (var round = 1; round <= 12; round++) {
      for (final controller in <ArcadeController>[first, second]) {
        for (final card in controller.hand.take(3)) {
          controller.toggleCard(card.uid!);
        }
        await controller.scoreSelected();
      }
      expect(first.phase, second.phase);
      if (first.phase == ArcadePhase.shop) {
        expect(
          first.shopOffers.map((joker) => joker.id),
          orderedEquals(second.shopOffers.map((joker) => joker.id)),
        );
        expect(
          first.shopOffers.every((joker) => discoveries.contains(joker.id)),
          isTrue,
        );
        expect(
          first.shopOffers.where(isPremiumShopOffer),
          hasLength(lessThanOrEqualTo(1)),
        );
        if (round < 12) {
          first.leaveShop();
          second.leaveShop();
        }
      }
    }
  });
}

List<PlayingCard> _openingDeck() => <PlayingCard>[
  const PlayingCard(rank: CardRank.ace, suit: CardSuit.spades),
  const PlayingCard(rank: CardRank.king, suit: CardSuit.spades),
  const PlayingCard(rank: CardRank.queen, suit: CardSuit.spades),
  const PlayingCard(rank: CardRank.jack, suit: CardSuit.hearts),
  const PlayingCard(rank: CardRank.ten, suit: CardSuit.diamonds),
  ...baseCardSet(),
];

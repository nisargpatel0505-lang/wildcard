import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/deck_integrity.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';

void main() {
  group('v7.1 deck integrity', () {
    test('repairs a short deck to 24 distinct cards', () {
      final deck = baseCardSet().take(10).toList();
      final result = normalizeDeckIntegrity(deck);
      expect(deck, hasLength(minimumDeckSize));
      expect(deck.map((card) => card.toString()).toSet(), hasLength(24));
      expect(result.changed, isTrue);
      expect(result.restored, 14);
      expect(result.copiedCount, 0);
      expect(result.destroyedCount, 28);
    });

    test('marks second exact card copied and drops a third', () {
      final ace = const PlayingCard(rank: CardRank.ace, suit: CardSuit.spades);
      final deck = <PlayingCard>[
        ...baseCardSet().take(24),
        ace,
        ace.copyWith(enhancement: CardEnhancement.neon),
      ];
      final result = normalizeDeckIntegrity(deck);
      final aces = deck
          .where(
            (card) => card.rank == CardRank.ace && card.suit == CardSuit.spades,
          )
          .toList();
      expect(aces, hasLength(2));
      expect(aces.last.copied, isTrue);
      expect(aces.last.enhancement, isNull);
      expect(result.removed, 1);
    });

    test('copy, enhancement and dye guards enforce exact-copy rules', () {
      final deck = baseCardSet();
      final aceIndex = deck.indexWhere(
        (card) => card.rank == CardRank.ace && card.suit == CardSuit.spades,
      );
      final ace = deck[aceIndex];
      expect(canCopyCard(deck, ace), isTrue);
      deck.add(ace.copyWith(copied: true));
      expect(canCopyCard(deck, ace), isFalse);
      expect(canEnhanceCard(deck.last), isFalse);
      final heartsAceIndex = deck.indexWhere(
        (card) => card.rank == CardRank.ace && card.suit == CardSuit.hearts,
      );
      expect(canDyeCard(deck, heartsAceIndex, CardSuit.spades), isFalse);
    });
  });

  group('v7.1 economy', () {
    test('Heat rewards, interest, reroll and grades match the phone build', () {
      expect(
        <int>[for (var heat = 1; heat <= 5; heat++) runReward(heat)],
        <int>[3, 4, 5, 5, 6],
      );
      expect(runCoinInterest(7), 0);
      expect(runCoinInterest(8), 1);
      expect(runCoinInterest(100), 3);
      expect(shopRerollCost, 3);
      expect(gradeForPlays(1).bonus, 2);
      expect(gradeForPlays(2).bonus, 1);
      expect(gradeForPlays(3).bonus, 0);
      expect(gradeForPlays(4).bonus, 0);
    });

    test('supply ledger uses +5 through Heat 20 and +10 after Heat 20', () {
      final ledger = SupplyPurchaseLedger();
      final scalpel = supplyCatalog.firstWhere(
        (supply) => supply.id == SupplyId.scalpel,
      );
      expect(supplyPrice(scalpel, ledger: ledger), 3);
      ledger.record(SupplyId.scalpel, 20);
      expect(supplyPrice(scalpel, ledger: ledger), 8);
      ledger.record(SupplyId.scalpel, 21);
      expect(supplyPrice(scalpel, ledger: ledger), 18);
      expect(supplyPrice(scalpel, ledger: ledger, inflation: true), 20);
    });

    test('legacy purchase counts migrate without resetting prices', () {
      final ledger = SupplyPurchaseLedger.fromLegacy(
        ledgerJson: const <Object?>[
          <String, Object?>{'id': 'scalpel', 'stage': 21, 'step': 10},
        ],
        purchaseCountsJson: const <String, Object?>{'scalpel': 3},
      );
      expect(ledger.count(SupplyId.scalpel), 3);
      expect(ledger.surcharge(SupplyId.scalpel), 20);
    });

    test('difficulty scales deterministic stake payout', () {
      expect(stakePayout(100, 12, difficulty: RunDifficulty.easy), 120);
      expect(stakePayout(100, 12), 200);
      expect(stakePayout(100, 12, difficulty: RunDifficulty.hard), 320);
    });
  });
}

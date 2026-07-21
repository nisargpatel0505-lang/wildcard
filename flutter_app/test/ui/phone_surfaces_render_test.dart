import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  const phoneSizes = <Size>[Size(320, 568), Size(360, 800)];

  testWidgets('home keeps its complete primary menu visible on a phone', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      const _Harness(
        child: WildcardHomeScreen(
          coins: 1250,
          bestHeat: 12,
          dailyRewardAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DAILY REWARD'), findsOneWidget);
    expect(find.bySemanticsLabel('Mute sound effects'), findsOneWidget);
    final lastControl = find.bySemanticsLabel('Use fast scoring pace');
    expect(lastControl, findsOneWidget);
    expect(tester.getRect(lastControl).bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  for (final size in phoneSizes) {
    group('${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('run table renders and keeps card taps separate', (
        tester,
      ) async {
        await _setPhoneSize(tester, size);
        final tappedCards = <int>[];
        final hand = <PlayingCard>[
          const PlayingCard(
            rank: CardRank.ace,
            suit: CardSuit.spades,
            selected: true,
          ),
          const PlayingCard(
            rank: CardRank.king,
            suit: CardSuit.hearts,
            selected: true,
          ),
          const PlayingCard(rank: CardRank.queen, suit: CardSuit.diamonds),
          const PlayingCard(rank: CardRank.jack, suit: CardSuit.clubs),
          const PlayingCard(rank: CardRank.ten, suit: CardSuit.spades),
          const PlayingCard(rank: CardRank.eight, suit: CardSuit.hearts),
          const PlayingCard(rank: CardRank.six, suit: CardSuit.diamonds),
          const PlayingCard(rank: CardRank.four, suit: CardSuit.clubs),
          const PlayingCard(rank: CardRank.two, suit: CardSuit.spades),
        ];
        final state = ScoringState(
          rngSeed: 71,
          stage: 8,
          stageScore: 312,
          handsLeft: 3,
          discardsLeft: 4,
          runCoins: 18,
          jokerIds: jokerCatalog.take(5).map((joker) => joker.id).toList(),
          deckCardsLeft: 43,
          modifierStack: const <HeatModifier>[HeatModifier.frostbite],
        );
        const score = ScoreResult(
          handType: HandType.pair,
          base: 20,
          rankSum: 28,
          rankScore: 17,
          valuePoints: 37,
          multiplier: 2.4,
          total: 89,
          perCard: <int>[15, 13],
          scoringFlags: <bool>[true, true],
          events: <ScoreEvent>[],
        );

        await tester.pumpWidget(
          _Harness(
            child: RunTableScreen(
              state: state,
              hand: hand,
              slySpeech: 'That Pair buys you time. Make the next hand count.',
              tableFeltId: 'felt_royal',
              score: score,
              activeScoreEvent: const ScoreEvent(
                type: ScoreEventType.mult,
                jokerIndex: 1,
                label: '+0.20 Mult',
              ),
              onToggleCard: tappedCards.add,
              onPlay: () {},
              onDiscard: () {},
              onAbandon: () {},
              onOpenDeck: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('MODIFIER ACTIVE  \u00b7  FROSTBITE'), findsOneWidget);
        expect(find.byKey(const Key('playing-card-row')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('table-felt-felt_royal')),
          findsOneWidget,
        );

        final firstCard = find.byKey(const ValueKey('hand-card-0'));
        final secondCard = find.byKey(const ValueKey('hand-card-1'));
        await tester.ensureVisible(firstCard);
        await tester.tap(firstCard);
        await tester.tap(secondCard);
        expect(tappedCards, <int>[0, 1]);

        final firstRect = tester.getRect(firstCard);
        final secondRect = tester.getRect(secondCard);
        expect(
          secondRect.left,
          greaterThan(firstRect.right),
          reason: 'Adjacent cards must keep independent, non-overlapping taps.',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('shop renders offers and enforces once-per-shop supply UI', (
        tester,
      ) async {
        await _setPhoneSize(tester, size);
        var boughtSupply = false;
        final ledger = SupplyPurchaseLedger()..record(SupplyId.scalpel, 3);

        await tester.pumpWidget(
          _Harness(
            child: BetweenHeatShopScreen(
              stageCleared: 3,
              runCoins: 28,
              heatReward: 6,
              grade: 'A',
              heldJokers: jokerCatalog.take(3).toList(),
              jokerOffers: <JokerShopOffer>[
                JokerShopOffer(joker: jokerCatalog[5]),
                JokerShopOffer(joker: jokerCatalog[8]),
              ],
              supplyOffers: const <SupplyDefinition>[
                SupplyDefinition(SupplyId.scalpel, 'Scalpel', 3),
                SupplyDefinition(SupplyId.dye, 'Dye Kit', 4),
              ],
              supplyLedger: ledger,
              purchasedSupplyIdsThisShop: const <SupplyId>{SupplyId.dye},
              onBuyJoker: (_) {},
              onBuySupply: (_) => boughtSupply = true,
              onReroll: () {},
              onOpenDeck: () {},
              onNextHeat: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('next-heat-button')), findsOneWidget);

        final boughtButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey('buy-supply-dye')),
        );
        expect(boughtButton.onPressed, isNull);

        final scalpelButton = find.byKey(const ValueKey('buy-supply-scalpel'));
        await tester.ensureVisible(scalpelButton);
        await tester.tap(scalpelButton);
        expect(boughtSupply, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('deck overlay shows every card identity including all Aces', (
        tester,
      ) async {
        await _setPhoneSize(tester, size);
        final allCards = baseCardSet();
        final liveCards = allCards.skip(12).take(31).toList();
        final currentHand = allCards.take(9).toList();

        await tester.pumpWidget(
          _Harness(
            child: DeckOverlay(
              allHeatCards: allCards,
              liveDrawCards: liveCards,
              currentHand: currentHand,
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('deck-cell-spades-ace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('deck-cell-hearts-ace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('deck-cell-diamonds-ace')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('deck-cell-clubs-ace')),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'deck-cell-',
                ),
          ),
          findsNWidgets(52),
        );
      });
    });
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WildcardTheme.build(),
      home: child,
    );
  }
}

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

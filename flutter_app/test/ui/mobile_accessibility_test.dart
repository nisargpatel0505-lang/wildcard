import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/tutorial_screen.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
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
      expect(
        tester.takeException(),
        isNull,
        reason: 'Tutorial page ${page + 2} must fit the compact phone.',
      );
    }
    expect(find.text('CLAIM GIFT & CHOOSE RUN'), findsOneWidget);
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

  testWidgets(
    'dense House Rule table remains readable and non-overlapping at 320x568',
    (tester) async {
      await _setPhoneSize(tester, const Size(320, 568));
      final state = ScoringState(
        rngSeed: 87,
        stage: 12,
        stageScore: 540,
        handsLeft: 2,
        discardsLeft: 1,
        runCoins: 31,
        jokerIds: jokerCatalog.take(5).map((joker) => joker.id).toList(),
        deckCardsLeft: 43,
        modifierStack: const <HeatModifier>[HeatModifier.frostbite],
      );

      await tester.pumpWidget(
        _Harness(
          textScaler: const TextScaler.linear(1.3),
          child: RunTableScreen(
            state: state,
            hand: const <PlayingCard>[
              PlayingCard(rank: CardRank.ace, suit: CardSuit.spades),
              PlayingCard(rank: CardRank.king, suit: CardSuit.hearts),
              PlayingCard(rank: CardRank.queen, suit: CardSuit.diamonds),
              PlayingCard(rank: CardRank.jack, suit: CardSuit.clubs),
              PlayingCard(rank: CardRank.ten, suit: CardSuit.spades),
              PlayingCard(rank: CardRank.eight, suit: CardSuit.hearts),
              PlayingCard(rank: CardRank.six, suit: CardSuit.diamonds),
              PlayingCard(rank: CardRank.four, suit: CardSuit.clubs),
              PlayingCard(rank: CardRank.two, suit: CardSuit.spades),
            ],
            slySpeech:
                'The House changed the table. Read the rule before you play.',
            levelRules: const <String>[
              'PAUPERS\' TABLE · Jacks, Queens and Kings still form hands but score 0 rank.',
              'FROSTBITE · Spades score 0 printed rank this Heat.',
            ],
            onToggleCard: (_) {},
            onPlay: () {},
            onDiscard: () {},
            onAbandon: () {},
            onOpenDeck: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('level-rule-panel')), findsOneWidget);
      expect(find.byKey(const Key('playing-card-row')), findsOneWidget);

      for (final label in <String>['HANDS', 'DECK', 'SORT: RANK']) {
        final matches = find.text(label);
        expect(matches, findsAtLeastNWidgets(1));
        await tester.ensureVisible(matches.last);
        expect(tester.takeException(), isNull);
      }
      for (final label in <String>['DISCARD (0)', 'PLAY HAND', 'ABANDON']) {
        final control = find.text(label);
        expect(control, findsOneWidget);
        await tester.ensureVisible(control);
        expect(tester.takeException(), isNull);
      }
    },
  );
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

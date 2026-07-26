import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  const layouts = <(Size, double, double)>[
    (Size(320, 568), 60, 9),
    (Size(360, 800), 72, 42),
    (Size(393, 873), 86, 71),
    (Size(1080, 2400), 86, 71),
  ];

  for (final (size, jokerHeight, minimumEquationGap) in layouts) {
    testWidgets('playfield reserves Joker and table spacing at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await _setSize(tester, size);
      await tester.pumpWidget(
        _Harness(
          child: RunTableScreen(
            state: _state(),
            hand: _hand(),
            slySpeech: 'Read the table.',
            score: _score,
            onToggleCard: (_) {},
            onPlay: () {},
            onDiscard: () {},
            onAbandon: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final jokerFinders = [
        for (final joker in jokerCatalog.take(5))
          find.byKey(ValueKey('run-joker-${joker.id}')),
      ];
      for (final finder in jokerFinders) {
        expect(
          tester.widget<CompactJokerCard>(finder).height,
          closeTo(jokerHeight, 0.01),
        );
      }

      final lastJokerBottom = jokerFinders
          .map(tester.getRect)
          .map((rect) => rect.bottom)
          .reduce((a, b) => a > b ? a : b);
      final equationLabel = tester.getRect(
        find.text('PAIR \u00b7 2 CARDS SCORE'),
      );
      expect(
        equationLabel.top - lastJokerBottom,
        greaterThanOrEqualTo(minimumEquationGap),
        reason: 'The playfield must not crowd the two-row Joker rack.',
      );

      final felt = tester.getRect(
        find.byKey(const ValueKey('table-felt-felt_classic')),
      );
      expect(felt.width, lessThanOrEqualTo(760));
      expect(felt.center.dx, closeTo(size.width / 2, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selected card lifts without stealing the adjacent exposed tap strip',
    (tester) async {
      await _setSize(tester, const Size(360, 800));
      final taps = <int>[];

      await tester.pumpWidget(
        _Harness(
          child: RunTableScreen(
            state: _state(),
            hand: _hand(),
            slySpeech: 'Read the table.',
            onToggleCard: taps.add,
            onPlay: () {},
            onDiscard: () {},
            onAbandon: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = find.byKey(const ValueKey('hand-card-slot-0'));
      final second = find.byKey(const ValueKey('hand-card-slot-1'));
      await tester.ensureVisible(first);
      final frostbitten = tester.widget<PlayingCardTile>(first);
      expect(frostbitten.rankSuppressed, isTrue);
      expect(frostbitten.rankSuppressionLabel, 'Frostbite');
      expect(
        frostbitten.onTap,
        isNotNull,
        reason:
            'A zero-rank card must stay selectable because it can still form a hand.',
      );
      expect(
        find.byKey(const ValueKey('modifier-rank-zero-A♠')),
        findsOneWidget,
      );
      expect(tester.widget<PlayingCardTile>(second).rankSuppressed, isFalse);
      final secondRect = tester.getRect(second);
      final firstSuit = tester.getRect(
        find.descendant(
          of: first,
          matching: find.byKey(const Key('playing-card-center-suit')),
        ),
      );
      final secondSuit = tester.getRect(
        find.descendant(
          of: second,
          matching: find.byKey(const Key('playing-card-center-suit')),
        ),
      );

      expect(
        secondSuit.top - firstSuit.top,
        greaterThanOrEqualTo(5),
        reason: 'Selection needs a clearly visible lift.',
      );

      // This point sits inside both overlapping cards. Natural paint order
      // must leave the next card on top, otherwise selecting one card makes
      // its neighbour harder to tap.
      await tester.tapAt(Offset(secondRect.left + 2, secondRect.center.dy));
      expect(taps, <int>[1]);

      await tester.pumpWidget(
        _Harness(
          child: RunTableScreen(
            state: _state(),
            hand: _hand(),
            slySpeech: 'Read the table.',
            busy: true,
            onToggleCard: taps.add,
            onPlay: () {},
            onDiscard: () {},
            onAbandon: () {},
          ),
        ),
      );
      await tester.pump();

      final busySlide = tester.widget<AnimatedSlide>(
        find.descendant(
          of: find.byKey(const ValueKey('hand-card-slot-0')),
          matching: find.byType(AnimatedSlide),
        ),
      );
      expect(busySlide.offset, Offset.zero);
      expect(tester.takeException(), isNull);
    },
  );
}

ScoringState _state() => ScoringState(
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

List<PlayingCard> _hand() => const <PlayingCard>[
  PlayingCard(rank: CardRank.ace, suit: CardSuit.spades, selected: true),
  PlayingCard(rank: CardRank.king, suit: CardSuit.hearts),
  PlayingCard(rank: CardRank.queen, suit: CardSuit.diamonds),
  PlayingCard(rank: CardRank.jack, suit: CardSuit.clubs),
  PlayingCard(rank: CardRank.ten, suit: CardSuit.spades),
  PlayingCard(rank: CardRank.eight, suit: CardSuit.hearts),
  PlayingCard(rank: CardRank.six, suit: CardSuit.diamonds),
  PlayingCard(rank: CardRank.four, suit: CardSuit.clubs),
  PlayingCard(rank: CardRank.two, suit: CardSuit.spades),
];

const _score = ScoreResult(
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

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: WildcardTheme.build(),
      home: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );
  }
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

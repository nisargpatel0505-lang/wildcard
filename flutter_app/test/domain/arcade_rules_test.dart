import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/arcade_rules.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/scoring_engine.dart';

void main() {
  group('Arcade three-card recognition', () {
    test('requires exactly three selected cards', () {
      expect(ArcadeRules.canScoreSelection(2), isFalse);
      expect(ArcadeRules.canScoreSelection(3), isTrue);
      expect(ArcadeRules.canScoreSelection(4), isFalse);
      expect(
        () => ArcadeRules.evaluate(<PlayingCard>[
          _card(CardRank.ace, CardSuit.spades),
          _card(CardRank.king, CardSuit.spades),
        ]),
        throwsArgumentError,
      );
    });

    test('recognizes every Arcade hand in descending shape order', () {
      expect(
        _type(
          _cards(
            const <CardRank>[CardRank.ace, CardRank.king, CardRank.queen],
            const <CardSuit>[CardSuit.spades, CardSuit.spades, CardSuit.spades],
          ),
        ),
        ArcadeHandType.straightFlush,
      );
      expect(
        _type(
          _cards(const <CardRank>[
            CardRank.seven,
            CardRank.seven,
            CardRank.seven,
          ]),
        ),
        ArcadeHandType.threeOfAKind,
      );
      expect(
        _type(
          _cards(const <CardRank>[CardRank.ace, CardRank.two, CardRank.three]),
        ),
        ArcadeHandType.straight,
      );
      expect(
        _type(
          _cards(
            const <CardRank>[CardRank.two, CardRank.six, CardRank.king],
            const <CardSuit>[CardSuit.clubs, CardSuit.clubs, CardSuit.clubs],
          ),
        ),
        ArcadeHandType.flush,
      );
      expect(
        _type(
          _cards(const <CardRank>[CardRank.nine, CardRank.nine, CardRank.king]),
        ),
        ArcadeHandType.pair,
      );
      expect(
        _type(
          _cards(const <CardRank>[CardRank.two, CardRank.eight, CardRank.king]),
        ),
        ArcadeHandType.highCard,
      );
    });

    test('high card and pair only score their contributing cards', () {
      final highCards = _cards(const <CardRank>[
        CardRank.two,
        CardRank.eight,
        CardRank.king,
      ]);
      final high = ArcadeRules.evaluate(highCards);
      expect(high.scoringCards, <PlayingCard>{highCards[2]});

      final pairCards = _cards(const <CardRank>[
        CardRank.nine,
        CardRank.nine,
        CardRank.king,
      ]);
      final pair = ArcadeRules.evaluate(pairCards);
      expect(pair.scoringCards, <PlayingCard>{pairCards[0], pairCards[1]});
    });

    test('structural Jokers keep their authoritative Arcade meaning', () {
      expect(
        ArcadeRules.evaluate(
          _cards(const <CardRank>[CardRank.four, CardRank.six, CardRank.seven]),
          activeJokerIds: const <String>{'gap_filler'},
        ).type,
        ArcadeHandType.straight,
      );
      expect(
        ArcadeRules.evaluate(
          _cards(const <CardRank>[CardRank.two, CardRank.ace, CardRank.ace]),
          activeJokerIds: const <String>{'alchemist'},
        ).type,
        ArcadeHandType.threeOfAKind,
      );
      expect(
        ArcadeRules.evaluate(
          _cards(const <CardRank>[
            CardRank.eight,
            CardRank.king,
            CardRank.king,
          ]),
          activeJokerIds: const <String>{'understudy'},
        ).type,
        ArcadeHandType.threeOfAKind,
      );
      expect(
        ArcadeRules.evaluate(
          _cards(
            const <CardRank>[CardRank.three, CardRank.eight, CardRank.king],
            const <CardSuit>[CardSuit.clubs, CardSuit.clubs, CardSuit.diamonds],
          ),
          activeJokerIds: const <String>{'suit_swap'},
        ).type,
        ArcadeHandType.flush,
      );
    });
  });

  group('Arcade progression contract', () {
    test(
      'targets increase deterministically and accelerate after 15 and 30',
      () {
        final targets = <int>[
          for (var round = 1; round <= 60; round++)
            ArcadeRules.targetForRound(round),
        ];
        expect(targets.first, 15);
        for (var index = 1; index < targets.length; index++) {
          expect(targets[index], greaterThan(targets[index - 1]));
        }
        expect(ArcadeRules.targetForRound(8), 43);
        expect(ArcadeRules.targetForRound(15), 71);
        expect(ArcadeRules.targetForRound(30), 176);
        expect(ArcadeRules.targetForRound(31), 189);
      },
    );

    test('shop opens after every third cleared round only', () {
      expect(
        <int>[
          for (var round = 1; round <= 12; round++)
            if (ArcadeRules.opensShopAfter(round)) round,
        ],
        <int>[3, 6, 9, 12],
      );
    });

    test('finite endings and Endless milestones are exact', () {
      expect(ArcadeRules.completesAfter(ArcadeRunLength.sprint8, 7), isFalse);
      expect(ArcadeRules.completesAfter(ArcadeRunLength.sprint8, 8), isTrue);
      expect(
        ArcadeRules.completesAfter(ArcadeRunLength.standard15, 15),
        isTrue,
      );
      expect(
        ArcadeRules.completesAfter(ArcadeRunLength.challenge30, 30),
        isTrue,
      );
      expect(
        ArcadeRules.completesAfter(ArcadeRunLength.endless, 1000),
        isFalse,
      );
      expect(
        <int>[
          for (var round = 1; round <= 100; round++)
            if (ArcadeRules.milestoneAfter(round) != null) round,
        ],
        <int>[25, 50, 75, 100],
      );
    });
  });

  group('authoritative scoring isolation', () {
    test('Arcade resolves three-card shapes through existing Joker maths', () {
      final cards = _cards(const <CardRank>[
        CardRank.five,
        CardRank.six,
        CardRank.seven,
      ]);
      final state = ScoringState(rngSeed: 41, jokerIds: <String>['copper']);
      final evaluation = ArcadeRules.evaluate(cards);
      final result = WildcardScoringEngine(
        state,
      ).scoreHand(cards, resolvedHand: evaluation.authoritative);

      expect(result.handType, HandType.straight);
      expect(result.multiplier, closeTo(1.3, 0.0001));
      expect(
        result.events.any(
          (event) => event.jokerIndex == 0 && event.type == ScoreEventType.mult,
        ),
        isTrue,
      );
    });

    test('normal five-card evaluator remains unchanged', () {
      final engine = WildcardScoringEngine(ScoringState(rngSeed: 9));
      expect(
        engine.evaluateHand(
          _cards(
            const <CardRank>[
              CardRank.ten,
              CardRank.jack,
              CardRank.queen,
              CardRank.king,
              CardRank.ace,
            ],
            const <CardSuit>[
              CardSuit.spades,
              CardSuit.spades,
              CardSuit.spades,
              CardSuit.spades,
              CardSuit.spades,
            ],
          ),
        ),
        HandType.royalFlush,
      );
      expect(
        engine.evaluateHand(
          _cards(const <CardRank>[
            CardRank.two,
            CardRank.two,
            CardRank.two,
            CardRank.king,
            CardRank.king,
          ]),
        ),
        HandType.fullHouse,
      );
      expect(
        engine.evaluateHand(
          _cards(const <CardRank>[
            CardRank.two,
            CardRank.five,
            CardRank.eight,
            CardRank.jack,
            CardRank.ace,
          ]),
        ),
        HandType.highCard,
      );
    });
  });
}

ArcadeHandType _type(List<PlayingCard> cards) =>
    ArcadeRules.evaluate(cards).type;

List<PlayingCard> _cards(
  List<CardRank> ranks, [
  List<CardSuit> suits = const <CardSuit>[
    CardSuit.spades,
    CardSuit.hearts,
    CardSuit.diamonds,
    CardSuit.clubs,
    CardSuit.spades,
  ],
]) => <PlayingCard>[
  for (var index = 0; index < ranks.length; index++)
    _card(ranks[index], suits[index]),
];

PlayingCard _card(CardRank rank, CardSuit suit) =>
    PlayingCard(rank: rank, suit: suit);

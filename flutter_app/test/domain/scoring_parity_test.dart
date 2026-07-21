import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/random_streams.dart';
import 'package:wildcard/domain/scoring_engine.dart';

void main() {
  group('card and hand evaluation parity', () {
    test('base deck contains 52 unique cards and Ace is 15', () {
      final deck = baseCardSet();
      expect(deck, hasLength(52));
      expect(deck.map((card) => card.toString()).toSet(), hasLength(52));
      expect(deck.where((card) => card.rank == CardRank.ace), hasLength(4));
      expect(deck.any((card) => card.value == 14), isFalse);
    });

    test('all standard hand classes and Ace-low/high straights', () {
      final engine = _engine();
      expect(engine.evaluateHand(_cards('AS KD 8C 5H 2S')), HandType.highCard);
      expect(engine.evaluateHand(_cards('AS AD 8C 5H 2S')), HandType.pair);
      expect(engine.evaluateHand(_cards('AS AD 8C 8H 2S')), HandType.twoPair);
      expect(
        engine.evaluateHand(_cards('AS AD AC 8H 2S')),
        HandType.threeOfAKind,
      );
      expect(engine.evaluateHand(_cards('2S 3D 4C 5H 6S')), HandType.straight);
      expect(engine.evaluateHand(_cards('AS 2D 3C 4H 5S')), HandType.straight);
      expect(engine.evaluateHand(_cards('10S JD QC KH AS')), HandType.straight);
      expect(engine.evaluateHand(_cards('2S 5S 8S 10S AS')), HandType.flush);
      expect(engine.evaluateHand(_cards('AS AD AC 8H 8S')), HandType.fullHouse);
      expect(
        engine.evaluateHand(_cards('AS AD AC AH 8S')),
        HandType.fourOfAKind,
      );
      expect(
        engine.evaluateHand(_cards('2S 3S 4S 5S 6S')),
        HandType.straightFlush,
      );
      expect(
        engine.evaluateHand(_cards('10S JS QS KS AS')),
        HandType.royalFlush,
      );
    });

    test(
      'rule-breaker hand definitions match Shortcut, Pocket Flush and wild suit',
      () {
        final shortcut = _engine(jokers: const <String>['shortcut']);
        expect(shortcut.evaluateHand(_cards('QS KD AH')), HandType.straight);
        expect(
          shortcut.evaluateHand(_cards('QS KS AS')),
          HandType.straight,
          reason: 'v7.1 removed the old illegal 3-card Straight Flush path',
        );

        final pocket = _engine(jokers: const <String>['pocketflush']);
        expect(pocket.evaluateHand(_cards('2S 5S 8S AS')), HandType.flush);

        final state = ScoringState(
          rngSeed: 1,
          modifier: HeatModifier.lowCeiling,
        );
        final ceiling = WildcardScoringEngine(state);
        expect(ceiling.evaluateHand(_cards('2S 3D 4C 5H')), HandType.straight);

        final wildSuit = _cards('2S 5S 8S 10H AS');
        wildSuit[3] = wildSuit[3].copyWith(
          enhancement: CardEnhancement.wildsuit,
        );
        expect(ceiling.evaluateHand(wildSuit), HandType.flush);
      },
    );
  });

  group('exact score goldens', () {
    final cases = <String, int>{
      'AS': 15,
      '10S 10H': 35,
      '10S 10H 5C 5D': 64,
      '7S 7H 7C': 91,
      '2S 3D 4C 5H 6S': 123,
      '10S JS QS KS AS': 481,
    };

    for (final entry in cases.entries) {
      test('${entry.key} scores ${entry.value}', () {
        expect(_engine().scoreHand(_cards(entry.key)).total, entry.value);
      });
    }

    test('kickers do not score', () {
      final result = _engine().scoreHand(_cards('10S 10H AS KD 8C'));
      expect(result.handType, HandType.pair);
      expect(result.scoringFlags, <bool>[true, true, false, false, false]);
      expect(result.scoringCount, 2);
      expect(result.total, 35);
    });

    test('Frostbite excludes Ace and picks the live King', () {
      final engine = _engine(modifier: HeatModifier.frostbite);
      final result = engine.scoreHand(_cards('AS KH'));
      expect(result.scoringFlags, <bool>[false, true]);
      expect(result.total, 14);
    });

    test(
      'additive Mult resolves before xMult and Dead Air only blocks xMult',
      () {
        final normal = _engine(jokers: const <String>['copper', 'polish']);
        final normalScore = normal.scoreHand(_cards('10S 10H'));
        expect(normalScore.multiplier, closeTo(1.82, 1e-12));
        expect(normalScore.total, 58);

        final fog = _engine(
          jokers: const <String>['copper', 'polish'],
          modifier: HeatModifier.deadAir,
        );
        final fogScore = fog.scoreHand(_cards('10S 10H'));
        expect(fogScore.multiplier, closeTo(1.30, 1e-12));
        expect(fogScore.total, 42);
      },
    );

    test('Neon then Joker addMult then Joker xMult then Glass', () {
      final cards = _cards('10S 10H');
      cards[0] = cards[0].copyWith(enhancement: CardEnhancement.neon);
      cards[1] = cards[1].copyWith(enhancement: CardEnhancement.glass);
      final result = _engine(
        jokers: const <String>['copper', 'polish'],
      ).scoreHand(cards);
      expect(result.multiplier, closeTo(3.15, 1e-12));
      expect(result.total, 101);
      expect(
        result.events
            .where(
              (event) =>
                  event.type == ScoreEventType.mult ||
                  event.type == ScoreEventType.xMult,
            )
            .map((event) => event.label),
        <String>['NEON +0.20', '+0.20 Mult', '×1.4', 'GLASS ×1.5'],
      );
    });

    test('Null Field leaves rank scoring but disables every Mult source', () {
      final cards = _cards('10S 10H');
      cards[0] = cards[0].copyWith(enhancement: CardEnhancement.neon);
      cards[1] = cards[1].copyWith(enhancement: CardEnhancement.glass);
      final result = _engine(
        jokers: const <String>['copper', 'polish'],
        modifier: HeatModifier.nullField,
      ).scoreHand(cards);
      expect(result.valuePoints, 32);
      expect(result.multiplier, 1.1);
      expect(result.total, 35);
      expect(
        result.events.where(
          (event) =>
              event.type == ScoreEventType.mult ||
              event.type == ScoreEventType.xMult,
        ),
        isEmpty,
      );
    });

    test('Echo applies after Mult and stacks with Null Field', () {
      final result = _engine(
        jokers: const <String>['copper', 'polish'],
        modifiers: const <HeatModifier>[
          HeatModifier.nullField,
          HeatModifier.echoChamber,
        ],
        previousHandType: HandType.pair,
      ).scoreHand(_cards('10S 10H'));
      expect(result.multiplier, closeTo(0.55, 1e-12));
      expect(result.total, 18);
      expect(result.events.last.label, 'ECHO ×0.5');
    });

    test('Counterfeit copied cards score zero rank', () {
      final cards = _cards('AS KH');
      cards[0] = cards[0].copyWith(copied: true);
      final result = _engine(
        modifier: HeatModifier.counterfeit,
      ).scoreHand(cards);
      expect(result.scoringFlags, <bool>[false, true]);
      expect(result.total, 14);
    });

    test('Level Lock ignores Hand Boost levels for this Heat', () {
      final unlocked = _engine(
        handLevels: <HandType, int>{HandType.pair: 5},
      ).scoreHand(_cards('10S 10H'));
      final locked = _engine(
        modifier: HeatModifier.levelLock,
        handLevels: <HandType, int>{HandType.pair: 5},
      ).scoreHand(_cards('10S 10H'));
      expect(unlocked.base, 95);
      expect(locked.base, 20);
      expect(locked.total, 35);
    });

    test('Lucky Seven preview consumes no luck; commit consumes one value', () {
      final state = ScoringState(
        rngSeed: dailySeed('2026-07-21'),
        jokerIds: <String>['lucky7'],
      );
      final engine = WildcardScoringEngine(state);
      engine.scoreHand(_cards('7S'), commit: false);
      expect(state.rngCounters[RandomStream.luck], 0);
      final committed = engine.scoreHand(_cards('7S'), commit: true);
      expect(state.rngCounters[RandomStream.luck], 1);
      expect(
        committed.events.where((event) => event.type == ScoreEventType.seven),
        hasLength(1),
      );
    });

    test('Pair Trainer changes only future hands', () {
      final state = ScoringState(rngSeed: 1, jokerIds: <String>['trainer']);
      final engine = WildcardScoringEngine(state);
      final first = engine.scoreHand(_cards('10S 10H'));
      expect(first.multiplier, 1.1);
      engine.applyOnScored(first);
      final second = engine.scoreHand(_cards('9S 9H'));
      expect(second.multiplier, closeTo(1.15, 1e-12));
    });
  });

  group('special Joker and Boss parity', () {
    test('The Cheat chooses the maximum final score five-card subset', () {
      final cards = _cards('AS AH AD KC KD 2S');
      final cheat = _engine(jokers: const <String>['cheat']);
      final six = cheat.scoreHand(cards);
      final subsetScores = <int>[
        for (var skip = 0; skip < 6; skip++)
          cheat.scoreHand(<PlayingCard>[
            for (var index = 0; index < 6; index++)
              if (index != skip) cards[index],
          ]).total,
      ];
      expect(six.total, subsetScores.reduce(mathMax));
      expect(six.handType, HandType.fullHouse);
    });

    test(
      'Prism Lens triggers with five matching colours plus one off-colour',
      () {
        final engine = _engine(jokers: const <String>['cheat', 'prism_lens']);
        final fiveRedOneBlack = _cards('2H 3D 4H 5D 6H AS');
        expect(
          engine.scoreHand(fiveRedOneBlack).multiplier,
          closeTo(1.485, 1e-12),
        );
      },
    );

    test(
      'THE HOUSE selects and persists exactly two unique blocked Jokers',
      () {
        final state = ScoringState(
          rngSeed: dailySeed('2026-07-21'),
          modifier: HeatModifier.theHouse,
          jokerIds: <String>['copper', 'polish', 'roller', 'wire', 'trainer'],
        );
        final engine = WildcardScoringEngine(state);
        final first = engine.ensureBossBlocks();
        final counterAfterFirst = state.rngCounters[RandomStream.boss];
        final second = engine.ensureBossBlocks();
        expect(first, hasLength(2));
        expect(first.toSet(), hasLength(2));
        expect(second, first);
        expect(state.rngCounters[RandomStream.boss], counterAfterFirst);
      },
    );

    test(
      'Glass Joystick always survives first clear then uses one-in-six stream',
      () {
        final state = ScoringState(
          rngSeed: 1,
          jokerIds: <String>['glass_joystick'],
        );
        final engine = WildcardScoringEngine(state);
        engine.applyHeatClearJokerHooks();
        expect(state.jokerIds, contains('glass_joystick'));
        expect(state.jokerState['glass_joystick_armed'], 1);
        expect(state.rngCounters[RandomStream.luck], 0);
        engine.applyHeatClearJokerHooks();
        expect(state.rngCounters[RandomStream.luck], 1);
      },
    );

    test('Glass card uses 20% luck roll and never crosses 24-card floor', () {
      final deck = baseCardSet().take(25).toList();
      deck[0] = deck[0].copyWith(enhancement: CardEnhancement.glass);
      final state = ScoringState(rngSeed: 1, cards: deck);
      final engine = WildcardScoringEngine(state);
      final first = engine.resolveGlassCardShatters(
        <PlayingCard>[deck[0]],
        const <bool>[true],
      );
      expect(first.shattered, 1);
      expect(state.cards, hasLength(minimumDeckSize));
      expect(state.shatteredCount, 1);
      expect(state.rngCounters[RandomStream.luck], 1);

      final glassAtFloor = state.cards.first.copyWith(
        enhancement: CardEnhancement.glass,
      );
      state.cards[0] = glassAtFloor;
      final second = engine.resolveGlassCardShatters(
        <PlayingCard>[glassAtFloor],
        const <bool>[true],
      );
      expect(second.shattered, 0);
      expect(state.cards, hasLength(minimumDeckSize));
      expect(state.rngCounters[RandomStream.luck], 1);
    });
  });
}

WildcardScoringEngine _engine({
  List<String> jokers = const <String>[],
  HeatModifier? modifier,
  Iterable<HeatModifier>? modifiers,
  HandType? previousHandType,
  Map<HandType, int>? handLevels,
}) {
  return WildcardScoringEngine(
    ScoringState(
      rngSeed: 1,
      jokerIds: List<String>.from(jokers),
      modifier: modifier,
      modifierStack: modifiers,
      previousHandType: previousHandType,
      handLevels: handLevels,
    ),
  );
}

List<PlayingCard> _cards(String description) => description
    .split(RegExp(r'\s+'))
    .where((token) => token.isNotEmpty)
    .map((token) {
      final suit = CardSuit.values.firstWhere(
        (value) => switch (token[token.length - 1]) {
          'S' => value == CardSuit.spades,
          'H' => value == CardSuit.hearts,
          'D' => value == CardSuit.diamonds,
          'C' => value == CardSuit.clubs,
          _ => false,
        },
      );
      final rank = CardRank.fromLabel(token.substring(0, token.length - 1));
      return PlayingCard(rank: rank, suit: suit);
    })
    .toList();

int mathMax(int a, int b) => a > b ? a : b;

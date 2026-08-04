import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/scoring_engine.dart';

void main() {
  group('LevelScoringOverride rank phase', () {
    test('face ranks contribute zero but still form the detected hand', () {
      final result = _engine(
        LevelScoringOverride(faceRanksScoreZero: true),
      ).scoreHand(_cards('JS JH'));

      expect(result.handType, HandType.pair);
      expect(result.scoringFlags, <bool>[true, true]);
      expect(result.rankSum, 0);
      expect(result.valuePoints, handBasePoints[HandType.pair]);
      expect(result.total, 22);
      expect(
        result.events.where((event) => event.label == 'FACE RANK · 0'),
        hasLength(2),
      );
    });

    test('red-only and black-only rules suppress the opposite colour', () {
      final redOnly = _engine(
        LevelScoringOverride(scoringColor: LevelRankColor.red),
      ).scoreHand(_cards('10H 10S'));
      final blackOnly = _engine(
        LevelScoringOverride(scoringColor: LevelRankColor.black),
      ).scoreHand(_cards('10H 10S'));

      expect(redOnly.handType, HandType.pair);
      expect(redOnly.rankSum, 10);
      expect(redOnly.total, 29);
      expect(
        redOnly.events.any((event) => event.label == 'RED CARDS ONLY · 0'),
        isTrue,
      );
      expect(blackOnly.rankSum, 10);
      expect(blackOnly.total, 29);
      expect(
        blackOnly.events.any((event) => event.label == 'BLACK CARDS ONLY · 0'),
        isTrue,
      );
    });

    test('colour factors are applied and narrated inside the rank phase', () {
      final result = _engine(
        LevelScoringOverride(redRankFactor: 1.5, blackRankFactor: 0.5),
      ).scoreHand(_cards('9H 9D'));

      expect(result.handType, HandType.pair);
      expect(result.perCard, <int>[14, 14]);
      expect(result.rankSum, 28);
      expect(result.rankScore, 17);
      expect(result.total, 41);
      expect(
        result.events.where(
          (event) => event.label?.startsWith('RED ×1.5') ?? false,
        ),
        hasLength(2),
      );
    });

    test('High Card chooses the greatest effective Level rank', () {
      final result = _engine(
        LevelScoringOverride(redRankFactor: 1.5, blackRankFactor: 0.5),
      ).scoreHand(_cards('9H 10S'));

      expect(result.handType, HandType.highCard);
      expect(result.scoringFlags, <bool>[true, false]);
      expect(result.rankSum, 14);
      expect(result.total, 14);
    });

    test('the visible disabled suit contributes zero rank', () {
      final result = _engine(
        LevelScoringOverride(disabledSuit: CardSuit.spades),
      ).scoreHand(_cards('AS AH'));

      expect(result.handType, HandType.pair);
      expect(result.scoringFlags, <bool>[true, true]);
      expect(result.perCard, <int>[0, 15]);
      expect(result.rankSum, 15);
      expect(
        result.events.any((event) => event.label == 'SPADES DISABLED · 0'),
        isTrue,
      );
    });
  });

  group('LevelScoringOverride final score phase', () {
    test('High Card zero does not change hand detection', () {
      final result = _engine(
        LevelScoringOverride(highCardScoresZero: true),
      ).scoreHand(_cards('AS KD 8C'));

      expect(result.handType, HandType.highCard);
      expect(result.total, 0);
      expect(result.multiplier, 0);
      expect(result.events.last.label, 'LEVEL RULE · HIGH CARD ×0');
    });

    test('only allowed hand types score', () {
      final result = _engine(
        LevelScoringOverride(
          allowedHandTypes: const <HandType>{HandType.pair, HandType.twoPair},
        ),
      ).scoreHand(_cards('2S 3D 4C 5H 6S'));

      expect(result.handType, HandType.straight);
      expect(result.total, 0);
      expect(result.events.last.label, 'LEVEL RULE · HAND NOT ALLOWED ×0');
    });

    test('repeat decay compounds from immutable prior hand counts', () {
      final firstRepeat = _engine(
        LevelScoringOverride(
          repeatDecay: 0.4,
          previousHandCounts: const <HandType, int>{HandType.pair: 1},
        ),
      ).scoreHand(_cards('10S 10H'));
      final secondRepeat = _engine(
        LevelScoringOverride(
          repeatDecay: 0.4,
          previousHandCounts: const <HandType, int>{HandType.pair: 2},
        ),
      ).scoreHand(_cards('10S 10H'));

      expect(firstRepeat.multiplier, closeTo(0.66, 1e-12));
      expect(firstRepeat.total, 21);
      expect(firstRepeat.events.last.label, 'REPEAT DECAY ×0.6');
      expect(secondRepeat.multiplier, closeTo(0.396, 1e-12));
      expect(secondRepeat.total, 13);
      expect(secondRepeat.events.last.label, 'REPEAT DECAY ×0.36');
    });

    test('no-repeat scores a repeated detected hand at zero', () {
      final result = _engine(
        LevelScoringOverride(
          repeatedHandsScoreZero: true,
          previousHandCounts: const <HandType, int>{HandType.pair: 1},
        ),
      ).scoreHand(_cards('10S 10H'));

      expect(result.handType, HandType.pair);
      expect(result.total, 0);
      expect(result.events.last.label, 'LEVEL RULE · NO REPEAT ×0');
    });

    test(
      'zero-based play factor applies after the normal scoring pipeline',
      () {
        final result = _engine(
          LevelScoringOverride(
            playIndex: 4,
            perPlayScoreFactors: const <double>[0.75, 0.75, 0.75, 0.75, 2],
          ),
        ).scoreHand(_cards('10S 10H'));

        expect(result.multiplier, closeTo(2.2, 1e-12));
        expect(result.total, 70);
        expect(result.events.last.label, 'PLAY 5 ×2.0');
      },
    );
  });

  test('preview and commit apply identical deterministic Level rules', () {
    final override = LevelScoringOverride(
      faceRanksScoreZero: true,
      redRankFactor: 1.5,
      blackRankFactor: 0.5,
      repeatDecay: 0.35,
      previousHandCounts: const <HandType, int>{HandType.pair: 1},
      playIndex: 1,
      perPlayScoreFactors: const <double>[0.75, 2],
    );
    final engine = _engine(override);
    final preview = engine.scoreHand(_cards('KH KS'), commit: false);
    final committed = engine.scoreHand(_cards('KH KS'), commit: true);

    expect(_snapshot(preview), _snapshot(committed));
  });

  test('null override preserves representative Arcade score snapshots', () {
    final cases = <String>['AS', '10S 10H', '2S 3D 4C 5H 6S'];
    for (final cards in cases) {
      final expected = WildcardScoringEngine(
        ScoringState(rngSeed: 42),
      ).scoreHand(_cards(cards));
      final explicitNull = WildcardScoringEngine(
        ScoringState(rngSeed: 42),
        levelOverride: null,
      ).scoreHand(_cards(cards));
      expect(_snapshot(explicitNull), _snapshot(expected), reason: cards);
    }
  });

  test('override collections are defensive immutable snapshots', () {
    final allowed = <HandType>{HandType.pair};
    final counts = <HandType, int>{HandType.pair: 1};
    final factors = <double>[0.5];
    final override = LevelScoringOverride(
      allowedHandTypes: allowed,
      previousHandCounts: counts,
      perPlayScoreFactors: factors,
    );

    allowed.add(HandType.flush);
    counts[HandType.pair] = 99;
    factors[0] = 9;
    expect(override.allowedHandTypes, const <HandType>{HandType.pair});
    expect(override.previousCount(HandType.pair), 1);
    expect(override.perPlayFactor, 0.5);
    expect(
      () => override.allowedHandTypes.add(HandType.flush),
      throwsUnsupportedError,
    );
  });

  test('authored modifier metadata powers Level Jokers without Heat rules', () {
    final state = ScoringState(
      rngSeed: 42,
      jokerIds: <String>['chaos_theory', 'modded', 'survivor', 'storm_harness'],
    );
    final engine = WildcardScoringEngine(
      state,
      levelOverride: LevelScoringOverride(
        hasAuthoredModifier: true,
        authoredModifierCount: 2,
      ),
    );

    final result = engine.scoreHand(_cards('AS'));
    expect(
      state.modifiers,
      isEmpty,
      reason: 'no fake Heat rules are installed',
    );
    expect(result.multiplier, closeTo(8.82, 1e-12));
    expect(result.total, 123);

    state.jokerIds
      ..clear()
      ..add('safe_cracker');
    engine.applyHeatClearJokerHooks();
    expect(state.jokerState['safecrack'], 2);
  });
}

WildcardScoringEngine _engine(LevelScoringOverride override) =>
    WildcardScoringEngine(ScoringState(rngSeed: 42), levelOverride: override);

List<Object?> _snapshot(ScoreResult result) => <Object?>[
  result.handType,
  result.base,
  result.rankSum,
  result.rankScore,
  result.valuePoints,
  result.multiplier,
  result.total,
  result.perCard,
  result.scoringFlags,
  for (final event in result.events)
    <Object?>[
      event.type,
      event.cardIndex,
      event.jokerIndex,
      event.label,
      event.amount,
      event.multiplier,
      event.hit,
    ],
];

List<PlayingCard> _cards(String description) => description
    .split(RegExp(r'\s+'))
    .where((token) => token.isNotEmpty)
    .map((token) {
      final suit = switch (token[token.length - 1]) {
        'S' => CardSuit.spades,
        'H' => CardSuit.hearts,
        'D' => CardSuit.diamonds,
        'C' => CardSuit.clubs,
        final value => throw FormatException('Unknown suit: $value'),
      };
      return PlayingCard(
        rank: CardRank.fromLabel(token.substring(0, token.length - 1)),
        suit: suit,
      );
    })
    .toList();

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/random_streams.dart';
import 'package:wildcard/domain/scoring_engine.dart';

void main() {
  group('new rank and position Jokers', () {
    final rankCases = <({String joker, String cards, int expectedRankSum})>[
      (joker: 'ice_pick', cards: 'AD', expectedRankSum: 19),
      (joker: 'union_boss', cards: 'AC', expectedRankSum: 19),
      (joker: 'gravedigger', cards: 'AS', expectedRankSum: 19),
      (joker: 'rose_tint', cards: 'AH', expectedRankSum: 18),
      (joker: 'odd_job', cards: '7S', expectedRankSum: 10),
      (joker: 'prime_time', cards: '5H', expectedRankSum: 9),
      (joker: 'kingpin', cards: 'KS', expectedRankSum: 21),
    ];

    for (final testCase in rankCases) {
      test('${testCase.joker} adds its exact rank amount', () {
        final result = _engine(
          jokers: <String>[testCase.joker],
        ).scoreHand(_cards(testCase.cards));
        expect(result.rankSum, testCase.expectedRankSum);
      });
    }

    test('Glazier makes a scoring Glass card worth three times rank', () {
      final glassTen = _cards(
        '10S',
      ).single.copyWith(enhancement: CardEnhancement.glass);
      final result = _engine(
        jokers: const <String>['glazier'],
      ).scoreHand(<PlayingCard>[glassTen]);
      expect(result.rankSum, 30);
      expect(result.perCard, <int>[30]);
    });

    test('Leadoff adds six only to the first scoring card', () {
      final result = _engine(
        jokers: const <String>['leadoff'],
      ).scoreHand(_cards('10S 10H'));
      expect(result.rankSum, 26);
      expect(result.perCard, <int>[16, 10]);
    });

    test('Leadoff advances past a rank-suppressed scoring card', () {
      final result = _engine(
        jokers: const <String>['leadoff'],
        modifiers: const <HeatModifier>[HeatModifier.frostbite],
      ).scoreHand(_cards('10S 10H'));
      expect(result.scoringFlags, <bool>[true, true]);
      expect(result.rankSum, 16);
      expect(result.perCard, <int>[0, 16]);
    });

    test('Closer triples only the last scoring card rank', () {
      final result = _engine(
        jokers: const <String>['closer'],
      ).scoreHand(_cards('10S 10H'));
      expect(result.rankSum, 40);
      expect(result.perCard, <int>[10, 30]);
    });
  });

  group('new hand-shape and threshold multiplier Jokers', () {
    final shapeCases = <({String joker, String cards, double factor})>[
      (joker: 'twin_flame', cards: '9S 9H', factor: 1.5),
      (joker: 'trident', cards: '9S 9H 2D', factor: 1.7),
      (joker: 'quartet', cards: '9S 9H 2D 3C', factor: 1.6),
      (joker: 'face_value', cards: 'KS', factor: 1.5),
      (joker: 'ace_in_the_hole', cards: 'AS', factor: 1.6),
      (joker: 'rainbow', cards: '2S 4H 7D', factor: 1.8),
    ];

    for (final testCase in shapeCases) {
      test('${testCase.joker} triggers at its advertised factor', () {
        final result = _engine(
          jokers: <String>[testCase.joker],
        ).scoreHand(_cards(testCase.cards));
        expect(_jokerXFactor(result), closeTo(testCase.factor, 1e-12));
      });
    }

    test('Underdog triggers strictly below forty percent of target', () {
      final active = _engine(
        jokers: const <String>['underdog'],
        stageScore: 35,
      ).scoreHand(_cards('5S'));
      expect(_jokerXFactor(active), 2);

      final boundary = _engine(
        jokers: const <String>['underdog'],
        stageScore: 36,
      ).scoreHand(_cards('5S'));
      expect(_jokerXEvents(boundary), isEmpty);
    });

    test('Frontrunner triggers strictly above eighty percent of target', () {
      final active = _engine(
        jokers: const <String>['frontrunner'],
        stageScore: 73,
      ).scoreHand(_cards('5S'));
      expect(_jokerXFactor(active), 1.6);

      final boundary = _engine(
        jokers: const <String>['frontrunner'],
        stageScore: 72,
      ).scoreHand(_cards('5S'));
      expect(_jokerXEvents(boundary), isEmpty);
    });

    test('Marathoner adds 0.20 Mult per remaining play', () {
      final result = _engine(
        jokers: const <String>['marathoner'],
        handsLeft: 4,
      ).scoreHand(_cards('5S'));
      expect(_jokerAddAmount(result), closeTo(0.8, 1e-12));
      expect(result.multiplier, closeTo(1.9, 1e-12));
    });
  });

  group('new stateful Jokers', () {
    test('Metronome grows only across consecutive matching hand types', () {
      final state = _state(jokers: const <String>['metronome']);
      final engine = WildcardScoringEngine(state);

      final first = engine.scoreHand(_cards('10S 10H'));
      expect(_jokerAddEvents(first), isEmpty);
      engine.applyOnScored(first);

      final second = engine.scoreHand(_cards('9S 9H'));
      expect(_jokerAddAmount(second), closeTo(0.3, 1e-12));
      engine.applyOnScored(second);

      final third = engine.scoreHand(_cards('8S 8H'));
      expect(_jokerAddAmount(third), closeTo(0.6, 1e-12));
      engine.applyOnScored(third);

      final changed = engine.scoreHand(_cards('AS'));
      expect(_jokerAddEvents(changed), isEmpty);
    });

    test('Perfectionist stops before the first changed-type hand scores', () {
      final state = _state(jokers: const <String>['perfectionist']);
      final engine = WildcardScoringEngine(state);

      final first = engine.scoreHand(_cards('10S 10H'));
      expect(_jokerXFactor(first), 2.5);
      engine.applyOnScored(first);

      final changed = engine.scoreHand(_cards('AS'));
      expect(_jokerXEvents(changed), isEmpty);
      engine.applyOnScored(changed);
      expect(state.jokerState['perfect'], 0);

      final later = engine.scoreHand(_cards('KS'));
      expect(_jokerXEvents(later), isEmpty);
    });

    test('Comboist counts each distinct hand type once', () {
      final state = _state(jokers: const <String>['comboist']);
      final engine = WildcardScoringEngine(state);

      final pair = engine.scoreHand(_cards('10S 10H'));
      expect(_jokerAddAmount(pair), closeTo(0.15, 1e-12));
      engine.applyOnScored(pair);

      final high = engine.scoreHand(_cards('AS'));
      expect(_jokerAddAmount(high), closeTo(0.30, 1e-12));
      engine.applyOnScored(high);

      final anotherHigh = engine.scoreHand(_cards('KS'));
      expect(_jokerAddAmount(anotherHigh), closeTo(0.30, 1e-12));
    });

    test('per-Heat reset restores all three stateful contracts', () {
      final state = _state(
        jokers: const <String>['metronome', 'perfectionist', 'comboist'],
        jokerState: <String, double>{
          'metronome': 9,
          'perfect': 0,
          'combo': 255,
          'safecrack': 4,
        },
      );
      WildcardScoringEngine(state).prepareHeatJokerState();
      expect(state.jokerState, containsPair('metronome', 0));
      expect(state.jokerState, containsPair('perfect', 1));
      expect(state.jokerState, containsPair('combo', 0));
      expect(
        state.jokerState['safecrack'],
        4,
        reason: 'run-scoped state must survive a Heat reset',
      );
    });
  });

  group('enhancement, deck, and held-Joker synergies', () {
    test('Goldsmith detects any Gilded played card', () {
      final gilded = _cards(
        '8S',
      ).single.copyWith(enhancement: CardEnhancement.gild);
      final result = _engine(
        jokers: const <String>['goldsmith'],
      ).scoreHand(<PlayingCard>[gilded]);
      expect(_jokerXFactor(result), 1.5);
    });

    test('Neon Dealer adds 0.40 in addition to intrinsic Neon Mult', () {
      final neon = _cards(
        '8S',
      ).single.copyWith(enhancement: CardEnhancement.neon);
      final result = _engine(
        jokers: const <String>['neon_dealer'],
      ).scoreHand(<PlayingCard>[neon]);
      expect(_jokerAddAmount(result), closeTo(0.4, 1e-12));
      expect(result.multiplier, closeTo(1.7, 1e-12));
    });

    test('Wild Whisperer compounds once per Wild-suit card', () {
      final cards = _cards('8S 8H')
          .map((card) => card.copyWith(enhancement: CardEnhancement.wildsuit))
          .toList();
      final result = _engine(
        jokers: const <String>['wild_whisperer'],
      ).scoreHand(cards);
      expect(_jokerXFactor(result), closeTo(1.35 * 1.35, 1e-12));
    });

    test('Purist requires every played card to be unenhanced', () {
      final plain = _engine(
        jokers: const <String>['purist'],
      ).scoreHand(_cards('8S'));
      expect(_jokerXFactor(plain), 1.6);

      final gilded = _cards(
        '8S',
      ).single.copyWith(enhancement: CardEnhancement.gild);
      final enhanced = _engine(
        jokers: const <String>['purist'],
      ).scoreHand(<PlayingCard>[gilded]);
      expect(_jokerXEvents(enhanced), isEmpty);
    });

    test('Hoarder counts only deck cards above forty', () {
      final result = _engine(
        jokers: const <String>['hoarder'],
        deck: baseCardSet().take(42).toList(),
      ).scoreHand(_cards('8S'));
      expect(_jokerAddAmount(result), closeTo(0.06, 1e-12));
    });

    test('Monochrome includes the exact sixty-percent boundary', () {
      final deck = <PlayingCard>[
        ...baseCardSet().where((card) => card.isRed).take(6),
        ...baseCardSet().where((card) => !card.isRed).take(4),
      ];
      final result = _engine(
        jokers: const <String>['monochrome'],
        deck: deck,
      ).scoreHand(_cards('8S'));
      expect(_jokerXFactor(result), 1.7);
    });

    test('Twin Study requires four ranks with at least two copies', () {
      final fourPairs = _engine(
        jokers: const <String>['twin_study'],
        deck: _cards('2S 2H 3S 3H 4S 4H 5S 5H'),
      ).scoreHand(_cards('8S'));
      expect(_jokerXFactor(fourPairs), 1.4);

      final threePairs = _engine(
        jokers: const <String>['twin_study'],
        deck: _cards('2S 2H 3S 3H 4S 4H 5S'),
      ).scoreHand(_cards('8S'));
      expect(_jokerXEvents(threePairs), isEmpty);

      final untouchedDeck = _engine(
        jokers: const <String>['twin_study'],
        deck: baseCardSet(),
      ).scoreHand(_cards('8S'));
      expect(_jokerXFactor(untouchedDeck), 1.4);
    });

    test('Ensemble includes itself in held-Joker count', () {
      final result = _engine(
        jokers: const <String>['ensemble', 'gap_filler', 'two_faced'],
      ).scoreHand(_cards('8S'));
      expect(_jokerAddAmount(result, jokerIndex: 0), closeTo(0.36, 1e-12));
    });

    test('Rarity Hunter follows live catalogue rarities', () {
      final raritySupport = jokerCatalog
          .where(
            (joker) =>
                joker.id != 'rarity_hunter' &&
                (joker.rarity == JokerRarity.rare ||
                    joker.rarity == JokerRarity.wild),
          )
          .take(3)
          .map((joker) => joker.id)
          .toList();
      final held = <String>['rarity_hunter', ...raritySupport];
      final premiumCount = held.where((id) {
        final rarity = jokersById[id]!.rarity;
        return rarity == JokerRarity.rare || rarity == JokerRarity.wild;
      }).length;
      expect(premiumCount, greaterThan(0));

      final result = _engine(jokers: held).scoreHand(_cards('8S'));
      expect(
        _jokerXFactor(result, jokerIndex: 0),
        closeTo(math.pow(1.25, premiumCount).toDouble(), 1e-12),
      );
    });

    test('Warm-Up applies only to the first hand of a Heat', () {
      final first = _engine(
        jokers: const <String>['warm_up'],
      ).scoreHand(_cards('8S'));
      expect(_jokerAddAmount(first), closeTo(0.6, 1e-12));

      final later = _engine(
        jokers: const <String>['warm_up'],
        handsPlayedThisStage: 1,
      ).scoreHand(_cards('8S'));
      expect(_jokerAddEvents(later), isEmpty);
    });
  });

  group('risk and modifier Jokers', () {
    test('Overclock is x2.4 and removes exactly one play per Heat', () {
      final state = _state(jokers: const <String>['overclock']);
      final result = WildcardScoringEngine(state).scoreHand(_cards('8S'));
      expect(_jokerXFactor(result), 2.4);
      expect(state.effectiveHandsPerHeat, handsPerHeat - 1);
    });

    test('Roulette preview is pure and commit is seed-deterministic', () {
      final firstState = _state(
        seed: dailySeed('2026-07-27'),
        jokers: const <String>['roulette'],
      );
      final firstEngine = WildcardScoringEngine(firstState);

      final preview = firstEngine.scoreHand(_cards('8S'), commit: false);
      expect(firstState.rngCounters[RandomStream.luck], 0);
      expect(_jokerXFactor(preview), closeTo(1.55, 1e-12));

      final committed = firstEngine.scoreHand(_cards('8S'), commit: true);
      expect(firstState.rngCounters[RandomStream.luck], 1);
      expect(_jokerXFactor(committed), anyOf(2.5, 0.6));

      final repeatState = _state(
        seed: dailySeed('2026-07-27'),
        jokers: const <String>['roulette'],
      );
      final repeated = WildcardScoringEngine(
        repeatState,
      ).scoreHand(_cards('8S'), commit: true);
      expect(repeated.total, committed.total);
      expect(repeated.multiplier, committed.multiplier);
      expect(repeatState.rngCounters[RandomStream.luck], 1);
    });

    test('Blood Money spends one run coin only when post-score hook runs', () {
      final state = _state(jokers: const <String>['blood_money'], runCoins: 5);
      final engine = WildcardScoringEngine(state);
      final result = engine.scoreHand(_cards('8S'));
      expect(_jokerXFactor(result), 1.8);
      expect(state.runCoins, 5);
      engine.applyOnScored(result);
      expect(state.runCoins, 4);

      state.runCoins = 0;
      final broke = engine.scoreHand(_cards('7S'));
      expect(_jokerXFactor(broke), 1.8);
      engine.applyOnScored(broke);
      expect(state.runCoins, 0);
    });

    test('Fragile Genius destroys itself after a lower-scoring hand', () {
      final state = _state(jokers: const <String>['fragile_genius']);
      final engine = WildcardScoringEngine(state);
      final high = engine.scoreHand(_cards('AS AH'));
      expect(_jokerXFactor(high), 4);
      engine.applyOnScored(high);
      expect(state.jokerIds, contains('fragile_genius'));

      final low = engine.scoreHand(_cards('2S'));
      engine.applyOnScored(low);
      expect(state.jokerIds, isNot(contains('fragile_genius')));
      expect(state.jokerState, isNot(contains('fragile')));
    });

    test('High Wire requires both zero discards and one play left', () {
      final active = _engine(
        jokers: const <String>['high_wire'],
        handsLeft: 1,
        discardsLeft: 0,
      ).scoreHand(_cards('8S'));
      expect(_jokerXFactor(active), 2.2);

      final hasDiscard = _engine(
        jokers: const <String>['high_wire'],
        handsLeft: 1,
        discardsLeft: 1,
      ).scoreHand(_cards('8S'));
      expect(_jokerXEvents(hasDiscard), isEmpty);
    });

    test('Chaos Theory counts every stacked active modifier', () {
      final result = _engine(
        jokers: const <String>['chaos_theory'],
        modifiers: const <HeatModifier>[HeatModifier.cold, HeatModifier.famine],
      ).scoreHand(_cards('8S'));
      expect(_jokerAddAmount(result), closeTo(1, 1e-12));
    });

    test('Rule Breaker triggers only during THE HOUSE', () {
      final boss = _engine(
        jokers: const <String>['rule_breaker'],
        modifiers: const <HeatModifier>[HeatModifier.theHouse],
      ).scoreHand(_cards('8S'));
      expect(_jokerXFactor(boss), 2.2);

      final normal = _engine(
        jokers: const <String>['rule_breaker'],
      ).scoreHand(_cards('8S'));
      expect(_jokerXEvents(normal), isEmpty);
    });

    test('Safe Cracker increments once per survived modifier', () {
      final state = _state(
        jokers: const <String>['safe_cracker'],
        modifiers: const <HeatModifier>[HeatModifier.cold, HeatModifier.famine],
      );
      final engine = WildcardScoringEngine(state);
      engine.applyHeatClearJokerHooks();
      expect(state.jokerState['safecrack'], 2);
      final result = engine.scoreHand(_cards('8S'));
      expect(_jokerAddAmount(result), closeTo(0.7, 1e-12));
    });
  });

  group('structural Jokers', () {
    test('Gap Filler permits exactly one skipped rank in a Straight', () {
      final cards = _cards('2S 3D 5C 6H 7S');
      expect(_engine().evaluateHand(cards), HandType.highCard);
      expect(
        _engine(jokers: const <String>['gap_filler']).evaluateHand(cards),
        HandType.straight,
      );
    });

    test('Gap Filler does not extend short Straight rule-benders', () {
      expect(
        _engine(
          jokers: const <String>['gap_filler', 'shortcut'],
        ).evaluateHand(_cards('2S 4D 5C')),
        HandType.highCard,
      );
      expect(
        _engine(
          jokers: const <String>['gap_filler'],
          modifiers: const <HeatModifier>[HeatModifier.lowCeiling],
        ).evaluateHand(_cards('2S 3D 5C 6H')),
        HandType.highCard,
      );
    });

    test('Two-Faced gives Two Pair the Full House base', () {
      final result = _engine(
        jokers: const <String>['two_faced'],
      ).scoreHand(_cards('AS AD KC KD 2S'));
      expect(result.handType, HandType.twoPair);
      expect(result.base, handBasePoints[HandType.fullHouse]);
    });

    test('Understudy duplicates the highest card for hand detection only', () {
      final cards = _cards('AS KD 8C');
      final result = _engine(
        jokers: const <String>['understudy'],
      ).scoreHand(cards);
      expect(result.handType, HandType.pair);
      expect(result.scoringFlags, <bool>[false, false, false]);
      expect(result.rankSum, 0);
    });

    test('Understudy synthetic Full House excludes the unused kicker', () {
      final result = _engine(
        jokers: const <String>['understudy'],
      ).scoreHand(_cards('AS AH KD KC QS'));
      expect(result.handType, HandType.fullHouse);
      expect(result.scoringFlags, <bool>[true, true, true, true, false]);
      expect(result.rankSum, 56);
    });

    test(
      'Understudy preserves Four of a Kind at a synthetic count of five',
      () {
        final result = _engine(
          jokers: const <String>['understudy'],
        ).scoreHand(_cards('AS AH AD AC KS'));
        expect(result.handType, HandType.fourOfAKind);
        expect(result.scoringFlags, <bool>[true, true, true, true, false]);
        expect(result.rankSum, 60);
      },
    );

    test('Suit Swap turns four matching suits plus one card into a Flush', () {
      final cards = _cards('2S 5S 8S 10S KH');
      expect(_engine().evaluateHand(cards), HandType.highCard);
      expect(
        _engine(jokers: const <String>['suit_swap']).evaluateHand(cards),
        HandType.flush,
      );
    });

    test('Alchemist makes a 2 pair with an Ace and score as rank 15', () {
      final result = _engine(
        jokers: const <String>['alchemist'],
      ).scoreHand(_cards('2S AH 8C'));
      expect(result.handType, HandType.pair);
      expect(result.scoringFlags, <bool>[true, true, false]);
      expect(result.rankSum, 30);
      expect(result.perCard, <int>[15, 15, 0]);
    });
  });
}

WildcardScoringEngine _engine({
  int seed = 1,
  List<String> jokers = const <String>[],
  int stageScore = 0,
  int handsLeft = handsPerHeat,
  int discardsLeft = discardsPerHeat,
  int handsPlayedThisStage = 0,
  int runCoins = 0,
  List<PlayingCard>? deck,
  Iterable<HeatModifier>? modifiers,
  Map<String, double>? jokerState,
}) => WildcardScoringEngine(
  _state(
    seed: seed,
    jokers: jokers,
    stageScore: stageScore,
    handsLeft: handsLeft,
    discardsLeft: discardsLeft,
    handsPlayedThisStage: handsPlayedThisStage,
    runCoins: runCoins,
    deck: deck,
    modifiers: modifiers,
    jokerState: jokerState,
  ),
);

ScoringState _state({
  int seed = 1,
  List<String> jokers = const <String>[],
  int stageScore = 0,
  int handsLeft = handsPerHeat,
  int discardsLeft = discardsPerHeat,
  int handsPlayedThisStage = 0,
  int runCoins = 0,
  List<PlayingCard>? deck,
  Iterable<HeatModifier>? modifiers,
  Map<String, double>? jokerState,
}) => ScoringState(
  rngSeed: seed,
  jokerIds: jokers,
  stageScore: stageScore,
  handsLeft: handsLeft,
  discardsLeft: discardsLeft,
  handsPlayedThisStage: handsPlayedThisStage,
  runCoins: runCoins,
  cards: deck,
  modifierStack: modifiers,
  jokerState: jokerState,
);

Iterable<ScoreEvent> _jokerXEvents(ScoreResult result, {int jokerIndex = 0}) =>
    result.events.where(
      (event) =>
          event.type == ScoreEventType.xMult && event.jokerIndex == jokerIndex,
    );

double _jokerXFactor(ScoreResult result, {int jokerIndex = 0}) =>
    _jokerXEvents(result, jokerIndex: jokerIndex).single.amount.toDouble();

Iterable<ScoreEvent> _jokerAddEvents(
  ScoreResult result, {
  int jokerIndex = 0,
}) => result.events.where(
  (event) =>
      event.type == ScoreEventType.mult && event.jokerIndex == jokerIndex,
);

double _jokerAddAmount(ScoreResult result, {int jokerIndex = 0}) =>
    _jokerAddEvents(result, jokerIndex: jokerIndex).single.amount.toDouble();

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

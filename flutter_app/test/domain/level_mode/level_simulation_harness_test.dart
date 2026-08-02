import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/level_mode/level_definition.dart';
import 'package:wildcard/domain/level_mode/level_simulation_harness.dart';

void main() {
  const harness = LevelSimulationHarness();

  test('an exact route uses native scoring and objective completion', () {
    final level = _level();
    final route = LevelSolverRoute(
      levelId: level.id,
      layoutId: level.layouts.single.id,
      selectedJokerIds: const <String>[],
      actions: <LevelSimulationAction>[
        LevelPlayAction(
          const <String>['10S', '10H'],
          expectedHandType: HandType.pair,
          expectedScore: 35,
          expectedCumulativeScore: 35,
        ),
      ],
    );

    final result = harness.runRoute(
      level: level,
      layout: level.layouts.single,
      route: route,
    );

    expect(result.valid, isTrue);
    expect(result.cleared, isTrue);
    expect(result.objectiveComplete, isTrue);
    expect(result.totalScore, 35);
    expect(result.plays.single.handType, HandType.pair);
    expect(result.plays.single.score, 35);
  });

  test('routes reject unavailable cards instead of inventing a legal play', () {
    final level = _level();
    final result = harness.runRoute(
      level: level,
      layout: level.layouts.single,
      route: LevelSolverRoute(
        levelId: level.id,
        layoutId: level.layouts.single.id,
        selectedJokerIds: const <String>[],
        actions: <LevelSimulationAction>[
          LevelPlayAction(const <String>['AS']),
        ],
      ),
    );

    expect(result.outcome, LevelSimulationOutcome.invalid);
    expect(
      result.validationErrors.any((error) => error.contains('not in hand')),
      isTrue,
    );
  });

  test('discard tax raises the authoritative dynamic target', () {
    final level = _level(
      rules: _rules(hands: 1, discards: 1, discardTargetTax: 100),
      objective: _objective(target: 35),
      deck: const <String>['10S', '10H', '2C', '3D', '4S', '9C'],
    );
    final route = LevelSolverRoute(
      levelId: level.id,
      layoutId: level.layouts.single.id,
      selectedJokerIds: const <String>[],
      expectedCleared: false,
      actions: <LevelSimulationAction>[
        LevelDiscardAction(const <String>['2C']),
        LevelPlayAction(
          const <String>['10S', '10H'],
          expectedScore: 35,
          expectedCumulativeScore: 35,
        ),
      ],
    );

    final result = harness.runRoute(
      level: level,
      layout: level.layouts.single,
      route: route,
    );
    expect(result.valid, isTrue);
    expect(result.outcome, LevelSimulationOutcome.failed);
    expect(result.dynamicTarget, 135);
    expect(result.totalScore, 35);
    expect(result.discardsUsed, 1);
  });

  for (final policy in LevelSimulationPolicy.values) {
    test(
      '${policy.name} is deterministic and clears the simple Pair level',
      () {
        final level = _level(
          objective: _objective(
            target: 35,
            requiredCounts: const <HandType, int>{HandType.pair: 1},
          ),
        );
        final first = harness.runPolicy(
          level: level,
          layout: level.layouts.single,
          selectedJokerIds: const <String>[],
          policy: policy,
        );
        final second = harness.runPolicy(
          level: level,
          layout: level.layouts.single,
          selectedJokerIds: const <String>[],
          policy: policy,
        );

        expect(first.cleared, isTrue);
        expect(first.valid, isTrue);
        expect(first.totalScore, second.totalScore);
        expect(first.plays.single.cardCodes, second.plays.single.cardCodes);
        expect(first.plays.single.handType, HandType.pair);
      },
    );
  }

  test('missing solver artifact is explicit and never fabricates replay', () {
    final report = harness.replaySolverRoutes(
      levels: <LevelDefinition>[_level()],
    );

    expect(report.artifactAvailable, isFalse);
    expect(report.routesSupplied, 0);
    expect(report.routesPassed, 0);
    expect(report.results, isEmpty);
    expect(report.allRoutesPassed, isFalse);
    expect(report.unavailableReason, contains('was not supplied'));
  });

  test('supplied solver JSON replays and proves only covered layouts', () {
    final level = _level();
    final source = jsonEncode(<String, Object?>{
      'routes': <Object?>[
        <String, Object?>{
          'levelId': 1,
          'layoutId': 'L001-TEST',
          'selectedJokerIds': <String>[],
          'expectedCleared': true,
          'actions': <Object?>[
            <String, Object?>{
              'type': 'play',
              'cards': <String>['10S', '10H'],
              'expectedHandType': 'Pair',
              'expectedScore': 35,
              'expectedCumulativeScore': 35,
            },
          ],
        },
      ],
    });

    final report = harness.replaySolverRoutes(
      levels: <LevelDefinition>[level],
      solverRouteJson: source,
    );

    expect(report.artifactAvailable, isTrue);
    expect(report.routesSupplied, 1);
    expect(report.routesPassed, 1);
    expect(report.successfulLayoutKeys, const <String>{'1:L001-TEST'});
    expect(report.missingLayoutKeys, isEmpty);
    expect(report.allRoutesPassed, isTrue);
  });

  test('solver JSON requires every native score expectation', () {
    final source = jsonEncode(<String, Object?>{
      'routes': <Object?>[
        <String, Object?>{
          'levelId': 1,
          'layoutId': 'L001-TEST',
          'selectedJokerIds': <String>[],
          'actions': <Object?>[
            <String, Object?>{
              'type': 'play',
              'cards': <String>['10S', '10H'],
              'expectedHandType': 'Pair',
              'expectedScore': 35,
              // expectedCumulativeScore is deliberately absent.
            },
          ],
        },
      ],
    });

    expect(
      () => LevelSolverRouteBundle.fromJsonString(source),
      throwsFormatException,
    );
  });

  test('solver score mismatches are retained as validation evidence', () {
    final level = _level();
    final route = LevelSolverRoute(
      levelId: level.id,
      layoutId: level.layouts.single.id,
      selectedJokerIds: const <String>[],
      actions: <LevelSimulationAction>[
        LevelPlayAction(
          const <String>['10S', '10H'],
          expectedHandType: HandType.pair,
          expectedScore: 999,
          expectedCumulativeScore: 999,
        ),
      ],
    );

    final result = harness.runRoute(
      level: level,
      layout: level.layouts.single,
      route: route,
    );
    expect(result.outcome, LevelSimulationOutcome.invalid);
    expect(result.validationErrors, hasLength(2));
    expect(result.validationErrors.first, contains('expected 999, got 35'));
  });

  test(
    'campaign report aggregates chapters, failures, and loadout frequency',
    () {
      final first = _level(
        name: 'Mixed layouts',
        chapter: '1 · Basics',
        objective: _objective(target: 40),
        jokerOptionIds: const <String>['roller', 'trainer'],
        chooseJokers: 1,
        layouts: const <LevelLayout>[
          LevelLayout(
            id: 'L001-PAIR',
            seed: 1,
            hash: 'test',
            deckCodes: <String>['AS', 'AH', '2C', '4D', '7S'],
            recommendedJokerIds: <String>['roller'],
          ),
          LevelLayout(
            id: 'L001-HIGH',
            seed: 2,
            hash: 'test',
            deckCodes: <String>['2S', '3H', '4C', '7D', '9S'],
            recommendedJokerIds: <String>['trainer'],
          ),
        ],
        recommendedLoadouts: const <LevelRecommendedLoadout>[
          LevelRecommendedLoadout(
            jokerIds: <String>['roller'],
            jokerNames: <String>['High Roller'],
            layoutCount: 1,
          ),
          LevelRecommendedLoadout(
            jokerIds: <String>['trainer'],
            jokerNames: <String>['Pair Trainer'],
            layoutCount: 1,
          ),
        ],
      );
      final second = _level(
        id: 2,
        name: 'Second Pair',
        chapter: '1 · Basics',
        objective: _objective(target: 40),
        jokerOptionIds: const <String>['roller'],
        chooseJokers: 1,
        layouts: const <LevelLayout>[
          LevelLayout(
            id: 'L002-PAIR',
            seed: 3,
            hash: 'test',
            deckCodes: <String>['AS', 'AH', '2C', '4D', '7S'],
            recommendedJokerIds: <String>['roller'],
          ),
        ],
      );

      final report = harness.runCampaignPolicies(
        levels: <LevelDefinition>[first, second],
        policies: const <LevelSimulationPolicy>[
          LevelSimulationPolicy.handRanking,
        ],
      );

      expect(report.attempts, 3);
      expect(report.clears, 2);
      expect(report.clearRate, closeTo(2 / 3, 0.000001));
      expect(report.uniqueLayoutFailures, const <String>{'1:L001-HIGH'});
      expect(report.levels, hasLength(2));
      expect(report.levels.first.uniqueLayoutFailures, const <String>{
        'L001-HIGH',
      });
      expect(report.chapters, hasLength(1));
      expect(report.chapters.single.attempts, 3);
      expect(report.chapters.single.clears, 2);
      expect(report.chapters.single.levelIds, const <int>[1, 2]);

      final frequencies = report.chapters.single.recommendedLoadoutFrequency;
      expect(frequencies, hasLength(2));
      expect(frequencies.first.jokerIds, const <String>['roller']);
      expect(frequencies.first.attempts, 2);
      expect(frequencies.first.layoutCount, 2);
      expect(frequencies.last.jokerIds, const <String>['trainer']);
      expect(frequencies.last.attempts, 1);
      expect(frequencies.last.layoutCount, 1);
      expect(report.toJson()['levels'], hasLength(2));
    },
  );

  test('recommended selection has deterministic catalog fallbacks', () {
    final fromFrequency = _level(
      jokerOptionIds: const <String>['roller', 'trainer'],
      chooseJokers: 1,
      layouts: const <LevelLayout>[
        LevelLayout(
          id: 'L001-NO-EXACT',
          seed: 1,
          hash: 'test',
          deckCodes: <String>['AS', 'AH', '2C', '4D', '7S'],
          recommendedJokerIds: <String>[],
        ),
      ],
      recommendedLoadouts: const <LevelRecommendedLoadout>[
        LevelRecommendedLoadout(
          jokerIds: <String>['roller'],
          jokerNames: <String>['High Roller'],
          layoutCount: 1,
        ),
        LevelRecommendedLoadout(
          jokerIds: <String>['trainer'],
          jokerNames: <String>['Pair Trainer'],
          layoutCount: 2,
        ),
      ],
    );
    expect(
      harness.recommendedJokerSelectionFor(
        level: fromFrequency,
        layout: fromFrequency.layouts.single,
      ),
      const <String>['trainer'],
    );

    final fromOptions = _level(
      jokerOptionIds: const <String>['roller', 'trainer'],
      chooseJokers: 1,
      layouts: const <LevelLayout>[
        LevelLayout(
          id: 'L001-NO-RECOMMENDATION',
          seed: 1,
          hash: 'test',
          deckCodes: <String>['AS', 'AH', '2C', '4D', '7S'],
          recommendedJokerIds: <String>[],
        ),
      ],
    );
    expect(
      harness.recommendedJokerSelectionFor(
        level: fromOptions,
        layout: fromOptions.layouts.single,
      ),
      const <String>['roller'],
    );
  });
}

LevelDefinition _level({
  int id = 1,
  String name = 'Harness Pair',
  String chapter = 'Test',
  LevelRules? rules,
  LevelObjective? objective,
  List<String> deck = const <String>['10S', '10H', '2C', '3D', '4S'],
  List<String> fixedJokerIds = const <String>[],
  List<String> jokerOptionIds = const <String>[],
  int chooseJokers = 0,
  String? negativeJokerId,
  List<LevelLayout>? layouts,
  List<LevelRecommendedLoadout> recommendedLoadouts =
      const <LevelRecommendedLoadout>[],
}) => LevelDefinition(
  id: id,
  name: name,
  chapter: chapter,
  description: 'Score one Pair.',
  rules: rules ?? _rules(),
  objective: objective ?? _objective(target: 35),
  fixedJokerIds: fixedJokerIds,
  jokerOptionIds: jokerOptionIds,
  chooseJokers: chooseJokers,
  negativeJokerId: negativeJokerId,
  layoutCount: layouts?.length ?? 1,
  curated: true,
  targetSuccess: 1,
  hint: 'Play the pair.',
  visibleModifiers: const <String>[],
  layouts:
      layouts ??
      <LevelLayout>[
        LevelLayout(
          id: 'L001-TEST',
          seed: 1234,
          hash: 'test',
          deckCodes: deck,
          recommendedJokerIds: const <String>[],
        ),
      ],
  recommendedLoadouts: recommendedLoadouts,
);

LevelRules _rules({
  int hands = 1,
  int discards = 0,
  int discardTargetTax = 0,
}) => LevelRules(
  handSize: 5,
  maxSelect: 5,
  hands: hands,
  discards: discards,
  blockFraction: 0,
  blockedRanks: const <CardRank>{},
  blockedSuits: const <CardSuit>{},
  highCardZero: false,
  allowedHandTypes: const <HandType>{},
  faceRankZero: false,
  scoreColor: null,
  colorRankMultipliers: const <LevelCardColor, double>{},
  repeatDecay: 0,
  noRepeat: false,
  discardTargetTax: discardTargetTax,
  handScoreMultipliers: const <double>[],
  disabledSuitRotation: const <CardSuit>[],
  burnPlayedCards: false,
  burnScoringCards: false,
  burnPlayedRanks: false,
  shrinkingDiscards: false,
  jokerBlackout: false,
  fadingJokers: false,
  rotatingJoker: false,
  stage: 1,
  heatsCleared: 0,
  destroyed: 0,
  copied: 0,
  runCoins: 0,
  handLevels: const <HandType, int>{},
  hasModifier: false,
  modifierCount: 0,
  nullField: false,
  deadAir: false,
  bossModifier: false,
);

LevelObjective _objective({
  required int target,
  Map<HandType, int> requiredCounts = const <HandType, int>{},
}) => LevelObjective(
  targetScore: target,
  requiredCounts: requiredCounts,
  requiredSequence: const <HandType>[],
  minVariety: 0,
  forbiddenTypes: const <HandType>{},
  minQualityCount: 0,
  minQuality: HandType.pair,
  minTypesFrom: const <HandType>{},
  minTypesFromCount: 0,
  checkpoints: const <int>[],
);

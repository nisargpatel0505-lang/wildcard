import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/scoring_engine.dart';

void main() {
  group('v8.4.1 starter and difficulty contract', () {
    test(
      'the exact ten-Joker starter set replaces Triple Threat with Face Value',
      () {
        const expected = <String>[
          'copper',
          'presser',
          'retainer',
          'even',
          'lowball',
          'uniform',
          'fulltable',
          'polish',
          'opening_act',
          'face_value',
        ];

        expect(starterJokerIds, expected);
        expect(
          jokerCatalog.where((joker) => joker.starter).map((joker) => joker.id),
          unorderedEquals(expected),
        );
        expect(jokersById['face_value']!.starter, isTrue);
        expect(jokersById['face_value']!.unlock, 0);
        expect(jokersById['triple3']!.starter, isFalse);
        expect(
          jokersById['triple3']!.unlock,
          greaterThan(0),
          reason: 'a removed starter must not remain a free collection unlock',
        );
      },
    );

    test(
      'Easy targets are 60 percent while Medium and Hard stay unchanged',
      () {
        expect(RunDifficulty.easy.targetMultiplier, 0.60);
        expect(RunDifficulty.medium.targetMultiplier, 1.00);
        expect(RunDifficulty.hard.targetMultiplier, 1.30);
        expect(RunDifficulty.easy.stakeMultiplier, 0.80);
        expect(RunDifficulty.medium.stakeMultiplier, 0.92);
        expect(RunDifficulty.hard.stakeMultiplier, 1.00);

        expect(
          ScoringState(
            rngSeed: 1,
            stage: 1,
            difficulty: RunDifficulty.easy,
          ).target,
          54,
        );
        expect(
          ScoringState(
            rngSeed: 1,
            stage: 1,
            difficulty: RunDifficulty.medium,
          ).target,
          90,
        );
        expect(
          ScoringState(
            rngSeed: 1,
            stage: 1,
            difficulty: RunDifficulty.hard,
          ).target,
          117,
        );
      },
    );
  });

  group('v8.4.1 measured retiers and shop prices', () {
    const targetRarities = <String, JokerRarity>{
      'surge': JokerRarity.wild,
      'butcher': JokerRarity.wild,
      'trainer': JokerRarity.wild,
      'miser': JokerRarity.rare,
      'tailor': JokerRarity.rare,
      'polish': JokerRarity.rare,
      'prism_lens': JokerRarity.uncommon,
      'rehearsal_tape': JokerRarity.uncommon,
      'shortcut': JokerRarity.uncommon,
      'pocketflush': JokerRarity.uncommon,
      'danger_music': JokerRarity.rare,
      'cheat': JokerRarity.rare,
      'glass_joystick': JokerRarity.rare,
      'royalscam': JokerRarity.uncommon,
      'redline': JokerRarity.uncommon,
      'overtime': JokerRarity.uncommon,
      'master_class': JokerRarity.uncommon,
      'lucky7': JokerRarity.uncommon,
      'color_wash': JokerRarity.uncommon,
      'survivor': JokerRarity.uncommon,
      'modded': JokerRarity.uncommon,
      'acemag': JokerRarity.common,
      'dividend': JokerRarity.common,
      'couple': JokerRarity.common,
      'sniper': JokerRarity.common,
      'panic_button': JokerRarity.common,
      'encore': JokerRarity.common,
      'guillotine': JokerRarity.common,
      'frequency_meter': JokerRarity.common,
      'cleaner': JokerRarity.common,
    };

    for (final entry in targetRarities.entries) {
      test('${entry.key} has its prescribed tier and an in-tier price', () {
        final joker = jokersById[entry.key];
        expect(joker, isNotNull);
        expect(joker!.rarity, entry.value);
        final (minimum, maximum) = switch (entry.value) {
          JokerRarity.common => (4, 6),
          JokerRarity.uncommon => (5, 7),
          JokerRarity.rare => (6, 8),
          JokerRarity.wild => (10, 12),
        };
        expect(
          joker.price,
          inInclusiveRange(minimum, maximum),
          reason:
              '${entry.key} must use the v8.4.1 ${entry.value.name} price band',
        );
      });
    }
  });

  group('v8.4.1 numerical nerfs', () {
    test('Heat Surge adds 0.12 Mult per cleared Heat', () {
      final result = _score(
        jokerId: 'surge',
        state: ScoringState(
          rngSeed: 1,
          jokerIds: <String>['surge'],
          stagesCleared: 5,
        ),
      );
      expect(_jokerAmount(result, ScoreEventType.mult), closeTo(0.60, 1e-12));
    });

    test('Butcher adds 0.30 Mult per destroyed card', () {
      final result = _score(
        jokerId: 'butcher',
        state: ScoringState(
          rngSeed: 1,
          jokerIds: <String>['butcher'],
          destroyedCount: 2,
        ),
      );
      expect(_jokerAmount(result, ScoreEventType.mult), closeTo(0.60, 1e-12));
    });

    test('Overclock is x2.4 and still removes exactly one play', () {
      final state = ScoringState(rngSeed: 1, jokerIds: <String>['overclock']);
      final result = _score(jokerId: 'overclock', state: state);
      expect(_jokerAmount(result, ScoreEventType.xMult), closeTo(2.4, 1e-12));
      expect(state.effectiveHandsPerHeat, handsPerHeat - 1);
    });

    test('Rainbow is x1.8 across three or more suits', () {
      final state = ScoringState(rngSeed: 1, jokerIds: <String>['rainbow']);
      final result = WildcardScoringEngine(state).scoreHand(const <PlayingCard>[
        PlayingCard(rank: CardRank.two, suit: CardSuit.spades),
        PlayingCard(rank: CardRank.four, suit: CardSuit.hearts),
        PlayingCard(rank: CardRank.seven, suit: CardSuit.diamonds),
      ]);
      expect(_jokerAmount(result, ScoreEventType.xMult), closeTo(1.8, 1e-12));
    });
  });

  group('public catalogue isolation', () {
    test('89 active public Jokers remain unique', () {
      expect(jokerCatalog, hasLength(89));
      expect(jokerCatalog.map((joker) => joker.id).toSet(), hasLength(89));
      expect(jokerCatalog.map((joker) => joker.effect).toSet(), hasLength(89));
      expect(
        <JokerRarity, int>{
          for (final rarity in JokerRarity.values)
            rarity: jokerCatalog
                .where((joker) => joker.rarity == rarity)
                .length,
        },
        const <JokerRarity, int>{
          JokerRarity.common: 30,
          JokerRarity.uncommon: 29,
          JokerRarity.rare: 23,
          JokerRarity.wild: 7,
        },
      );
    });

    test('lookup includes legacy Jokers while selection excludes them', () {
      final lookupIds = <String>{
        ...jokerCatalog.map((joker) => joker.id),
        ...legacyJokerCatalog.map((joker) => joker.id),
      };
      expect(jokersById.keys, unorderedEquals(lookupIds));
      expect(selectableJokers, orderedEquals(jokerCatalog));
    });

    test('unknown ids never inflate public collection progress', () {
      final publicIds = jokerCatalog.map((joker) => joker.id).toSet();
      expect(
        publicUnlockedJokerCount(<String>{
          ...publicIds,
          ...legacyJokerCatalog.map((joker) => joker.id),
          'legacy_developer_test_joker',
          'unknown_joker',
        }),
        89,
      );
    });
  });
}

ScoreResult _score({required String jokerId, required ScoringState state}) {
  expect(state.jokerIds, contains(jokerId));
  return WildcardScoringEngine(state).scoreHand(const <PlayingCard>[
    PlayingCard(rank: CardRank.eight, suit: CardSuit.spades),
  ]);
}

double _jokerAmount(ScoreResult result, ScoreEventType type) => result.events
    .singleWhere((event) => event.type == type && (event.jokerIndex ?? -1) >= 0)
    .amount
    .toDouble();

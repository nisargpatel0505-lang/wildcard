import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_balance_audit.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

void main() {
  const harness = WildcardSimulationHarness();

  test('adaptive decisions remain byte-identical for a matched seed range', () {
    const config = SimulationConfig(
      runs: 8,
      firstSeed: 0x71060000,
      strategy: SimulationStrategy.adaptive,
      difficulty: RunDifficulty.medium,
      initialJokers: <String>['copper', 'polish'],
    );

    final first = harness.runBatch(config);
    final second = harness.runBatch(config);

    expect(jsonEncode(second.toJson()), jsonEncode(first.toJson()));
    expect(
      second.results.map((result) => result.toJson()).toList(),
      first.results.map((result) => result.toJson()).toList(),
    );
  });

  test('adaptive target planning decisively outperforms random legal taps', () {
    const seeds = 24;
    final random = harness.runBatch(
      const SimulationConfig(
        runs: seeds,
        firstSeed: 0x71061000,
        strategy: SimulationStrategy.randomLegal,
        difficulty: RunDifficulty.medium,
        initialJokers: <String>['copper', 'polish'],
      ),
    );
    final adaptive = harness.runBatch(
      const SimulationConfig(
        runs: seeds,
        firstSeed: 0x71061000,
        strategy: SimulationStrategy.adaptive,
        difficulty: RunDifficulty.medium,
        initialJokers: <String>['copper', 'polish'],
      ),
    );

    expect(random.invariantFailureCount, 0);
    expect(adaptive.invariantFailureCount, 0);
    expect(
      adaptive.averageHeatsCleared,
      greaterThan(random.averageHeatsCleared + 1),
    );
    expect(adaptive.averageScore, greaterThan(random.averageScore));
  });

  test('adaptive planning improves on immediate-score-only hand ranking', () {
    const seeds = 20;
    final naive = harness.runBatch(
      const SimulationConfig(
        runs: seeds,
        firstSeed: 0x71062000,
        strategy: SimulationStrategy.handRanking,
        difficulty: RunDifficulty.medium,
        initialJokers: <String>['copper', 'polish'],
      ),
    );
    final adaptive = harness.runBatch(
      const SimulationConfig(
        runs: seeds,
        firstSeed: 0x71062000,
        strategy: SimulationStrategy.adaptive,
        difficulty: RunDifficulty.medium,
        initialJokers: <String>['copper', 'polish'],
      ),
    );

    expect(naive.invariantFailureCount, 0);
    expect(adaptive.invariantFailureCount, 0);
    expect(
      adaptive.results.map((result) => result.toJson()).toList(),
      isNot(naive.results.map((result) => result.toJson()).toList()),
      reason: 'pace, retention and shop planning must change real decisions',
    );
    expect(
      adaptive.averageHeatsCleared,
      greaterThanOrEqualTo(naive.averageHeatsCleared),
    );
  });

  test('contribution cohorts use matched random five-Joker builds', () {
    final solo = jokerBalanceKitsForSeed(
      seed: 0x71070001,
      forcedJokers: const <String>['glass_joystick'],
    );
    final pair = jokerBalanceKitsForSeed(
      seed: 0x71070001,
      forcedJokers: const <String>['glass_joystick', 'roller'],
    );

    expect(solo.treatment, hasLength(maxJokers));
    expect(solo.control, hasLength(maxJokers));
    expect(solo.treatment.first, 'glass_joystick');
    expect(solo.treatment.skip(1), solo.control.skip(1));
    expect(pair.treatment.take(2), <String>['glass_joystick', 'roller']);
    expect(pair.treatment.skip(2), pair.control.skip(2));
    expect(solo.treatment.toSet(), hasLength(maxJokers));
    expect(solo.control.toSet(), hasLength(maxJokers));
    expect(solo.control.every(jokersById.containsKey), isTrue);

    final config = jokerBalanceSingleRunConfig(
      seed: 0x71070001,
      initialJokers: solo.treatment,
      difficulty: RunDifficulty.easy,
    );
    expect(config.runs, 1);
    expect(config.strategy, SimulationStrategy.adaptive);
    expect(config.difficulty, RunDifficulty.easy);
    expect(config.allJokersUnlocked, isFalse);
  });
}

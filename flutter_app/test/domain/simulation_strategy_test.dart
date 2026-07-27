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

  test('contribution cohorts preserve the matched two-starter baseline', () {
    final baseline = starterJokerIds.take(2).toList(growable: false);
    expect(jokerBalanceKit(const <String>[]), baseline);
    expect(
      jokerBalanceKit(<String>[baseline.first]),
      baseline,
      reason: 'forcing a baseline starter must deduplicate the kit',
    );

    final solo = jokerBalanceConfig(
      runs: 3,
      forcedJokers: const <String>['glass_joystick'],
    );
    final pair = jokerBalanceConfig(
      runs: 3,
      forcedJokers: const <String>['glass_joystick', 'roller'],
    );
    expect(solo.initialJokers, <String>[...baseline, 'glass_joystick']);
    expect(pair.initialJokers, <String>[
      ...baseline,
      'glass_joystick',
      'roller',
    ]);
    expect(solo.strategy, SimulationStrategy.adaptive);
    expect(solo.difficulty, RunDifficulty.medium);
    expect(solo.allJokersUnlocked, isFalse);
  });
}

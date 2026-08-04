import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/simulation.dart';

void main() {
  const harness = WildcardSimulationHarness();

  test('same seed range produces byte-identical reports', () {
    const config = SimulationConfig(
      runs: 20,
      firstSeed: 71000,
      strategy: SimulationStrategy.handRanking,
    );
    final first = harness.runBatch(config);
    final second = harness.runBatch(config);
    expect(jsonEncode(second.toJson()), jsonEncode(first.toJson()));
    expect(
      second.results.map((result) => result.toJson()).toList(),
      first.results.map((result) => result.toJson()).toList(),
    );
  });

  test('2,000 deterministic full runs preserve every engine invariant', () {
    final random = harness.runBatch(
      const SimulationConfig(
        runs: 1000,
        firstSeed: 100000,
        strategy: SimulationStrategy.randomLegal,
      ),
    );
    final ranked = harness.runBatch(
      const SimulationConfig(
        runs: 1000,
        firstSeed: 200000,
        strategy: SimulationStrategy.handRanking,
      ),
    );

    expect(random.invariantFailureCount, 0);
    expect(ranked.invariantFailureCount, 0);
    expect(random.results, hasLength(1000));
    expect(ranked.results, hasLength(1000));
    expect(
      ranked.averageHeatsCleared,
      greaterThan(random.averageHeatsCleared),
      reason: 'the hand-ranking policy must outperform random legal tapping',
    );

    // Kept visible in CI logs so each balance change has an immediate, stable
    // heat-distribution fingerprint without invoking the old JS bot harness.
    // ignore: avoid_print
    print('SIM_RANDOM ${jsonEncode(random.toJson())}');
    // ignore: avoid_print
    print('SIM_RANKED ${jsonEncode(ranked.toJson())}');
  });

  test('Daily locks balance to Medium even when picker difficulty differs', () {
    const easyPicker = SimulationConfig(
      runs: 12,
      firstSeed: 0x7100D000,
      strategy: SimulationStrategy.adaptive,
      mode: RunMode.daily,
      difficulty: RunDifficulty.easy,
      initialJokers: <String>[],
    );
    const hardPicker = SimulationConfig(
      runs: 12,
      firstSeed: 0x7100D000,
      strategy: SimulationStrategy.adaptive,
      mode: RunMode.daily,
      difficulty: RunDifficulty.hard,
      initialJokers: <String>[],
    );

    final easy = harness.runBatch(easyPicker);
    final hard = harness.runBatch(hardPicker);
    expect(
      hard.results.map((result) => result.toJson()).toList(),
      easy.results.map((result) => result.toJson()).toList(),
    );
  });

  test('Gauntlet, shops and supplies are exercised by the native harness', () {
    final report = harness.runBatch(
      const SimulationConfig(
        runs: 20,
        firstSeed: 0x7100A000,
        strategy: SimulationStrategy.adaptive,
        mode: RunMode.gauntlet,
        maxHeat: gauntletHeats,
      ),
    );

    expect(report.invariantFailureCount, 0);
    expect(report.averageShopsVisited, greaterThan(0));
    expect(report.averageJokersBought, greaterThan(0));
    expect(report.averageSuppliesBought, greaterThan(0));
    expect(
      report.results.every(
        (result) => result.modifierSlotsFaced >= result.terminalHeat,
      ),
      isTrue,
      reason: 'Gauntlet assigns at least one modifier on every attempted Heat',
    );
  });

  test('explicit Endless stress continues beyond the Heat 12 victory', () {
    final report = harness.runBatch(
      const SimulationConfig(
        runs: 20,
        firstSeed: 0x7100E000,
        strategy: SimulationStrategy.adaptive,
        difficulty: RunDifficulty.easy,
        maxHeat: 20,
        continueEndless: true,
        initialJokers: <String>[
          'glass_joystick',
          'roller',
          'polish',
          'danger_music',
          'allin',
        ],
      ),
    );

    expect(report.invariantFailureCount, 0);
    expect(report.results.any((result) => result.heatsCleared > 12), isTrue);
    expect(
      report.results
          .where((result) => result.heatsCleared > 12)
          .every((result) => result.modifierSlotsFaced >= 4),
      isTrue,
    );
  });

  test('Endless cannot be requested for Daily or Gauntlet', () {
    expect(
      () => harness.runBatch(
        const SimulationConfig(
          runs: 1,
          mode: RunMode.daily,
          continueEndless: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('THE HOUSE sensitivity knobs stay inside the simulator', () {
    const initial = <String>[
      'glass_joystick',
      'roller',
      'polish',
      'danger_music',
      'allin',
    ];
    final production = harness.runBatch(
      const SimulationConfig(
        runs: 12,
        firstSeed: 0x7100B000,
        strategy: SimulationStrategy.adaptive,
        difficulty: RunDifficulty.easy,
        initialJokers: initial,
        bossBlockedJokers: 2,
        bossTargetMultiplier: 1.10,
      ),
    );
    final sensitivity = harness.runBatch(
      const SimulationConfig(
        runs: 12,
        firstSeed: 0x7100B000,
        strategy: SimulationStrategy.adaptive,
        difficulty: RunDifficulty.easy,
        initialJokers: initial,
        bossBlockedJokers: 3,
        bossTargetMultiplier: 1.00,
      ),
    );

    expect(production.invariantFailureCount, 0);
    expect(sensitivity.invariantFailureCount, 0);
    expect(production.averageBossHeatsFaced, greaterThan(0));
    expect(sensitivity.averageBossHeatsFaced, greaterThan(0));
    expect(
      production.averageBossBlockedJokerSlots /
          production.averageBossHeatsFaced,
      closeTo(2, 0.001),
    );
    expect(
      sensitivity.averageBossBlockedJokerSlots /
          sensitivity.averageBossHeatsFaced,
      closeTo(3, 0.001),
    );
    expect(
      sensitivity.averageBossTargetWhenFaced,
      lessThan(production.averageBossTargetWhenFaced),
    );
  });

  test('invalid THE HOUSE sensitivity knobs are rejected', () {
    expect(
      () => harness.runBatch(
        const SimulationConfig(runs: 1, bossBlockedJokers: 6),
      ),
      throwsArgumentError,
    );
    expect(
      () => harness.runBatch(
        const SimulationConfig(runs: 1, bossTargetMultiplier: 0),
      ),
      throwsArgumentError,
    );
  });
}

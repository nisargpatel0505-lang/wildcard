import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

void main() {
  const harness = WildcardSimulationHarness();

  test(
    'null discovery override preserves the historical full-pool harness',
    () {
      const baseline = SimulationConfig(
        runs: 3,
        firstSeed: 0x85000100,
        strategy: SimulationStrategy.handRanking,
        difficulty: RunDifficulty.medium,
        allJokersUnlocked: true,
      );
      final explicit = SimulationConfig(
        runs: baseline.runs,
        firstSeed: baseline.firstSeed,
        strategy: baseline.strategy,
        difficulty: baseline.difficulty,
        allJokersUnlocked: false,
        discoveredJokerIds: jokerCatalog
            .map((joker) => joker.id)
            .toList(growable: false),
      );

      final baselineRuns = harness
          .runBatch(baseline)
          .results
          .map((run) => run.toJson())
          .toList(growable: false);
      final explicitRuns = harness
          .runBatch(explicit)
          .results
          .map((run) => run.toJson())
          .toList(growable: false);

      expect(explicitRuns, baselineRuns);
    },
  );

  test('explicit empty discovery pool cannot create a shop Joker purchase', () {
    final report = harness.runBatch(
      const SimulationConfig(
        runs: 8,
        firstSeed: 0x85000200,
        strategy: SimulationStrategy.adaptive,
        difficulty: RunDifficulty.easy,
        initialJokers: <String>[],
        allJokersUnlocked: true,
        discoveredJokerIds: <String>[],
      ),
    );

    expect(report.results, isNotEmpty);
    expect(report.results.every((run) => run.jokersBought == 0), isTrue);
    expect(report.results.every((run) => run.finalJokers.isEmpty), isTrue);
  });
}

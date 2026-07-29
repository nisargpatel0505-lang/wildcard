import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_balance_audit.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

void main() {
  const harness = WildcardSimulationHarness();

  test('matched kits are deterministic, public and share their teammates', () {
    final first = jokerBalanceKitsForSeed(
      seed: 0x71070123,
      forcedJokers: const <String>['surge'],
    );
    final repeated = jokerBalanceKitsForSeed(
      seed: 0x71070123,
      forcedJokers: const <String>['surge'],
    );
    final publicIds = jokerCatalog.map((joker) => joker.id).toSet();

    expect(repeated.treatment, first.treatment);
    expect(repeated.control, first.control);
    expect(first.treatment, hasLength(maxJokers));
    expect(first.control, hasLength(maxJokers));
    expect(first.treatment.skip(1), first.control.skip(1));
    expect(first.treatment.every(publicIds.contains), isTrue);
    expect(first.control.every(publicIds.contains), isTrue);
  });

  test('terminal progress includes the exact failed-Heat fraction', () {
    final result = harness
        .runBatch(
          const SimulationConfig(
            runs: 1,
            firstSeed: 0x71070234,
            strategy: SimulationStrategy.adaptive,
            difficulty: RunDifficulty.medium,
            initialJokers: <String>[],
            allJokersUnlocked: false,
          ),
        )
        .results
        .single;

    expect(result.terminalTarget, greaterThan(0));
    expect(result.terminalStageScore, greaterThanOrEqualTo(0));
    final expected = result.won
        ? result.heatsCleared.toDouble()
        : result.heatsCleared +
              (result.terminalStageScore / result.terminalTarget).clamp(0, 1);
    expect(jokerBalanceRunProgress(result), expected);
  });

  test('matched Medium and Easy cohorts reproduce byte-for-byte metrics', () {
    for (final difficulty in <RunDifficulty>[
      RunDifficulty.medium,
      RunDifficulty.easy,
    ]) {
      final first = runJokerBalanceMatchedCohort(
        harness: harness,
        runs: 2,
        firstSeed: 0x71070345,
        forcedJokers: const <String>['surge'],
        difficulty: difficulty,
      );
      final repeated = runJokerBalanceMatchedCohort(
        harness: harness,
        runs: 2,
        firstSeed: 0x71070345,
        forcedJokers: const <String>['surge'],
        difficulty: difficulty,
      );

      expect(repeated.treatment.winRate, first.treatment.winRate);
      expect(
        repeated.treatment.averageProgress,
        first.treatment.averageProgress,
      );
      expect(repeated.control.winRate, first.control.winRate);
      expect(repeated.control.averageProgress, first.control.averageProgress);
      expect(first.treatment.invariantFailures, 0);
      expect(first.control.invariantFailures, 0);
    }
  });

  test('unknown ids cannot enter balance cohorts', () {
    expect(
      () => jokerBalanceKitsForSeed(
        seed: 1,
        forcedJokers: const <String>['not-a-joker'],
      ),
      throwsArgumentError,
    );
  });
}

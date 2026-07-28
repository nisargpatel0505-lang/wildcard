import 'game_rules.dart';
import 'joker_catalog.dart';
import 'simulation.dart';

/// The heavyweight audit is opt-in, but its default is large enough to avoid
/// treating a handful of lucky seeds as balance evidence.
const int jokerBalanceDefaultRuns = 200;
const int jokerBalanceFirstSeed = 0x71070000;

/// The two arms used for one seed of a matched contribution test.
///
/// A single forced Joker is compared as `[J] + four teammates` against the
/// same four teammates plus one random replacement. A forced pair is compared
/// with three shared teammates and two random replacements. This makes both
/// arms real five-Joker builds while holding teammates and the engine seed
/// constant.
class JokerBalanceKits {
  const JokerBalanceKits({
    required this.treatment,
    required this.control,
    required this.matchedTeammates,
  });

  final List<String> treatment;
  final List<String> control;
  final List<String> matchedTeammates;
}

JokerBalanceKits jokerBalanceKitsForSeed({
  required int seed,
  Iterable<String> forcedJokers = const <String>[],
}) {
  final forced = forcedJokers.toList(growable: false);
  if (forced.length > maxJokers || forced.toSet().length != forced.length) {
    throw ArgumentError.value(
      forced,
      'forcedJokers',
      'Use at most $maxJokers unique public Joker ids',
    );
  }
  final publicIds = jokerCatalog.map((joker) => joker.id).toSet();
  if (forced.any((id) => !publicIds.contains(id))) {
    throw ArgumentError.value(
      forced,
      'forcedJokers',
      'Every forced id must belong to the public catalogue',
    );
  }

  final pool = jokerCatalog
      .map((joker) => joker.id)
      .where((id) => !forced.contains(id))
      .toList(growable: true);
  _shuffleWithSeed(pool, seed ^ 0x51ED270B);

  final teammateCount = maxJokers - forced.length;
  final teammates = pool.take(teammateCount).toList(growable: false);
  final replacements = pool
      .skip(teammateCount)
      .take(forced.length)
      .toList(growable: false);
  return JokerBalanceKits(
    treatment: List<String>.unmodifiable(<String>[...forced, ...teammates]),
    control: List<String>.unmodifiable(<String>[...replacements, ...teammates]),
    matchedTeammates: List<String>.unmodifiable(teammates),
  );
}

SimulationConfig jokerBalanceSingleRunConfig({
  required int seed,
  required List<String> initialJokers,
  required RunDifficulty difficulty,
}) => SimulationConfig(
  runs: 1,
  firstSeed: seed,
  strategy: SimulationStrategy.adaptive,
  difficulty: difficulty,
  initialJokers: List<String>.unmodifiable(initialJokers),
  allJokersUnlocked: false,
);

class JokerBalanceMatchedCohort {
  const JokerBalanceMatchedCohort({
    required this.treatment,
    required this.control,
  });

  final JokerBalanceMetrics treatment;
  final JokerBalanceMetrics control;
}

JokerBalanceMatchedCohort runJokerBalanceMatchedCohort({
  required WildcardSimulationHarness harness,
  required int runs,
  required int firstSeed,
  required Iterable<String> forcedJokers,
  required RunDifficulty difficulty,
}) {
  if (runs < 1) throw ArgumentError.value(runs, 'runs');
  final forced = forcedJokers.toList(growable: false);
  final treatment = <SimulatedRunResult>[];
  final control = <SimulatedRunResult>[];

  for (var index = 0; index < runs; index++) {
    final seed = firstSeed + index;
    final kits = jokerBalanceKitsForSeed(seed: seed, forcedJokers: forced);
    control.add(
      harness
          .runBatch(
            jokerBalanceSingleRunConfig(
              seed: seed,
              initialJokers: kits.control,
              difficulty: difficulty,
            ),
          )
          .results
          .single,
    );
    treatment.add(
      harness
          .runBatch(
            jokerBalanceSingleRunConfig(
              seed: seed,
              initialJokers: kits.treatment,
              difficulty: difficulty,
            ),
          )
          .results
          .single,
    );
  }

  return JokerBalanceMatchedCohort(
    treatment: JokerBalanceMetrics.fromResults(treatment),
    control: JokerBalanceMetrics.fromResults(control),
  );
}

double jokerBalanceRunProgress(SimulatedRunResult result) {
  if (result.won || result.terminalTarget <= 0) {
    return result.heatsCleared.toDouble();
  }
  final terminalFraction = result.terminalStageScore / result.terminalTarget;
  return result.heatsCleared + terminalFraction.clamp(0.0, 1.0);
}

class JokerBalanceMetrics {
  const JokerBalanceMetrics({
    required this.runs,
    required this.wins,
    required this.winRate,
    required this.averageProgress,
    required this.averageTerminalHeat,
    required this.averageHeatsCleared,
    required this.averageScore,
    required this.averageJokerTriggersPerHand,
    required this.jokerActiveHandRate,
    required this.invariantFailures,
  });

  factory JokerBalanceMetrics.fromReport(SimulationBatchReport report) =>
      JokerBalanceMetrics.fromResults(report.results);

  factory JokerBalanceMetrics.fromResults(List<SimulatedRunResult> results) {
    if (results.isEmpty) {
      return const JokerBalanceMetrics(
        runs: 0,
        wins: 0,
        winRate: 0,
        averageProgress: 0,
        averageTerminalHeat: 0,
        averageHeatsCleared: 0,
        averageScore: 0,
        averageJokerTriggersPerHand: 0,
        jokerActiveHandRate: 0,
        invariantFailures: 0,
      );
    }
    final runs = results.length;
    final wins = results.where((result) => result.won).length;
    final hands = results.fold<int>(
      0,
      (sum, result) => sum + result.handsPlayed,
    );
    final triggerEvents = results.fold<int>(
      0,
      (sum, result) => sum + result.jokerTriggerEvents,
    );
    final activeHands = results.fold<int>(
      0,
      (sum, result) => sum + result.handsWithJokerTrigger,
    );
    double average(num Function(SimulatedRunResult result) read) =>
        results.fold<num>(0, (sum, result) => sum + read(result)) / runs;

    return JokerBalanceMetrics(
      runs: runs,
      wins: wins,
      winRate: wins / runs,
      averageProgress: average(jokerBalanceRunProgress),
      averageTerminalHeat: average((result) => result.terminalHeat),
      averageHeatsCleared: average((result) => result.heatsCleared),
      averageScore: average((result) => result.totalScore),
      averageJokerTriggersPerHand: hands == 0 ? 0 : triggerEvents / hands,
      jokerActiveHandRate: hands == 0 ? 0 : activeHands / hands,
      invariantFailures: results.fold<int>(
        0,
        (sum, result) => sum + result.invariantFailures.length,
      ),
    );
  }

  final int runs;
  final int wins;
  final double winRate;

  /// Average completed Heats plus fractional progress through the failed Heat.
  ///
  /// A completed run ends at exactly its number of cleared Heats rather than
  /// receiving a fictitious thirteenth-Heat fraction.
  final double averageProgress;
  final double averageTerminalHeat;
  final double averageHeatsCleared;
  final double averageScore;
  final double averageJokerTriggersPerHand;
  final double jokerActiveHandRate;
  final int invariantFailures;
}

class JokerContributionRow {
  const JokerContributionRow({
    required this.joker,
    required this.rarity,
    required this.difficulty,
    required this.metrics,
    required this.control,
  });

  final String joker;
  final String rarity;
  final RunDifficulty difficulty;
  final JokerBalanceMetrics metrics;
  final JokerBalanceMetrics control;

  double get winDelta => metrics.winRate - control.winRate;
  double get progressDelta => metrics.averageProgress - control.averageProgress;
  double get terminalHeatDelta =>
      metrics.averageTerminalHeat - control.averageTerminalHeat;
  double get heatsClearedDelta =>
      metrics.averageHeatsCleared - control.averageHeatsCleared;
  bool get pairOver70 => metrics.winRate > 0.70;

  String toCsv(String prefix) => <Object>[
    prefix,
    joker,
    rarity,
    winDelta.toStringAsFixed(6),
    // Position five was historically `heatDelta`. Keeping progress lift here
    // lets old positional shard mergers rank the corrected methodology.
    progressDelta.toStringAsFixed(6),
    metrics.runs,
    metrics.wins,
    metrics.winRate.toStringAsFixed(6),
    metrics.averageTerminalHeat.toStringAsFixed(4),
    metrics.averageHeatsCleared.toStringAsFixed(4),
    heatsClearedDelta.toStringAsFixed(6),
    metrics.averageScore.toStringAsFixed(2),
    metrics.averageJokerTriggersPerHand.toStringAsFixed(4),
    metrics.jokerActiveHandRate.toStringAsFixed(6),
    pairOver70 ? 1 : 0,
    progressDelta.toStringAsFixed(6),
    metrics.averageProgress.toStringAsFixed(6),
    terminalHeatDelta.toStringAsFixed(6),
    control.runs,
    control.wins,
    control.winRate.toStringAsFixed(6),
    control.averageProgress.toStringAsFixed(6),
    control.averageTerminalHeat.toStringAsFixed(4),
    control.averageHeatsCleared.toStringAsFixed(4),
    control.averageScore.toStringAsFixed(2),
    difficulty.name,
  ].join(',');
}

const String jokerContributionCsvHeader =
    'prefix,joker,rarity,winDelta,progressDelta,runs,wins,winRate,'
    'avgTerminalHeat,avgHeatsCleared,heatsClearedDelta,avgScore,'
    'avgJokerTriggersPerHand,jokerActiveHandRate,over70,'
    'progressDeltaExact,avgProgress,terminalHeatDelta,controlRuns,'
    'controlWins,controlWinRate,controlAvgProgress,controlAvgTerminalHeat,'
    'controlAvgHeatsCleared,controlAvgScore,difficulty';

int compareJokerContribution(
  JokerContributionRow left,
  JokerContributionRow right,
) {
  final wins = right.winDelta.compareTo(left.winDelta);
  if (wins != 0) return wins;
  final progress = right.progressDelta.compareTo(left.progressDelta);
  if (progress != 0) return progress;
  final heatsCleared = right.heatsClearedDelta.compareTo(
    left.heatsClearedDelta,
  );
  if (heatsCleared != 0) return heatsCleared;
  final score = right.metrics.averageScore.compareTo(left.metrics.averageScore);
  if (score != 0) return score;
  return left.joker.compareTo(right.joker);
}

void _shuffleWithSeed(List<String> values, int seed) {
  final random = _BalanceRandom(seed);
  for (var index = values.length - 1; index > 0; index--) {
    final swapIndex = random.nextInt(index + 1);
    final value = values[index];
    values[index] = values[swapIndex];
    values[swapIndex] = value;
  }
}

/// Small harness-only generator with an explicitly stable 32-bit sequence.
///
/// This avoids both unseeded randomness and depending on SDK implementation
/// details of `dart:math Random` when balance evidence is reproduced later.
class _BalanceRandom {
  _BalanceRandom(int seed) : _state = seed & 0xFFFFFFFF {
    if (_state == 0) _state = 0x6D2B79F5;
  }

  int _state;

  int nextInt(int maximum) {
    if (maximum <= 0) throw ArgumentError.value(maximum, 'maximum');
    var value = _state;
    value ^= (value << 13) & 0xFFFFFFFF;
    value ^= value >>> 17;
    value ^= (value << 5) & 0xFFFFFFFF;
    _state = value & 0xFFFFFFFF;
    return _state % maximum;
  }
}

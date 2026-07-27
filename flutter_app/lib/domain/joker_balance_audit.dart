import 'game_rules.dart';
import 'joker_catalog.dart';
import 'simulation.dart';

const int jokerBalanceDefaultRuns = 1000;
const int jokerBalanceFirstSeed = 0x71070000;

List<String> get jokerBalanceBaselineKit =>
    starterJokerIds.take(2).toList(growable: false);

List<String> jokerBalanceKit(Iterable<String> forcedJokers) {
  final result = <String>[];
  for (final id in <String>[...jokerBalanceBaselineKit, ...forcedJokers]) {
    if (jokersById.containsKey(id) && !result.contains(id)) result.add(id);
  }
  return List<String>.unmodifiable(result.take(maxJokers));
}

SimulationConfig jokerBalanceConfig({
  required int runs,
  required Iterable<String> forcedJokers,
  int firstSeed = jokerBalanceFirstSeed,
}) => SimulationConfig(
  runs: runs,
  firstSeed: firstSeed,
  strategy: SimulationStrategy.adaptive,
  difficulty: RunDifficulty.medium,
  initialJokers: jokerBalanceKit(forcedJokers),
  allJokersUnlocked: false,
);

class JokerBalanceMetrics {
  const JokerBalanceMetrics({
    required this.runs,
    required this.wins,
    required this.winRate,
    required this.averageTerminalHeat,
    required this.averageHeatsCleared,
    required this.averageScore,
    required this.averageJokerTriggersPerHand,
    required this.jokerActiveHandRate,
    required this.invariantFailures,
  });

  factory JokerBalanceMetrics.fromReport(SimulationBatchReport report) {
    final averageTerminalHeat = report.results.isEmpty
        ? 0.0
        : report.results.fold<int>(
                0,
                (sum, result) => sum + result.terminalHeat,
              ) /
              report.results.length;
    return JokerBalanceMetrics(
      runs: report.results.length,
      wins: report.wins,
      winRate: report.winRate,
      averageTerminalHeat: averageTerminalHeat,
      averageHeatsCleared: report.averageHeatsCleared,
      averageScore: report.averageScore,
      averageJokerTriggersPerHand: report.averageJokerTriggersPerHand,
      jokerActiveHandRate: report.jokerActiveHandRate,
      invariantFailures: report.invariantFailureCount,
    );
  }

  final int runs;
  final int wins;
  final double winRate;
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
    required this.metrics,
    required this.baseline,
  });

  final String joker;
  final String rarity;
  final JokerBalanceMetrics metrics;
  final JokerBalanceMetrics baseline;

  double get winDelta => metrics.winRate - baseline.winRate;
  double get heatDelta =>
      metrics.averageTerminalHeat - baseline.averageTerminalHeat;
  double get heatsClearedDelta =>
      metrics.averageHeatsCleared - baseline.averageHeatsCleared;

  String toCsv(String prefix) => <Object>[
    prefix,
    joker,
    rarity,
    winDelta.toStringAsFixed(6),
    heatDelta.toStringAsFixed(4),
    metrics.runs,
    metrics.wins,
    metrics.winRate.toStringAsFixed(6),
    metrics.averageTerminalHeat.toStringAsFixed(4),
    metrics.averageHeatsCleared.toStringAsFixed(4),
    heatsClearedDelta.toStringAsFixed(4),
    metrics.averageScore.toStringAsFixed(2),
    metrics.averageJokerTriggersPerHand.toStringAsFixed(4),
    metrics.jokerActiveHandRate.toStringAsFixed(6),
    metrics.winRate > 0.70 ? 1 : 0,
  ].join(',');
}

const String jokerContributionCsvHeader =
    'prefix,joker,rarity,winDelta,heatDelta,runs,wins,winRate,'
    'avgTerminalHeat,avgHeatsCleared,heatsClearedDelta,avgScore,'
    'avgJokerTriggersPerHand,jokerActiveHandRate,over70';

int compareJokerContribution(
  JokerContributionRow left,
  JokerContributionRow right,
) {
  final wins = right.winDelta.compareTo(left.winDelta);
  if (wins != 0) return wins;
  final heat = right.heatDelta.compareTo(left.heatDelta);
  if (heat != 0) return heat;
  final heatsCleared = right.heatsClearedDelta.compareTo(
    left.heatsClearedDelta,
  );
  if (heatsCleared != 0) return heatsCleared;
  final score = right.metrics.averageScore.compareTo(left.metrics.averageScore);
  if (score != 0) return score;
  return left.joker.compareTo(right.joker);
}

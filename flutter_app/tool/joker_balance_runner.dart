import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/joker_balance_audit.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

const _harness = WildcardSimulationHarness();

void main(List<String> arguments) {
  final options = _RunnerOptions.parse(arguments, Platform.environment);
  options.validate();

  stdout.writeln(
    '# WILDCARD Joker balance '
    'phase=${options.phase} runs=${options.runs} '
    'shard=${options.shardIndex + 1}/${options.shardCount} '
    'baseline=${options.baseline == null ? 'computed' : 'precomputed'}',
  );
  stdout.writeln('JOKERCSV_HEADER,$jokerContributionCsvHeader');

  final baseline =
      options.baseline ??
      _runMetrics(
        runs: options.runs,
        firstSeed: options.firstSeed,
        forcedJokers: const <String>[],
      );
  stdout.writeln(
    JokerContributionRow(
      joker: 'BASELINE',
      rarity: 'baseline',
      metrics: baseline,
      baseline: baseline,
    ).toCsv('JOKERCSV'),
  );

  final singles = <JokerContributionRow>[];
  if (options.phase != 'pairs') {
    for (var index = 0; index < jokerCatalog.length; index++) {
      if (!options.includes(index)) continue;
      final joker = jokerCatalog[index];
      final metrics = _runMetrics(
        runs: options.runs,
        firstSeed: options.firstSeed,
        forcedJokers: <String>[joker.id],
      );
      final row = JokerContributionRow(
        joker: joker.id,
        rarity: joker.rarity.name,
        metrics: metrics,
        baseline: baseline,
      );
      singles.add(row);
      stdout.writeln(row.toCsv('JOKERCSV'));
    }
  }

  if (options.phase == 'singles') return;
  final top12 = _resolveTop12(options, singles);
  stdout.writeln('PAIRCSV_HEADER,$jokerContributionCsvHeader');
  final pairs = <List<String>>[
    for (var left = 0; left < top12.length; left++)
      for (var right = left + 1; right < top12.length; right++)
        <String>[top12[left], top12[right]],
  ];
  for (var index = 0; index < pairs.length; index++) {
    if (!options.includes(index)) continue;
    final ids = pairs[index];
    final metrics = _runMetrics(
      runs: options.runs,
      firstSeed: options.firstSeed,
      forcedJokers: ids,
    );
    final rarity = ids.map((id) => jokersById[id]!.rarity.name).join('+');
    stdout.writeln(
      JokerContributionRow(
        joker: ids.join('+'),
        rarity: rarity,
        metrics: metrics,
        baseline: baseline,
      ).toCsv('PAIRCSV'),
    );
  }
}

JokerBalanceMetrics _runMetrics({
  required int runs,
  required int firstSeed,
  required List<String> forcedJokers,
}) {
  final metrics = JokerBalanceMetrics.fromReport(
    _harness.runBatch(
      jokerBalanceConfig(
        runs: runs,
        firstSeed: firstSeed,
        forcedJokers: forcedJokers,
      ),
    ),
  );
  if (metrics.invariantFailures != 0) {
    throw StateError(
      '${forcedJokers.isEmpty ? 'baseline' : forcedJokers.join('+')} '
      'produced ${metrics.invariantFailures} invariant failures',
    );
  }
  return metrics;
}

List<String> _resolveTop12(
  _RunnerOptions options,
  List<JokerContributionRow> singles,
) {
  final result = options.top12.isNotEmpty
      ? options.top12
      : options.shardCount == 1 && options.phase == 'both'
      ? (singles..sort(compareJokerContribution))
            .take(12)
            .map((row) => row.joker)
            .toList(growable: false)
      : throw StateError(
          'Pair shards need --top12=id1,...,id12 after merging and ranking '
          'the singles JOKERCSV output.',
        );
  if (result.length != 12 ||
      result.toSet().length != 12 ||
      result.any((id) => !jokerCatalog.any((joker) => joker.id == id))) {
    throw ArgumentError.value(
      result,
      'top12',
      'Provide exactly 12 unique public Joker ids',
    );
  }
  return result;
}

class _RunnerOptions {
  const _RunnerOptions({
    required this.runs,
    required this.firstSeed,
    required this.phase,
    required this.shardIndex,
    required this.shardCount,
    required this.top12,
    required this.baseline,
  });

  factory _RunnerOptions.parse(
    List<String> arguments,
    Map<String, String> environment,
  ) {
    final values = <String, String>{};
    for (final argument in arguments) {
      if (!argument.startsWith('--') || !argument.contains('=')) {
        throw FormatException('Expected --name=value, got "$argument"');
      }
      final separator = argument.indexOf('=');
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
    String option(String name, String environmentName, String fallback) =>
        values[name] ?? environment[environmentName] ?? fallback;
    final top12 = option('top12', 'WILDCARD_JOKER_TOP12', '')
        .split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final baselineValue = option(
      'baseline',
      'WILDCARD_JOKER_BALANCE_BASELINE',
      '',
    );
    final baselineFile = option(
      'baseline-file',
      'WILDCARD_JOKER_BALANCE_BASELINE_FILE',
      '',
    );
    if (baselineValue.isNotEmpty && baselineFile.isNotEmpty) {
      throw const FormatException(
        'Use only one of --baseline or --baseline-file',
      );
    }
    final baselineSource = baselineFile.isNotEmpty
        ? File(baselineFile).readAsStringSync()
        : baselineValue;
    return _RunnerOptions(
      runs: _parseInteger(
        option(
          'runs',
          'WILDCARD_JOKER_BALANCE_RUNS',
          '$jokerBalanceDefaultRuns',
        ),
        'runs',
      ),
      firstSeed: _parseInteger(
        option(
          'first-seed',
          'WILDCARD_JOKER_BALANCE_FIRST_SEED',
          '$jokerBalanceFirstSeed',
        ),
        'first-seed',
      ),
      phase: option('phase', 'WILDCARD_JOKER_BALANCE_PHASE', 'both'),
      shardIndex: _parseInteger(
        option('shard-index', 'WILDCARD_JOKER_BALANCE_SHARD_INDEX', '0'),
        'shard-index',
      ),
      shardCount: _parseInteger(
        option('shard-count', 'WILDCARD_JOKER_BALANCE_SHARD_COUNT', '1'),
        'shard-count',
      ),
      top12: top12,
      baseline: baselineSource.trim().isEmpty
          ? null
          : _parseBaselineMetrics(baselineSource),
    );
  }

  final int runs;
  final int firstSeed;
  final String phase;
  final int shardIndex;
  final int shardCount;
  final List<String> top12;
  final JokerBalanceMetrics? baseline;

  bool includes(int cohortIndex) => cohortIndex % shardCount == shardIndex;

  void validate() {
    if (runs < 1) throw ArgumentError.value(runs, 'runs');
    if (!const <String>{'both', 'singles', 'pairs'}.contains(phase)) {
      throw ArgumentError.value(phase, 'phase');
    }
    if (shardCount < 1) {
      throw ArgumentError.value(shardCount, 'shard-count');
    }
    if (shardIndex < 0 || shardIndex >= shardCount) {
      throw ArgumentError.value(
        shardIndex,
        'shard-index',
        'Must be in [0, ${shardCount - 1}]',
      );
    }
    if (baseline case final metrics?) {
      if (metrics.runs != runs) {
        throw ArgumentError(
          'Precomputed baseline has ${metrics.runs} runs, but --runs=$runs.',
        );
      }
      if (metrics.wins < 0 || metrics.wins > metrics.runs) {
        throw ArgumentError.value(metrics.wins, 'baseline wins');
      }
      if ((metrics.winRate - metrics.wins / metrics.runs).abs() > 0.000001) {
        throw ArgumentError(
          'Precomputed baseline winRate does not match wins/runs.',
        );
      }
      if (!<double>[
            metrics.winRate,
            metrics.averageTerminalHeat,
            metrics.averageHeatsCleared,
            metrics.averageScore,
            metrics.averageJokerTriggersPerHand,
            metrics.jokerActiveHandRate,
          ].every((value) => value.isFinite && value >= 0) ||
          metrics.winRate > 1 ||
          metrics.jokerActiveHandRate > 1 ||
          metrics.averageTerminalHeat < 1 ||
          metrics.invariantFailures != 0) {
        throw ArgumentError('Precomputed baseline metrics are invalid.');
      }
    }
  }
}

JokerBalanceMetrics _parseBaselineMetrics(String source) {
  final trimmed = source.trim();
  final baselineLine = const LineSplitter()
      .convert(trimmed)
      .where((line) => line.startsWith('JOKERCSV,BASELINE,'))
      .firstOrNull;
  if (baselineLine != null) return _parseBaselineCsvRow(baselineLine);
  if (trimmed.startsWith('{')) {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw const FormatException('Baseline JSON must be an object.');
    }
    return _baselineFromFields(
      decoded.map((key, value) => MapEntry('$key', value)),
    );
  }
  if (trimmed.contains('=')) {
    final fields = <String, Object?>{};
    for (final part in trimmed.split(RegExp(r'[,;]'))) {
      final separator = part.indexOf('=');
      if (separator <= 0) {
        throw FormatException('Invalid baseline field "$part".');
      }
      fields[part.substring(0, separator).trim()] = part
          .substring(separator + 1)
          .trim();
    }
    return _baselineFromFields(fields);
  }
  final values = trimmed.split(',').map((value) => value.trim()).toList();
  if (values.length != 8) {
    throw const FormatException(
      'Compact baseline must contain '
      'runs,wins,winRate,avgTerminalHeat,avgHeatsCleared,avgScore,'
      'avgJokerTriggersPerHand,jokerActiveHandRate.',
    );
  }
  return _baselineFromFields(<String, Object?>{
    'runs': values[0],
    'wins': values[1],
    'winRate': values[2],
    'avgTerminalHeat': values[3],
    'avgHeatsCleared': values[4],
    'avgScore': values[5],
    'avgJokerTriggersPerHand': values[6],
    'jokerActiveHandRate': values[7],
  });
}

JokerBalanceMetrics _parseBaselineCsvRow(String row) {
  final values = row.split(',');
  if (values.length < 14 ||
      values[0] != 'JOKERCSV' ||
      values[1] != 'BASELINE') {
    throw const FormatException('Invalid baseline JOKERCSV row.');
  }
  return _baselineFromFields(<String, Object?>{
    'runs': values[5],
    'wins': values[6],
    'winRate': values[7],
    'avgTerminalHeat': values[8],
    'avgHeatsCleared': values[9],
    'avgScore': values[11],
    'avgJokerTriggersPerHand': values[12],
    'jokerActiveHandRate': values[13],
  });
}

JokerBalanceMetrics _baselineFromFields(Map<String, Object?> fields) {
  Object? read(String primary, [String? alternate]) =>
      fields[primary] ?? (alternate == null ? null : fields[alternate]);
  final runs = _requiredInt(read('runs'), 'runs');
  final wins = _requiredInt(read('wins'), 'wins');
  final winRate = _requiredDouble(read('winRate'), 'winRate');
  final terminal = _requiredDouble(
    read('avgTerminalHeat', 'averageTerminalHeat'),
    'avgTerminalHeat',
  );
  final heats = _requiredDouble(
    read('avgHeatsCleared', 'averageHeatsCleared'),
    'avgHeatsCleared',
  );
  final score = _requiredDouble(read('avgScore', 'averageScore'), 'avgScore');
  final triggers = _requiredDouble(
    read('avgJokerTriggersPerHand', 'averageJokerTriggersPerHand'),
    'avgJokerTriggersPerHand',
  );
  final activeRate = _requiredDouble(
    read('jokerActiveHandRate'),
    'jokerActiveHandRate',
  );
  return JokerBalanceMetrics(
    runs: runs,
    wins: wins,
    winRate: winRate,
    averageTerminalHeat: terminal,
    averageHeatsCleared: heats,
    averageScore: score,
    averageJokerTriggersPerHand: triggers,
    jokerActiveHandRate: activeRate,
    invariantFailures: 0,
  );
}

int _requiredInt(Object? value, String name) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null) throw FormatException('Invalid baseline $name=$value');
  return parsed;
}

double _requiredDouble(Object? value, String name) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null) throw FormatException('Invalid baseline $name=$value');
  return parsed;
}

int _parseInteger(String value, String name) {
  final parsed = value.toLowerCase().startsWith('0x')
      ? int.tryParse(value.substring(2), radix: 16)
      : int.tryParse(value);
  if (parsed == null) throw FormatException('Invalid --$name=$value');
  return parsed;
}

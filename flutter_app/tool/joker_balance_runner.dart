import 'dart:io';

import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_balance_audit.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

const _harness = WildcardSimulationHarness();

void main(List<String> arguments) {
  final options = _RunnerOptions.parse(arguments, Platform.environment);
  options.validate();

  stdout.writeln(
    '# WILDCARD Joker balance '
    'method=matched-random-five '
    'phase=${options.phase} difficulty=${options.difficulty.name} '
    'runs=${options.runs} '
    'shard=${options.shardIndex + 1}/${options.shardCount}',
  );
  if (options.runs < 200) {
    stdout.writeln(
      '# WARNING runs=${options.runs} is a smoke test; use 200+ for evidence.',
    );
  }
  stdout.writeln('JOKERCSV_HEADER,$jokerContributionCsvHeader');

  final singles = <JokerContributionRow>[];
  if (options.phase != 'pairs') {
    for (var index = 0; index < jokerCatalog.length; index++) {
      if (!options.includes(index)) continue;
      final joker = jokerCatalog[index];
      final cohort = _runCohort(
        options: options,
        forcedJokers: <String>[joker.id],
      );
      final row = JokerContributionRow(
        joker: joker.id,
        rarity: joker.rarity.name,
        difficulty: options.difficulty,
        metrics: cohort.treatment,
        control: cohort.control,
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
    final cohort = _runCohort(options: options, forcedJokers: ids);
    final rarity = ids.map((id) => jokersById[id]!.rarity.name).join('+');
    final row = JokerContributionRow(
      joker: ids.join('+'),
      rarity: rarity,
      difficulty: options.difficulty,
      metrics: cohort.treatment,
      control: cohort.control,
    );
    stdout.writeln(row.toCsv('PAIRCSV'));
    if (row.pairOver70) {
      stdout.writeln(
        'PAIR_OVER_70,${row.joker},${row.metrics.winRate.toStringAsFixed(6)},'
        '${options.difficulty.name}',
      );
    }
  }
}

JokerBalanceMatchedCohort _runCohort({
  required _RunnerOptions options,
  required List<String> forcedJokers,
}) {
  final cohort = runJokerBalanceMatchedCohort(
    harness: _harness,
    runs: options.runs,
    firstSeed: options.firstSeed,
    forcedJokers: forcedJokers,
    difficulty: options.difficulty,
  );
  for (final arm in <MapEntry<String, JokerBalanceMetrics>>[
    MapEntry<String, JokerBalanceMetrics>('treatment', cohort.treatment),
    MapEntry<String, JokerBalanceMetrics>('control', cohort.control),
  ]) {
    if (arm.value.invariantFailures != 0) {
      throw StateError(
        '${forcedJokers.join('+')} ${arm.key} produced '
        '${arm.value.invariantFailures} invariant failures',
      );
    }
  }
  return cohort;
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
          'the matched JOKERCSV contribution rows.',
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
    required this.difficulty,
    required this.shardIndex,
    required this.shardCount,
    required this.top12,
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
      difficulty: _parseDifficulty(
        option('difficulty', 'WILDCARD_JOKER_BALANCE_DIFFICULTY', 'medium'),
      ),
      shardIndex: _parseInteger(
        option('shard-index', 'WILDCARD_JOKER_BALANCE_SHARD_INDEX', '0'),
        'shard-index',
      ),
      shardCount: _parseInteger(
        option('shard-count', 'WILDCARD_JOKER_BALANCE_SHARD_COUNT', '1'),
        'shard-count',
      ),
      top12: top12,
    );
  }

  final int runs;
  final int firstSeed;
  final String phase;
  final RunDifficulty difficulty;
  final int shardIndex;
  final int shardCount;
  final List<String> top12;

  bool includes(int cohortIndex) => cohortIndex % shardCount == shardIndex;

  void validate() {
    if (runs < 1) throw ArgumentError.value(runs, 'runs');
    if (!const <String>{'both', 'singles', 'pairs'}.contains(phase)) {
      throw ArgumentError.value(phase, 'phase');
    }
    if (difficulty != RunDifficulty.medium &&
        difficulty != RunDifficulty.easy) {
      throw ArgumentError.value(
        difficulty,
        'difficulty',
        'The balance audit supports Medium and Easy',
      );
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
  }
}

RunDifficulty _parseDifficulty(String value) {
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'medium' || 'normal' => RunDifficulty.medium,
    'easy' => RunDifficulty.easy,
    _ => throw FormatException('Invalid --difficulty=$value'),
  };
}

int _parseInteger(String value, String name) {
  final parsed = value.toLowerCase().startsWith('0x')
      ? int.tryParse(value.substring(2), radix: 16)
      : int.tryParse(value);
  if (parsed == null) throw FormatException('Invalid --$name=$value');
  return parsed;
}

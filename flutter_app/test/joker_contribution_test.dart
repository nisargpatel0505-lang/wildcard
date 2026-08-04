import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_balance_audit.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

const _harness = WildcardSimulationHarness();
final _balanceAuditEnabled =
    Platform.environment['WILDCARD_RUN_JOKER_BALANCE'] == '1';
final _auditPhase =
    Platform.environment['WILDCARD_JOKER_BALANCE_PHASE'] ?? 'both';
final _shardCount = _positiveEnvironmentInt(
  'WILDCARD_JOKER_BALANCE_SHARD_COUNT',
  fallback: 1,
);
final _shardIndex = _environmentInt(
  'WILDCARD_JOKER_BALANCE_SHARD_INDEX',
  fallback: 0,
);
final _runs = _positiveEnvironmentInt(
  'WILDCARD_JOKER_BALANCE_RUNS',
  fallback: jokerBalanceDefaultRuns,
);
final _difficulties = _parseDifficulties(
  Platform.environment['WILDCARD_JOKER_BALANCE_DIFFICULTY'] ?? 'medium,easy',
);
final _providedTop12 =
    Platform.environment['WILDCARD_JOKER_TOP12']
        ?.split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false) ??
    const <String>[];

void main() {
  test(
    'matched random-five Joker contribution and top-12 pair audit',
    () {
      _validateOptions();
      // ignore: avoid_print
      print('JOKERCSV_HEADER,$jokerContributionCsvHeader');

      for (final difficulty in _difficulties) {
        final singles = <JokerContributionRow>[];
        if (_auditPhase != 'pairs') {
          for (var index = 0; index < jokerCatalog.length; index++) {
            if (!_belongsToShard(index)) continue;
            final joker = jokerCatalog[index];
            final row = _runRow(
              joker: joker.id,
              rarity: joker.rarity.name,
              forcedJokers: <String>[joker.id],
              difficulty: difficulty,
            );
            singles.add(row);
            // ignore: avoid_print
            print(row.toCsv('JOKERCSV'));
          }
        }

        if (_auditPhase == 'singles') continue;
        final pairIds = _resolveTop12(singles);
        // ignore: avoid_print
        print('PAIRCSV_HEADER,$jokerContributionCsvHeader');
        final pairs = <List<String>>[
          for (var left = 0; left < pairIds.length; left++)
            for (var right = left + 1; right < pairIds.length; right++)
              <String>[pairIds[left], pairIds[right]],
        ];
        for (var index = 0; index < pairs.length; index++) {
          if (!_belongsToShard(index)) continue;
          final ids = pairs[index];
          final rarity = ids.map((id) => jokersById[id]!.rarity.name).join('+');
          final row = _runRow(
            joker: ids.join('+'),
            rarity: rarity,
            forcedJokers: ids,
            difficulty: difficulty,
          );
          // ignore: avoid_print
          print(row.toCsv('PAIRCSV'));
          if (row.pairOver70) {
            // ignore: avoid_print
            print(
              'PAIR_OVER_70,${row.joker},'
              '${row.metrics.winRate.toStringAsFixed(6)},${difficulty.name}',
            );
          }
        }
      }
    },
    skip: _balanceAuditEnabled
        ? false
        : 'Set WILDCARD_RUN_JOKER_BALANCE=1 to run the heavyweight audit.',
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

JokerContributionRow _runRow({
  required String joker,
  required String rarity,
  required List<String> forcedJokers,
  required RunDifficulty difficulty,
}) {
  final cohort = runJokerBalanceMatchedCohort(
    harness: _harness,
    runs: _runs,
    firstSeed: jokerBalanceFirstSeed,
    forcedJokers: forcedJokers,
    difficulty: difficulty,
  );
  expect(
    cohort.treatment.invariantFailures,
    0,
    reason: '$joker treatment must preserve simulator invariants',
  );
  expect(
    cohort.control.invariantFailures,
    0,
    reason: '$joker matched control must preserve simulator invariants',
  );
  return JokerContributionRow(
    joker: joker,
    rarity: rarity,
    difficulty: difficulty,
    metrics: cohort.treatment,
    control: cohort.control,
  );
}

List<String> _resolveTop12(List<JokerContributionRow> singles) {
  final result = _providedTop12.isNotEmpty
      ? _providedTop12
      : _shardCount == 1 && _auditPhase == 'both'
      ? (singles..sort(compareJokerContribution))
            .take(12)
            .map((row) => row.joker)
            .toList(growable: false)
      : throw StateError(
          'Sharded pair runs require WILDCARD_JOKER_TOP12=id1,...,id12 '
          'from the merged matched-control JOKERCSV ranking.',
        );
  if (result.length != 12 ||
      result.toSet().length != 12 ||
      result.any((id) => !jokerCatalog.any((joker) => joker.id == id))) {
    throw ArgumentError.value(
      result,
      'WILDCARD_JOKER_TOP12',
      'Provide exactly 12 unique public Joker ids',
    );
  }
  return result;
}

void _validateOptions() {
  if (_shardIndex < 0 || _shardIndex >= _shardCount) {
    throw ArgumentError.value(
      _shardIndex,
      'WILDCARD_JOKER_BALANCE_SHARD_INDEX',
      'Must be in [0, ${_shardCount - 1}]',
    );
  }
  if (!const <String>{'both', 'singles', 'pairs'}.contains(_auditPhase)) {
    throw ArgumentError.value(_auditPhase, 'WILDCARD_JOKER_BALANCE_PHASE');
  }
}

List<RunDifficulty> _parseDifficulties(String source) {
  final result = source
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .map(
        (value) => switch (value) {
          'medium' || 'normal' => RunDifficulty.medium,
          'easy' => RunDifficulty.easy,
          _ => throw FormatException(
            'Invalid WILDCARD_JOKER_BALANCE_DIFFICULTY=$value',
          ),
        },
      )
      .toSet()
      .toList(growable: false);
  if (result.isEmpty) {
    throw const FormatException('Choose Medium and/or Easy');
  }
  return result;
}

bool _belongsToShard(int cohortIndex) =>
    cohortIndex % _shardCount == _shardIndex;

int _environmentInt(String name, {required int fallback}) =>
    int.tryParse(Platform.environment[name] ?? '') ?? fallback;

int _positiveEnvironmentInt(String name, {required int fallback}) {
  final value = _environmentInt(name, fallback: fallback);
  return value > 0 ? value : fallback;
}

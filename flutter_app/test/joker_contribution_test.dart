import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
final _providedTop12 =
    Platform.environment['WILDCARD_JOKER_TOP12']
        ?.split(',')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false) ??
    const <String>[];

void main() {
  test(
    'matched-seed Joker contribution and top-12 pair audit',
    () {
      _validateShard();
      final baseline = _runMetrics(const <String>[]);
      expect(baseline.invariantFailures, 0);

      // Prefixes and the first four reader fields are a stable parsing
      // contract; the remaining raw metrics are intentionally additive.
      // ignore: avoid_print
      print('JOKERCSV_HEADER,$jokerContributionCsvHeader');
      // ignore: avoid_print
      print(
        JokerContributionRow(
          joker: 'BASELINE',
          rarity: 'baseline',
          metrics: baseline,
          baseline: baseline,
        ).toCsv('JOKERCSV'),
      );

      final singles = <JokerContributionRow>[];
      if (_auditPhase != 'pairs') {
        for (var index = 0; index < jokerCatalog.length; index++) {
          if (!_belongsToShard(index)) continue;
          final joker = jokerCatalog[index];
          final metrics = _runMetrics(<String>[joker.id]);
          expect(
            metrics.invariantFailures,
            0,
            reason: '${joker.id} must preserve simulator invariants',
          );
          final row = JokerContributionRow(
            joker: joker.id,
            rarity: joker.rarity.name,
            metrics: metrics,
            baseline: baseline,
          );
          singles.add(row);
          // ignore: avoid_print
          print(row.toCsv('JOKERCSV'));
        }
      }

      if (_auditPhase == 'singles') return;
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
        final metrics = _runMetrics(ids);
        expect(
          metrics.invariantFailures,
          0,
          reason: '${ids.join('+')} must preserve simulator invariants',
        );
        final rarity = ids.map((id) => jokersById[id]!.rarity.name).join('+');
        // Every pair arm is the same two-starter baseline plus the two forced
        // Jokers, with the same seeded shop randomness as the baseline.
        // ignore: avoid_print
        print(
          JokerContributionRow(
            joker: ids.join('+'),
            rarity: rarity,
            metrics: metrics,
            baseline: baseline,
          ).toCsv('PAIRCSV'),
        );
      }
    },
    skip: _balanceAuditEnabled
        ? false
        : 'Set WILDCARD_RUN_JOKER_BALANCE=1 to run the heavyweight audit.',
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

JokerBalanceMetrics _runMetrics(List<String> forcedJokers) =>
    JokerBalanceMetrics.fromReport(
      _harness.runBatch(
        jokerBalanceConfig(
          runs: jokerBalanceDefaultRuns,
          forcedJokers: forcedJokers,
        ),
      ),
    );

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
          'from the merged JOKERCSV contribution ranking.',
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

void _validateShard() {
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

bool _belongsToShard(int cohortIndex) =>
    cohortIndex % _shardCount == _shardIndex;

int _environmentInt(String name, {required int fallback}) =>
    int.tryParse(Platform.environment[name] ?? '') ?? fallback;

int _positiveEnvironmentInt(String name, {required int fallback}) {
  final value = _environmentInt(name, fallback: fallback);
  return value > 0 ? value : fallback;
}

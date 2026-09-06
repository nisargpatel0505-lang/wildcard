import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/random_streams.dart';
import 'package:wildcard/domain/simulation.dart';

const _midIds = <String>[
  ...starterJokerIds,
  'acemag',
  'momentum',
  'inktrade',
  'triple3',
  'dividend',
  'couple',
  'sniper',
  'piggy',
  'cleaner',
  'flushfund',
  'wire',
  'dumpster',
  'overtime',
  'collector',
  'roller',
];
const _exitHeats = <int>[1, 3, 6, 8, 9, 12, 15, 18, 24, 30];
const _policies = <SimulationStrategy>[
  SimulationStrategy.handRanking,
  SimulationStrategy.adaptive,
  SimulationStrategy.pairBuilder,
  SimulationStrategy.flushBuilder,
];

/// Single-process study. Raw runs stream to JSONL, keeping RAM bounded.
/// Default is a 3-seed pilot. Larger cohorts require explicit CLI options.
/// dart run tool/astra_mode_economy_study.dart --runs=3 --scope=pilot
/// dart run tool/astra_mode_economy_study.dart --runs=30 --scope=full
void main(List<String> args) {
  if (args.contains('--verify-only')) {
    _verifyHarnessObservation();
    return;
  }
  String option(String name, String fallback) =>
      args
          .where((arg) => arg.startsWith('--$name='))
          .map((arg) => arg.substring(name.length + 3))
          .firstOrNull ??
      fallback;
  final runs = int.parse(option('runs', '3'));
  final full = option('scope', 'pilot') == 'full';
  final maxHeat = int.parse(option('max-heat', '24'));
  final seedOffset = int.parse(option('seed-offset', '0'));
  final starterPolicy = option('starter', 'policy');
  final out = option('out', 'build/astra-mode-study');
  final allowedModes = option(
    'modes',
    'normal,daily,gauntlet,endless',
  ).split(',');
  final allowedPolicies = option(
    'policies',
    _policies.map((p) => p.name).join(','),
  ).split(',');
  final allowedCollections = option('collections', 'new,mid,full').split(',');
  final allowedDifficulties = option(
    'difficulties',
    'easy,medium,hard',
  ).split(',');
  final allowedRules = option('rules', 'play,astra').split(',');
  if (runs < 1 || runs > 500 || maxHeat < 13 || maxHeat > 60) {
    throw ArgumentError('runs must be 1..500 and max-heat 13..60');
  }
  for (final id in _midIds) {
    if (!jokersById.containsKey(id)) {
      throw StateError('Unknown mid discovery $id');
    }
  }
  final cells = <_Cell>[];
  for (final mode in allowedModes) {
    if (!['normal', 'daily', 'gauntlet', 'endless'].contains(mode)) {
      throw ArgumentError('Unknown mode $mode');
    }
    final shared = mode == 'daily' || mode == 'gauntlet';
    for (final difficulty in RunDifficulty.values) {
      if (!allowedDifficulties.contains(difficulty.name)) continue;
      if (shared && difficulty != RunDifficulty.medium) continue;
      for (final policy in _policies.where(
        (p) => allowedPolicies.contains(p.name),
      )) {
        for (final collection in allowedCollections) {
          if (!['new', 'mid', 'full'].contains(collection)) {
            throw ArgumentError('Unknown collection $collection');
          }
          if (!full && !_pilotCell(mode, difficulty, policy, collection)) {
            continue;
          }
          for (final rule in shared ? ['shared'] : allowedRules) {
            if (!['play', 'astra', 'shared'].contains(rule)) {
              throw ArgumentError('Unknown rule $rule');
            }
            cells.add(_Cell(mode, difficulty, policy, collection, rule));
          }
        }
      }
    }
  }
  if (cells.isEmpty) {
    throw ArgumentError('The selected filters produce no cells');
  }
  final rawFile = File('$out.runs.jsonl')..parent.createSync(recursive: true);
  final raw = rawFile.openSync(mode: FileMode.write);
  final summaries = <Map<String, Object?>>[];
  final sourceHashes = _sourceHashes();
  final started = DateTime.now();
  var failures = 0;
  const harness = WildcardSimulationHarness();
  final timing = _Timing.readSource();
  stdout.writeln(
    'cells=${cells.length}, runs/cell=$runs, total=${cells.length * runs}; single process',
  );
  try {
    for (final cell in cells) {
      final records = <Map<String, Object?>>[];
      for (var index = 0; index < runs; index++) {
        final date = DateTime.utc(2026, 9, 5)
            .add(Duration(days: index + seedOffset))
            .toIso8601String()
            .substring(0, 10);
        final seed = cell.mode == 'daily'
            ? dailySeed(date)
            : 0xA5709000 + index + seedOffset;
        final starter = cell.rule != 'astra'
            ? null
            : starterPolicy == 'rotate'
            ? astraStarterChoices(seed).first.id
            : astraStarterJokerIds.contains(starterPolicy)
            ? starterPolicy
            : cell.policy == SimulationStrategy.flushBuilder
            ? 'flushfund'
            : 'polish';
        final config = SimulationConfig(
          runs: 1,
          firstSeed: seed,
          strategy: cell.policy,
          mode: cell.runMode,
          difficulty: cell.difficulty,
          maxHeat: cell.mode == 'endless'
              ? maxHeat
              : cell.mode == 'gauntlet'
              ? gauntletHeats
              : 12,
          initialJokers: starter == null ? const [] : [starter],
          allJokersUnlocked: cell.collection == 'full',
          discoveredJokerIds: cell.discoveryIds,
          continueEndless: cell.mode == 'endless',
          astraEconomy: cell.rule == 'astra',
          captureHeatCheckpoints: true,
        );
        final result = harness.runBatch(config).results.single;
        final checks = _fidelityFailures(cell, result, maxHeat);
        failures += checks.length + result.invariantFailures.length;
        final record = _record(
          cell,
          result,
          date,
          starter,
          maxHeat,
          timing,
          checks,
        );
        raw.writeStringSync('${jsonEncode(record)}\n');
        records.add(record);
      }
      final summary = _summarize(cell, records);
      summaries.add(summary);
      stdout.writeln(jsonEncode(summary));
    }
  } finally {
    raw.closeSync();
  }
  final finalSourceHashes = _sourceHashes();
  if (jsonEncode(sourceHashes) != jsonEncode(finalSourceHashes)) {
    throw StateError(
      'Analysis source changed during this batch; do not use outputs',
    );
  }
  final report = <String, Object?>{
    'sourceHead': '700372f + analysis-only harness instrumentation',
    'sourceGitBlobHashes': sourceHashes,
    'sourceHashesUnchangedAtCompletion': true,
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'scope': full ? 'full matrix' : 'selected mode/policy pilot',
    'cells': summaries,
    'runsPerCell': runs,
    'seedOffset': seedOffset,
    'starterPolicy': starterPolicy,
    'totalRuns': cells.length * runs,
    'elapsedSeconds': DateTime.now().difference(started).inMilliseconds / 1000,
    'invariantAndFidelityFailures': failures,
    'rawRunFile': rawFile.absolute.path,
    'endlessCap': maxHeat,
    'discoveryPools': {
      'new': starterJokerIds,
      'mid': _midIds,
      'full': jokerCatalog.map((joker) => joker.id).toList(),
    },
    'methodology': [
      'Same seed per index across rules/policies/collections; Daily uses actual UTC date hashes.',
      'Normal compares free baseline (after guided first run) versus free Astra draft.',
      'Default draft: Pair Polisher for adaptive/basic/pair policies; Flush Fund for flush policy. '
          'The --starter option supports rotation or an explicit route for sensitivity checks.',
      'Daily/Gauntlet are shared rules, always Medium internally; no synthetic Easy/Hard variants.',
      'Current live Daily shop discovery restriction is retained, not presumed full-catalogue.',
      'Gauntlet entry gate requires a prior Normal win; collection sizes are conditional scenarios.',
      'Endless starts at Heat 1, passes Heat 12 victory without an extra shop, then continues.',
      'Endless cap is censoring, not victory; Normal win/bonus is counted once at Heat 12.',
      'No paid starter, stake, revive, ads, login, mission, journey, or leaderboard-prize income.',
      'Heat checkpoints are captured before that Heat\'s shop, matching immediate retained-reward exit.',
      'Early-exit strategy analysis must retain attempts failing before the chosen checkpoint '
          'using their terminal reward/time; averaging only survivors overstates farming rates.',
      'The real Dart scorer, targets, effects and seeded domain strategies are used; no live gameplay changed.',
      'Simulation matches the default phone rank-descending/suit-tie table order, '
          'selected-table scoring order, and post-supply deck normalization. '
          'Suit-sort/player reordering is not modeled.',
      'Bot policies are not measured human skill percentiles; choice/discard/search limitations remain.',
      'Authored animation waits derive from the current source; human choice/shop durations are assumptions.',
      'Timing estimates exclude ads, chest openings, tutorial, load/network waits, and victory video.',
      'A sparse pilot establishes instrumentation and direction, not optimal economy percentages.',
    ],
    'timing': timing.toJson(),
  };
  File('$out.summary.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'DONE ${report['totalRuns']} runs in ${report['elapsedSeconds']}s; failures=$failures; $out.summary.json',
  );
  if (failures > 0) exitCode = 1;
}

Map<String, String> _sourceHashes() {
  const paths = [
    'lib/domain/simulation.dart',
    'lib/domain/scoring_engine.dart',
    'lib/domain/game_rules.dart',
    'lib/domain/economy.dart',
    'lib/domain/astra_progression.dart',
    'lib/game/game_models.dart',
    'tool/astra_mode_economy_study.dart',
  ];
  final result = Process.runSync('git', ['hash-object', ...paths]);
  if (result.exitCode != 0) {
    throw StateError('Could not fingerprint study sources: ${result.stderr}');
  }
  final hashes = (result.stdout as String).trim().split(RegExp(r'\s+'));
  if (hashes.length != paths.length) {
    throw StateError('Incomplete source fingerprint');
  }
  return {
    for (var index = 0; index < paths.length; index++)
      paths[index]: hashes[index],
  };
}

bool _pilotCell(
  String mode,
  RunDifficulty difficulty,
  SimulationStrategy policy,
  String collection,
) {
  if (mode == 'normal') {
    return (difficulty == RunDifficulty.easy &&
            policy == SimulationStrategy.handRanking &&
            collection == 'new') ||
        (difficulty == RunDifficulty.medium &&
            policy == SimulationStrategy.adaptive &&
            collection == 'mid') ||
        (difficulty == RunDifficulty.medium &&
            [
              SimulationStrategy.pairBuilder,
              SimulationStrategy.flushBuilder,
            ].contains(policy) &&
            collection == 'mid') ||
        (difficulty == RunDifficulty.hard &&
            policy == SimulationStrategy.adaptive &&
            collection == 'full');
  }
  if (mode == 'daily') return policy == SimulationStrategy.adaptive;
  if (mode == 'gauntlet') {
    return policy == SimulationStrategy.adaptive && collection == 'full';
  }
  return difficulty == RunDifficulty.medium &&
      policy == SimulationStrategy.adaptive &&
      collection == 'full';
}

class _Cell {
  const _Cell(
    this.mode,
    this.difficulty,
    this.policy,
    this.collection,
    this.rule,
  );
  final String mode;
  final RunDifficulty difficulty;
  final SimulationStrategy policy;
  final String collection;
  final String rule;
  RunMode get runMode => switch (mode) {
    'daily' => RunMode.daily,
    'gauntlet' => RunMode.gauntlet,
    _ => RunMode.normal,
  };
  List<String>? get discoveryIds => switch (collection) {
    'new' => starterJokerIds,
    'mid' => _midIds,
    _ => null,
  };
  String get id => '$mode/${difficulty.name}/${policy.name}/$collection/$rule';
  Map<String, Object?> toJson() => {
    'cellId': id,
    'mode': mode,
    'difficulty': difficulty.name,
    'policy': policy.name,
    'collection': collection,
    'discoveryCount': discoveryIds?.length ?? jokerCatalog.length,
    'rules': rule,
  };
}

int _coins(_Cell cell, int cleared) {
  if (cell.mode == 'daily') return 0;
  var amount = 0;
  for (var heat = 1; heat <= cleared; heat++) {
    amount += cell.rule == 'astra'
        ? astraAccountReward(heat)
        : accountReward(heat);
  }
  final completion = cell.mode == 'gauntlet' ? gauntletHeats : 12;
  if (cleared >= completion) amount += standardCompletionBonus;
  return amount;
}

List<String> _fidelityFailures(_Cell cell, SimulatedRunResult result, int cap) {
  final failures = <String>[];
  if (result.heatCheckpoints.isEmpty) failures.add('Missing Heat checkpoints');
  if (cell.mode == 'gauntlet' && result.heatsCleared > gauntletHeats) {
    failures.add('Gauntlet exceeds 8');
  }
  if (cell.mode == 'daily' && result.heatsCleared > 12) {
    failures.add('Daily exceeds 12');
  }
  if (cell.mode == 'endless') {
    if (result.heatsCleared > cap) failures.add('Endless exceeds cap');
    final twelve = result.heatCheckpoints
        .where((c) => c.heat == 12 && c.cleared)
        .firstOrNull;
    final thirteen = result.heatCheckpoints
        .where((c) => c.heat == 13)
        .firstOrNull;
    if (twelve != null &&
        thirteen != null &&
        twelve.shopsVisited != thirteen.shopsVisited) {
      failures.add('Unexpected shop between Heat 12 and 13');
    }
  }
  return failures;
}

Map<String, Object?> _record(
  _Cell cell,
  SimulatedRunResult result,
  String date,
  String? starter,
  int cap,
  _Timing timing,
  List<String> checks,
) {
  final last = result.heatCheckpoints.last;
  final censored = cell.mode == 'endless' && result.heatsCleared >= cap;
  final won =
      result.heatsCleared >= (cell.mode == 'gauntlet' ? gauntletHeats : 12);
  final coins = _coins(cell, result.heatsCleared);
  final twelve = result.heatCheckpoints
      .where((c) => c.heat == 12 && c.cleared)
      .firstOrNull;
  final duration = timing.estimate(last, result.heatsCleared);
  return {
    ...cell.toJson(),
    'seed': result.seed,
    if (cell.mode == 'daily') 'dailyDate': date,
    'starter': starter,
    'heatsCleared': result.heatsCleared,
    'terminalHeat': result.terminalHeat,
    'standardModeWon': won,
    'censoredAtHeatCap': censored,
    'terminalReason': censored
        ? 'study_cap'
        : won && cell.mode != 'endless'
        ? 'victory_banked'
        : 'target_not_met',
    'handsPlayed': result.handsPlayed,
    'discardsUsed': result.discardsUsed,
    'shopsVisited': result.shopsVisited,
    'jokersBought': result.jokersBought,
    'suppliesBought': result.suppliesBought.map(
      (key, value) => MapEntry(key.name, value),
    ),
    'finalJokers': result.finalJokers,
    'totalScore': result.totalScore,
    'finalRunCoins': result.finalRunCoins,
    'accountCoinsEarned': coins,
    'modeledTimeSeconds': duration,
    'modeledCoinsPerMinute': duration.map(
      (key, value) => MapEntry(key, value > 0 ? coins * 60 / value : 0),
    ),
    'earlyExitCheckpoints': [
      for (final checkpoint in result.heatCheckpoints)
        if (checkpoint.cleared && _exitHeats.contains(checkpoint.heat))
          {
            'exitAfterHeat': checkpoint.heat,
            'accountCoinsRetained': _coins(cell, checkpoint.heat),
            'actions': checkpoint.toJson(),
            'modeledTimeSeconds': timing.estimate(checkpoint, checkpoint.heat),
          },
    ],
    if (cell.mode == 'endless')
      'endlessSegment': twelve == null
          ? null
          : {
              'heatsClearedAfter12': math.max(0, result.heatsCleared - 12),
              'additionalCoinsAfter12': coins - _coins(cell, 12),
              'additionalHandsAfter12': result.handsPlayed - twelve.handsPlayed,
              'additionalDiscardsAfter12':
                  result.discardsUsed - twelve.discardsUsed,
              'additionalTimeSeconds': duration.map(
                (key, value) =>
                    MapEntry(key, value - timing.estimate(twelve, 12)[key]!),
              ),
            },
    'heatCheckpoints': result.heatCheckpoints
        .map((checkpoint) => checkpoint.toJson())
        .toList(),
    'invariantFailures': result.invariantFailures,
    'fidelityFailures': checks,
  };
}

Map<String, Object?> _summarize(
  _Cell cell,
  List<Map<String, Object?>> records,
) {
  double mean(String field) =>
      records.fold<double>(0, (sum, r) => sum + (r[field] as num).toDouble()) /
      records.length;
  final wins = records.where((r) => r['standardModeWon'] == true).length;
  final coins =
      records.map((r) => (r['accountCoinsEarned'] as num).toDouble()).toList()
        ..sort();
  final times = <String, double>{};
  final rates = <String, double>{};
  for (final key
      in (records.first['modeledTimeSeconds'] as Map).keys.cast<String>()) {
    final seconds = records.fold<double>(
      0,
      (sum, r) =>
          sum + ((r['modeledTimeSeconds'] as Map)[key] as num).toDouble(),
    );
    times[key] = seconds / records.length;
    rates[key] = seconds > 0 ? coins.reduce((a, b) => a + b) * 60 / seconds : 0;
  }
  return {
    ...cell.toJson(),
    'runs': records.length,
    'wins': wins,
    'winRate': wins / records.length,
    'censoredRuns': records.where((r) => r['censoredAtHeatCap'] == true).length,
    'meanHeatsCleared': mean('heatsCleared'),
    'meanHands': mean('handsPlayed'),
    'meanDiscards': mean('discardsUsed'),
    'meanCoins': mean('accountCoinsEarned'),
    'medianCoins': coins.length.isOdd
        ? coins[coins.length ~/ 2]
        : (coins[coins.length ~/ 2 - 1] + coins[coins.length ~/ 2]) / 2,
    'p10Coins': coins[((coins.length - 1) * .1).floor()],
    'p90Coins': coins[((coins.length - 1) * .9).floor()],
    'meanModeledSeconds': times,
    'aggregateModeledCoinsPerMinute': rates,
    'failures': records.fold<int>(
      0,
      (sum, r) =>
          sum +
          (r['invariantFailures'] as List).length +
          (r['fidelityFailures'] as List).length,
    ),
  };
}

class _Timing {
  const _Timing(this.normal, this.fast);
  final Map<String, int> normal;
  final Map<String, int> fast;
  factory _Timing.readSource() {
    final source = File('lib/game/game_models.dart').readAsStringSync();
    Map<String, int> pacing(String name) {
      final body = RegExp(
        'static const $name = ScoringPacing\\(([\\s\\S]*?)\\);',
      ).firstMatch(source)?.group(1);
      if (body == null) {
        throw StateError('Cannot identify authored $name pacing');
      }
      return {
        for (final key in [
          'leadIn',
          'cardBeat',
          'jokerBeat',
          'resultHold',
          'transitionHold',
        ])
          key: int.parse(
            RegExp(
              '$key: Duration\\(milliseconds: (\\d+)\\)',
            ).firstMatch(body)!.group(1)!,
          ),
      };
    }

    return _Timing(pacing('normal'), pacing('fast'));
  }
  double authored(SimulatedHeatCheckpoint point, int cleared, bool isFast) {
    final p = isFast ? fast : normal;
    // Seven has two explicit onset gaps in scoring_timeline.dart at 700372f.
    return (point.handsPlayed * (p['leadIn']! + p['resultHold']!) +
            point.jokerEvents * p['jokerBeat']! +
            point.nonJokerEvents * p['cardBeat']! +
            point.luckySevenEvents * (isFast ? 430 + 330 : 850 + 592) +
            cleared * p['transitionHold']!) /
        1000;
  }

  Map<String, double> estimate(SimulatedHeatCheckpoint point, int cleared) => {
    'authoredNormalAnimationOnly': authored(point, cleared, false),
    'authoredFastAnimationOnly': authored(point, cleared, true),
    'quickFast':
        authored(point, cleared, true) +
        point.handsPlayed * 3 +
        point.discardsUsed * 2 +
        point.shopsVisited * 8 +
        10,
    'typicalNormal':
        authored(point, cleared, false) +
        point.handsPlayed * 8 +
        point.discardsUsed * 5 +
        point.shopsVisited * 18 +
        20,
    'deliberateNormal':
        authored(point, cleared, false) +
        point.handsPlayed * 15 +
        point.discardsUsed * 8 +
        point.shopsVisited * 30 +
        30,
  };
  Map<String, Object?> toJson() => {
    'sourcePacingMilliseconds': {'normal': normal, 'fast': fast},
    'assumedDecisionSeconds': {
      'quickFast': {'hand': 3, 'discard': 2, 'shop': 8, 'entry': 10},
      'typicalNormal': {'hand': 8, 'discard': 5, 'shop': 18, 'entry': 20},
      'deliberateNormal': {'hand': 15, 'discard': 8, 'shop': 30, 'entry': 30},
    },
    'animationOnlyIsNotHumanRunDuration': true,
  };
}

void _verifyHarnessObservation() {
  const harness = WildcardSimulationHarness();
  var parityPairs = 0;
  for (final mode in RunMode.values) {
    SimulatedRunResult run(bool capture) => harness
        .runBatch(
          SimulationConfig(
            runs: 1,
            firstSeed: 0xA5709090,
            mode: mode,
            maxHeat: mode == RunMode.gauntlet ? gauntletHeats : 12,
            initialJokers: const [],
            strategy: SimulationStrategy.adaptive,
            captureHeatCheckpoints: capture,
          ),
        )
        .results
        .single;
    final plain = run(false).toJson();
    final observed = run(true).toJson()..remove('heatCheckpoints');
    if (jsonEncode(plain) != jsonEncode(observed)) {
      throw StateError('Instrumentation changed ${mode.name} outcome');
    }
    parityPairs++;
  }
  final boundaryEvidence = <Map<String, Object?>>[];
  for (final gauntlet in [false, true]) {
    var found = false;
    for (var seed = 0; seed < 8 && !found; seed++) {
      final result = harness
          .runBatch(
            SimulationConfig(
              runs: 1,
              firstSeed: 0x7100E000 + seed,
              mode: gauntlet ? RunMode.gauntlet : RunMode.normal,
              difficulty: RunDifficulty.easy,
              strategy: SimulationStrategy.adaptive,
              initialJokers: const [
                'glass_joystick',
                'roller',
                'polish',
                'danger_music',
                'allin',
              ],
              maxHeat: gauntlet ? 8 : 14,
              continueEndless: !gauntlet,
              captureHeatCheckpoints: true,
            ),
          )
          .results
          .single;
      final cell = _Cell(
        gauntlet ? 'gauntlet' : 'endless',
        RunDifficulty.easy,
        SimulationStrategy.adaptive,
        'full',
        'play',
      );
      final failures = _fidelityFailures(cell, result, 14);
      if (failures.isNotEmpty || result.invariantFailures.isNotEmpty) {
        throw StateError(
          'Boundary fidelity failed: $failures ${result.invariantFailures}',
        );
      }
      found = gauntlet ? result.heatsCleared == 8 : result.heatsCleared >= 12;
      if (found) {
        if (gauntlet && result.shopsVisited != 7) {
          throw StateError('Gauntlet victory incorrectly opens an eighth shop');
        }
        boundaryEvidence.add({
          'mode': cell.mode,
          'seed': result.seed,
          'cleared': result.heatsCleared,
          'shops': result.shopsVisited,
        });
      }
    }
    if (!found) {
      throw StateError(
        'Could not exercise ${gauntlet ? 'Gauntlet8' : 'Endless12'} boundary',
      );
    }
  }
  stdout.writeln(
    jsonEncode({
      'instrumentationParityPairs': parityPairs,
      'boundaryEvidence': boundaryEvidence,
      'result': 'PASS',
    }),
  );
}

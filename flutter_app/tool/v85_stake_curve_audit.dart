import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

const _harness = WildcardSimulationHarness();

// Frozen v8.5 baseline used for honest before/after evidence even after the
// production curve changes.
const _baselinePayoutPerHundred = <int>[
  0,
  5,
  10,
  18,
  28,
  40,
  55,
  72,
  92,
  115,
  140,
  170,
  200,
];

const _baselineMultipliers = <RunDifficulty, double>{
  RunDifficulty.easy: 0.60,
  RunDifficulty.medium: 1.00,
  RunDifficulty.hard: 1.60,
};

const _starterIds = <String>[
  'copper',
  'presser',
  'retainer',
  'even',
  'lowball',
  'uniform',
  'fulltable',
  'polish',
  'opening_act',
  'face_value',
];

const _midDiscoveryIds = <String>[
  ..._starterIds,
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

void main(List<String> arguments) {
  final runs = _intOption(arguments, '--runs', fallback: 100);
  final outputPath = _stringOption(arguments, '--output');
  final mergePaths = _stringOption(arguments, '--merge');
  if (mergePaths != null) {
    if (outputPath == null) {
      throw ArgumentError('--output is required with --merge');
    }
    _mergeShardOutputs(
      mergePaths.split(',').where((path) => path.trim().isNotEmpty).toList(),
      outputPath,
    );
    return;
  }
  final difficultyOption =
      _stringOption(arguments, '--difficulty')?.toLowerCase() ?? 'all';
  final difficulties = difficultyOption == 'all'
      ? RunDifficulty.values
      : <RunDifficulty>[
          RunDifficulty.values.firstWhere(
            (difficulty) => difficulty.name == difficultyOption,
            orElse: () => throw ArgumentError.value(
              difficultyOption,
              '--difficulty',
              'Expected easy, medium, hard, or all',
            ),
          ),
        ];
  if (runs < 1) {
    throw ArgumentError.value(runs, '--runs', 'Must be positive');
  }
  final fullDiscovery = jokerCatalog
      .map((joker) => joker.id)
      .toList(growable: false);
  final profiles = <_Profile>[
    const _Profile(
      id: 'new_weak',
      strategy: SimulationStrategy.handRanking,
      discoveredIds: _starterIds,
    ),
    const _Profile(
      id: 'mid',
      strategy: SimulationStrategy.pairBuilder,
      discoveredIds: _midDiscoveryIds,
    ),
    _Profile(
      id: 'skilled_late',
      strategy: SimulationStrategy.adaptive,
      discoveredIds: fullDiscovery,
    ),
  ];
  final rows = <Map<String, Object?>>[];
  for (final difficulty in difficulties) {
    for (final profile in profiles) {
      final stopwatch = Stopwatch()..start();
      final report = _harness.runBatch(
        SimulationConfig(
          runs: runs,
          firstSeed: 0x71010000,
          strategy: profile.strategy,
          difficulty: difficulty,
          initialJokers: const <String>['copper', 'polish'],
          allJokersUnlocked: false,
          discoveredJokerIds: profile.discoveredIds,
        ),
      );
      stopwatch.stop();
      if (report.invariantFailureCount != 0) {
        throw StateError(
          '${difficulty.name}/${profile.id} produced '
          '${report.invariantFailureCount} invariant failures',
        );
      }
      final histogram = _clearedHistogram(report);
      final baselineEv = _expectedReturn(
        histogram,
        _baselinePayoutPerHundred,
        _baselineMultipliers[difficulty]!,
      );
      final liveEv = _expectedReturn(
        histogram,
        stakePayoutPerHundred,
        difficulty.stakeMultiplier,
      );
      final row = <String, Object?>{
        'difficulty': difficulty.name,
        'profile': profile.id,
        'strategy': profile.strategy.name,
        'discoveredJokers': profile.discoveredIds.length,
        'runs': report.results.length,
        'wins': report.wins,
        'winRate': report.winRate,
        'averageHeatsCleared': report.averageHeatsCleared,
        'heatsClearedHistogram': <String, int>{
          for (final entry in histogram.entries) '${entry.key}': entry.value,
        },
        'baselineEvPerCoin': baselineEv,
        'liveEvPerCoin': liveEv,
        'elapsedSeconds': stopwatch.elapsedMilliseconds / 1000,
      };
      rows.add(row);
      stdout.writeln(
        '${difficulty.name.padRight(6)} ${profile.id.padRight(13)} '
        'wins=${report.wins}/$runs '
        'heat=${report.averageHeatsCleared.toStringAsFixed(3)} '
        'old=${baselineEv.toStringAsFixed(4)} '
        'live=${liveEv.toStringAsFixed(4)} '
        'time=${stopwatch.elapsed.inSeconds}s',
      );
    }
  }
  final output = <String, Object?>{
    'schema': 1,
    'runsPerCohort': runs,
    'seedBase': '0x71010000',
    'difficultyFilter': difficultyOption,
    'baseline': <String, Object?>{
      'payoutPerHundred': _baselinePayoutPerHundred,
      'multipliers': <String, double>{
        for (final entry in _baselineMultipliers.entries)
          entry.key.name: entry.value,
      },
    },
    'live': <String, Object?>{
      'payoutPerHundred': stakePayoutPerHundred,
      'multipliers': <String, double>{
        for (final difficulty in RunDifficulty.values)
          difficulty.name: difficulty.stakeMultiplier,
      },
    },
    'cohorts': rows,
    'notes': const <String>[
      'The same deterministic gameplay results feed baseline and live payout calculations.',
      'No scoring, targets, deck order, shop order, or RNG stream is modified by this audit.',
      'new_weak = immediate-score handRanking policy with the 10-Joker starter discovery pool.',
      'mid = pairBuilder policy with a fixed 25-Joker discovery pool.',
      'skilled_late = adaptive policy with all 102 public Jokers discovered.',
      'EV is the mean payout divided by stake at stake=100, including integer rounding.',
    ],
  };
  final encoded = '${const JsonEncoder.withIndent('  ').convert(output)}\n';
  if (outputPath != null) {
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(encoded);
    stdout.writeln('WROTE ${file.absolute.path}');
  }
}

void _mergeShardOutputs(List<String> paths, String outputPath) {
  if (paths.length != RunDifficulty.values.length) {
    throw ArgumentError.value(
      paths,
      '--merge',
      'Expected exactly one Easy, Medium, and Hard shard',
    );
  }
  final shards = paths
      .map(
        (path) =>
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, Object?>,
      )
      .toList();
  final runs = shards.first['runsPerCohort']! as int;
  final baseline = shards.first['baseline']! as Map<String, Object?>;
  final live = shards.first['live']! as Map<String, Object?>;
  final cohorts = <Map<String, Object?>>[];
  for (final shard in shards) {
    if (shard['runsPerCohort'] != runs ||
        jsonEncode(shard['baseline']) != jsonEncode(baseline) ||
        jsonEncode(shard['live']) != jsonEncode(live)) {
      throw StateError('Stake evidence shards use different configurations');
    }
    cohorts.addAll(
      (shard['cohorts']! as List<Object?>).cast<Map<String, Object?>>(),
    );
  }
  final expectedDifficulties = RunDifficulty.values
      .map((difficulty) => difficulty.name)
      .toSet();
  final actualDifficulties = cohorts
      .map((row) => row['difficulty']! as String)
      .toSet();
  if (cohorts.length != 9 ||
      !actualDifficulties.containsAll(expectedDifficulties) ||
      !expectedDifficulties.containsAll(actualDifficulties)) {
    throw StateError(
      'Merged evidence must contain three profiles for every difficulty',
    );
  }
  cohorts.sort((left, right) {
    final leftDifficulty = RunDifficulty.values.indexWhere(
      (difficulty) => difficulty.name == left['difficulty'],
    );
    final rightDifficulty = RunDifficulty.values.indexWhere(
      (difficulty) => difficulty.name == right['difficulty'],
    );
    final difficultyOrder = leftDifficulty.compareTo(rightDifficulty);
    if (difficultyOrder != 0) return difficultyOrder;
    return (left['profile']! as String).compareTo(right['profile']! as String);
  });
  final output = <String, Object?>{
    'schema': 1,
    'runsPerCohort': runs,
    'totalRuns': cohorts.length * runs,
    'seedBase': shards.first['seedBase'],
    'difficultyFilter': 'merged',
    'baseline': baseline,
    'live': live,
    'cohorts': cohorts,
    'notes': shards.first['notes'],
    'sourceShards': paths,
  };
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  stdout.writeln('WROTE ${file.absolute.path}');
}

Map<int, int> _clearedHistogram(SimulationBatchReport report) {
  final histogram = <int, int>{};
  for (final result in report.results) {
    histogram[result.heatsCleared] = (histogram[result.heatsCleared] ?? 0) + 1;
  }
  return Map<int, int>.fromEntries(
    histogram.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key)),
  );
}

double _expectedReturn(
  Map<int, int> histogram,
  List<int> curve,
  double multiplier,
) {
  var totalPayout = 0;
  var runs = 0;
  for (final entry in histogram.entries) {
    totalPayout +=
        (curve[entry.key.clamp(0, 12)] * multiplier).round() * entry.value;
    runs += entry.value;
  }
  return totalPayout / (runs * 100);
}

int _intOption(List<String> arguments, String name, {required int fallback}) {
  final raw = _stringOption(arguments, name);
  return raw == null ? fallback : int.parse(raw);
}

String? _stringOption(List<String> arguments, String name) {
  for (var index = 0; index < arguments.length; index++) {
    final value = arguments[index];
    if (value == name && index + 1 < arguments.length) {
      return arguments[index + 1];
    }
    if (value.startsWith('$name=')) {
      return value.substring(name.length + 1);
    }
  }
  return null;
}

class _Profile {
  const _Profile({
    required this.id,
    required this.strategy,
    required this.discoveredIds,
  });

  final String id;
  final SimulationStrategy strategy;
  final List<String> discoveredIds;
}

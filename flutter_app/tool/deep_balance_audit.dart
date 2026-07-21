import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

const _harness = WildcardSimulationHarness();

void main(List<String> arguments) {
  final section = _option(arguments, 'section') ?? 'all';
  final outputDirectory = Directory('build/simulation')
    ..createSync(recursive: true);
  final selected = switch (section) {
    'strategies' => _strategyCohorts(),
    'starters' => _starterCohorts(),
    'modes' => _modeCohorts(),
    'boss-new' => _bossCohorts(allJokersUnlocked: false),
    'boss-all' => _bossCohorts(allJokersUnlocked: true),
    'boss' => <_AuditCohort>[
      ..._bossCohorts(allJokersUnlocked: false),
      ..._bossCohorts(allJokersUnlocked: true),
    ],
    'all' => <_AuditCohort>[
      ..._strategyCohorts(),
      ..._starterCohorts(),
      ..._modeCohorts(),
    ],
    _ => throw ArgumentError.value(section, 'section'),
  };

  final started = DateTime.now();
  final summaries = <Map<String, Object?>>[];
  for (var index = 0; index < selected.length; index++) {
    final cohort = selected[index];
    stdout.writeln(
      '[${index + 1}/${selected.length}] ${cohort.id}: '
      '${cohort.config.runs} deterministic runs',
    );
    final watch = Stopwatch()..start();
    final report = _harness.runBatch(cohort.config);
    watch.stop();
    final summary = _summarize(cohort, report, watch.elapsed);
    summaries.add(summary);
    stdout.writeln(
      '  wins=${report.wins}/${report.results.length} '
      'avgHeat=${report.averageHeatsCleared.toStringAsFixed(2)} '
      'failures=${report.invariantFailureCount} '
      'time=${watch.elapsed.inSeconds}s',
    );
  }

  final result = <String, Object?>{
    'schema': 1,
    'section': section,
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'elapsedSeconds': DateTime.now().difference(started).inMilliseconds / 1000,
    'totalRuns': selected.fold<int>(0, (sum, item) => sum + item.config.runs),
    'totalInvariantFailures': summaries.fold<int>(
      0,
      (sum, item) => sum + (item['invariantFailures']! as int),
    ),
    'cohorts': summaries,
  };
  final file = File('${outputDirectory.path}/deep_balance_$section.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln('WROTE ${file.absolute.path}');
}

List<_AuditCohort> _strategyCohorts() => <_AuditCohort>[
  for (final strategy in SimulationStrategy.values)
    _AuditCohort(
      'strategy_${strategy.name}',
      SimulationConfig(
        runs: strategy == SimulationStrategy.randomLegal ? 500 : 1000,
        firstSeed: 0x71010000,
        strategy: strategy,
        initialJokers: const <String>['copper', 'polish'],
      ),
    ),
];

List<_AuditCohort> _starterCohorts() {
  final arms = <(String, List<String>)>[
    ('none', const <String>[]),
    for (final id in starterJokerIds) (id, <String>[id]),
    ('guided_copper_polish', const <String>['copper', 'polish']),
  ];
  return <_AuditCohort>[
    for (final arm in arms)
      _AuditCohort(
        'starter_${arm.$1}',
        SimulationConfig(
          runs: 400,
          firstSeed: 0x71020000,
          strategy: SimulationStrategy.adaptive,
          initialJokers: arm.$2,
          allJokersUnlocked: false,
        ),
      ),
  ];
}

List<_AuditCohort> _modeCohorts() => <_AuditCohort>[
  for (final difficulty in RunDifficulty.values)
    _AuditCohort(
      'normal_${difficulty.name}',
      SimulationConfig(
        runs: 250,
        firstSeed: 0x71030000,
        strategy: SimulationStrategy.adaptive,
        difficulty: difficulty,
      ),
    ),
  _AuditCohort(
    'daily_medium_locked_difficulty',
    const SimulationConfig(
      runs: 250,
      firstSeed: 0x71031000,
      strategy: SimulationStrategy.adaptive,
      mode: RunMode.daily,
      // Deliberately pass Hard: Daily must still use Medium internally.
      difficulty: RunDifficulty.hard,
      initialJokers: <String>[],
    ),
  ),
  _AuditCohort(
    'gauntlet_medium',
    const SimulationConfig(
      runs: 300,
      firstSeed: 0x71032000,
      strategy: SimulationStrategy.adaptive,
      mode: RunMode.gauntlet,
      initialJokers: <String>['polish'],
      maxHeat: gauntletHeats,
    ),
  ),
  _AuditCohort(
    'new_player_starter_pool',
    const SimulationConfig(
      runs: 300,
      firstSeed: 0x71033000,
      strategy: SimulationStrategy.adaptive,
      initialJokers: <String>['copper', 'polish'],
      allJokersUnlocked: false,
    ),
  ),
  _AuditCohort(
    'endless_to_heat_20_stress',
    const SimulationConfig(
      runs: 200,
      firstSeed: 0x71034000,
      strategy: SimulationStrategy.adaptive,
      difficulty: RunDifficulty.easy,
      maxHeat: 20,
      continueEndless: true,
      initialJokers: <String>[
        'glass_joystick',
        'roller',
        'polish',
        'danger_music',
        'allin',
      ],
    ),
  ),
];

List<_AuditCohort> _bossCohorts({required bool allJokersUnlocked}) =>
    <_AuditCohort>[
      for (final blocked in const <int>[2, 3])
        for (final target in const <double>[1.10, 1.05, 1.00])
          _AuditCohort(
            'boss_${allJokersUnlocked ? 'all' : 'new'}_'
            '${blocked}blocked_target${(target * 100).round()}',
            SimulationConfig(
              runs: 1000,
              firstSeed: allJokersUnlocked ? 0x71051000 : 0x71050000,
              strategy: SimulationStrategy.adaptive,
              initialJokers: const <String>['copper', 'polish'],
              allJokersUnlocked: allJokersUnlocked,
              bossBlockedJokers: blocked,
              bossTargetMultiplier: target,
            ),
          ),
    ];

Map<String, Object?> _summarize(
  _AuditCohort cohort,
  SimulationBatchReport report,
  Duration elapsed,
) {
  final finalJokers = <String, int>{};
  final supplies = <String, int>{};
  final handTypes = <String, int>{};
  var hands = 0;
  var discards = 0;
  var finalDeckCards = 0;
  var meaningfulShopRuns = 0;
  final finalBuilds = <String>{};
  for (final run in report.results) {
    hands += run.handsPlayed;
    discards += run.discardsUsed;
    finalDeckCards += run.finalDeckSize;
    if (run.jokersBought > 0 || run.suppliesBought.isNotEmpty) {
      meaningfulShopRuns++;
    }
    finalBuilds.add((List<String>.from(run.finalJokers)..sort()).join('|'));
    for (final id in run.finalJokers) {
      finalJokers[id] = (finalJokers[id] ?? 0) + 1;
    }
    for (final entry in run.suppliesBought.entries) {
      supplies[entry.key.name] = (supplies[entry.key.name] ?? 0) + entry.value;
    }
    for (final entry in run.handTypeCounts.entries) {
      handTypes[entry.key.legacyName] =
          (handTypes[entry.key.legacyName] ?? 0) + entry.value;
    }
  }
  final topFinalJokers = finalJokers.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  final failures = <String>[
    for (final run in report.results)
      for (final failure in run.invariantFailures) 'seed ${run.seed}: $failure',
  ];
  final orderedHands = handTypes.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  final handEntropy = _normalizedEntropy(handTypes.values, hands);
  final completionHeat = cohort.config.mode == RunMode.gauntlet
      ? gauntletHeats
      : 12;
  final bossAttempts = report.results
      .where((result) => result.heatsCleared >= completionHeat - 1)
      .length;
  final bossClears = report.results
      .where((result) => result.heatsCleared >= completionHeat)
      .length;
  return <String, Object?>{
    'id': cohort.id,
    ...report.toJson(),
    'elapsedSeconds': elapsed.inMilliseconds / 1000,
    'averageHandsPlayed': hands / report.results.length,
    'averageDiscardsUsed': discards / report.results.length,
    'averageFinalDeckSize': finalDeckCards / report.results.length,
    'meaningfulShopRunRate': meaningfulShopRuns / report.results.length,
    'uniqueFinalBuilds': finalBuilds.length,
    'winRate95': _wilson(report.wins, report.results.length),
    'completionBossAttempts': bossAttempts,
    'completionBossClearRate': bossAttempts == 0
        ? 0
        : bossClears / bossAttempts,
    'completionBossClearRate95': _wilson(bossClears, bossAttempts),
    'handDiversityEntropy': handEntropy,
    'dominantHand': orderedHands.isEmpty ? null : orderedHands.first.key,
    'dominantHandRate': orderedHands.isEmpty
        ? 0
        : orderedHands.first.value / hands,
    'reachHeat9Rate': _reachRate(report, 9),
    'reachHeat12Rate': _reachRate(report, 12),
    'reachHeat13Rate': _reachRate(report, 13),
    'reachHeat20Rate': _reachRate(report, 20),
    'topFinalJokers': <String, int>{
      for (final entry in topFinalJokers.take(10)) entry.key: entry.value,
    },
    'supplyPurchases': supplies,
    'handTypeCounts': handTypes,
    'invariantFailureSamples': failures.take(20).toList(),
  };
}

double _normalizedEntropy(Iterable<int> counts, int total) {
  if (total <= 0) return 0;
  var entropy = 0.0;
  for (final count in counts) {
    if (count <= 0) continue;
    final probability = count / total;
    entropy -= probability * math.log(probability);
  }
  return entropy / math.log(HandType.values.length);
}

Map<String, double> _wilson(int successes, int total) {
  if (total <= 0) return const <String, double>{'low': 0, 'high': 0};
  const z = 1.959963984540054;
  final proportion = successes / total;
  final denominator = 1 + z * z / total;
  final centre = (proportion + z * z / (2 * total)) / denominator;
  final radius =
      z *
      math.sqrt((proportion * (1 - proportion) + z * z / (4 * total)) / total) /
      denominator;
  return <String, double>{
    'low': math.max(0, centre - radius),
    'high': math.min(1, centre + radius),
  };
}

double _reachRate(SimulationBatchReport report, int heat) =>
    report.results.where((result) => result.heatsCleared >= heat - 1).length /
    report.results.length;

String? _option(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}

class _AuditCohort {
  const _AuditCohort(this.id, this.config);

  final String id;
  final SimulationConfig config;
}

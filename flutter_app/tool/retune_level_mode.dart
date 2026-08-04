import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:wildcard/domain/level_mode/level_catalog.dart';
import 'package:wildcard/domain/level_mode/level_simulation_harness.dart';

/// Rebuilds Level Mode targets after applying a new hand/discard budget.
///
/// The production target is derived from the measured native-policy median
/// under the new budget. It is never capped by the weakest layout. Layout
/// reachability is reported separately so a solvability check cannot silently
/// turn into the pass mark again.
Future<void> main(List<String> arguments) async {
  try {
    final config = _Configuration.parse(arguments);
    if (config.showHelp) {
      stdout.writeln(_usage);
      return;
    }

    final sourceFile = File(config.catalogPath);
    final specFile = File(config.specPath);
    final overrideFile = File(config.overridePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException('Catalog does not exist', sourceFile.path);
    }
    if (!specFile.existsSync()) {
      throw FileSystemException('Redesign spec does not exist', specFile.path);
    }
    if (!overrideFile.existsSync()) {
      throw FileSystemException(
        'Balance overrides do not exist',
        overrideFile.path,
      );
    }

    final sourceRoot = _decodeRoot(await sourceFile.readAsString());
    final specs = _parseSpecs(await specFile.readAsString());
    final overrides = _parseOverrides(await overrideFile.readAsString());
    final rawLevels = _rawLevels(sourceRoot);
    _validateInputs(rawLevels, specs);

    final sourceTargets = <int, int>{};
    final sourceHands = <int, int>{};
    final sourceDiscards = <int, int>{};
    for (final raw in rawLevels) {
      final id = raw['id']! as int;
      final rules = _map(raw['rules'], 'level $id rules');
      final objective = _map(raw['objective'], 'level $id objective');
      sourceTargets[id] = objective['target_score']! as int;
      sourceHands[id] = rules['hands']! as int;
      sourceDiscards[id] = rules['discards']! as int;

      final spec = specs[id]!;
      // The redesign bands are ceilings, not permission to loosen an already
      // tighter authored puzzle (for example L11's four-play Pair chain or
      // L38's two-discard exercise).
      rules['hands'] = math.min(sourceHands[id]!, spec.hands);
      rules['discards'] = math.min(sourceDiscards[id]!, spec.discards);
      final levelOverride = overrides[id];
      if (levelOverride?.discards case final discards?) {
        if (discards > (rules['discards']! as int)) {
          throw FormatException(
            'Level $id discard override cannot loosen the capped budget',
          );
        }
        rules['discards'] = discards;
      }
      raw['targetSuccess'] = spec.desiredRate;
      _syncResourceCopy(raw, id);
      objective['target_score'] = _objectiveOnlyLevelIds.contains(id)
          ? 0
          : _capacityProbeTarget;
    }

    final capacityCatalog = LevelCatalog.fromJsonString(jsonEncode(sourceRoot));
    final harness = const LevelSimulationHarness();
    final capacityReport = harness.runCampaignPolicies(
      levels: capacityCatalog.levels,
    );
    final capacityByLevel = _bestPolicyMetrics(capacityReport);

    final targetRows = <_TargetRow>[];
    for (final raw in rawLevels) {
      final id = raw['id']! as int;
      final spec = specs[id]!;
      final objective = _map(raw['objective'], 'level $id objective');
      final scores = capacityByLevel[id]!.bestScores.toList()..sort();
      final median = _median(scores);
      final ratioTarget = _objectiveOnlyLevelIds.contains(id)
          ? 0
          : _roundedTarget(median * spec.targetRatio);
      final percentileTarget = _objectiveOnlyLevelIds.contains(id)
          ? 0
          : _selectThreshold(scores, spec.desiredRate);
      // The supplied ratios were measured against an older target dataset
      // (87/100 old targets differ from this catalog). The fresh percentile
      // measured on the exact native catalog is authoritative; retaining the
      // stale ratio as a hard override made L99/L100 unreachable in trial 1.
      objective['target_score'] = percentileTarget;
      targetRows.add(
        _TargetRow(
          id: id,
          name: raw['name']! as String,
          chapter: raw['chapter']! as String,
          objectiveOnly: _objectiveOnlyLevelIds.contains(id),
          oldTarget: sourceTargets[id]!,
          oldHands: sourceHands[id]!,
          oldDiscards: sourceDiscards[id]!,
          hands: _map(raw['rules'], 'level $id rules')['hands']! as int,
          discards: _map(raw['rules'], 'level $id rules')['discards']! as int,
          targetRatio: spec.targetRatio,
          desiredRate: spec.desiredRate,
          capacityMedian: median,
          target: percentileTarget,
          ratioReferenceTarget: ratioTarget,
        ),
      );
    }

    final notes = (sourceRoot['notes']! as List<Object?>).cast<String>();
    const redesignNote =
        'v8.6.2 difficulty rebuild applies chapter resource budgets before '
        'deriving score targets from native-policy medians; objective-only '
        'levels never receive a hidden score floor.';
    if (!notes.contains(redesignNote)) notes.add(redesignNote);

    late String tunedJson;
    late LevelCampaignPolicyReport tunedReport;
    late Map<int, _BestPolicyMetrics> tunedBestByLevel;
    final iterationSummaries = <Map<String, Object?>>[];
    final selectedCandidates = <int, _TargetCandidate>{};
    for (var iteration = 1; iteration <= config.iterations; iteration++) {
      tunedJson = '${const JsonEncoder.withIndent('  ').convert(sourceRoot)}\n';
      final tunedCatalog = LevelCatalog.fromJsonString(tunedJson);
      tunedReport = harness.runCampaignPolicies(levels: tunedCatalog.levels);
      tunedBestByLevel = _bestPolicyMetrics(tunedReport);
      final iterationMetrics = _metrics(tunedReport, targetRows);
      iterationSummaries.add(<String, Object?>{
        'iteration': iteration,
        'scoreBearingMeanAbsoluteRateError':
            iterationMetrics['scoreBearingMeanAbsoluteRateError'],
        'maxRateError': iterationMetrics['maxRateError'],
        'layoutsWithoutPolicyClear':
            iterationMetrics['layoutsWithoutPolicyClear'],
      });
      for (final row in targetRows.where((row) => !row.objectiveOnly)) {
        final measured = tunedBestByLevel[row.id]!;
        final candidate = _TargetCandidate(
          iteration: iteration,
          target: row.target,
          absoluteError: (measured.clearRate - row.desiredRate).abs(),
        );
        final selected = selectedCandidates[row.id];
        if (selected == null ||
            candidate.absoluteError < selected.absoluteError ||
            (candidate.absoluteError == selected.absoluteError &&
                (candidate.target - row.oldTarget).abs() <
                    (selected.target - row.oldTarget).abs())) {
          selectedCandidates[row.id] = candidate;
        }
      }
      if (iteration == config.iterations) break;

      for (final row in targetRows.where((row) => !row.objectiveOnly)) {
        final best = tunedBestByLevel[row.id]!;
        final next = _refinedTarget(
          current: row.target,
          scores: best.bestScores,
          actualRate: best.clearRate,
          desiredRate: row.desiredRate,
        );
        row.target = next;
        _map(
          rawLevels[row.id - 1]['objective'],
          'level ${row.id} objective',
        )['target_score'] = next;
      }
    }

    // Every level is deterministic and independent. Keep the best measured
    // candidate for each score-bearing table, then run one final combined
    // confirmation pass so the shipped report describes the exact output.
    for (final row in targetRows.where((row) => !row.objectiveOnly)) {
      final selected = selectedCandidates[row.id]!;
      row
        ..target = selected.target
        ..selectedIteration = selected.iteration;
      _map(
        rawLevels[row.id - 1]['objective'],
        'level ${row.id} objective',
      )['target_score'] = selected.target;
    }
    for (final entry in overrides.entries) {
      final levelOverride = entry.value;
      if (levelOverride.target case final target?) {
        if (_objectiveOnlyLevelIds.contains(entry.key)) {
          throw FormatException(
            'Level ${entry.key} is objective-only and cannot receive a score '
            'override',
          );
        }
        final row = targetRows[entry.key - 1]
          ..target = target
          ..selectedIteration = 0
          ..overrideReason = levelOverride.reason;
        _map(
          rawLevels[entry.key - 1]['objective'],
          'level ${entry.key} objective',
        )['target_score'] = row.target;
      }
    }
    tunedJson = '${const JsonEncoder.withIndent('  ').convert(sourceRoot)}\n';
    final confirmedCatalog = LevelCatalog.fromJsonString(tunedJson);
    tunedReport = harness.runCampaignPolicies(levels: confirmedCatalog.levels);
    tunedBestByLevel = _bestPolicyMetrics(tunedReport);
    final metrics = _metrics(tunedReport, targetRows);
    final report = <String, Object?>{
      'formatVersion': 1,
      'sourceCatalog': sourceFile.path,
      'redesignSpec': specFile.path,
      'balanceOverrides': overrideFile.path,
      'outputCatalog': config.outputPath,
      'algorithm': <String, Object?>{
        'budgetAppliedBeforeMeasurement': true,
        'budgetBandsActAsCaps': true,
        'targetFormula':
            'cap-free percentile seed plus bounded measured-rate refinement',
        'measurementIterations': config.iterations,
        'candidateSelection':
            'lowest absolute rate error per independent level, then one final '
            'combined deterministic confirmation pass',
        'focusedOverrides':
            'tracked overrides come from bounded per-level native-policy '
            'sweeps and are applied before the final combined confirmation',
        'staleRatioUsage':
            'comparison only; 87/100 supplied oldTarget values do not match '
            'the source catalog',
        'weakestLayoutCapacityCap': false,
        'capacityProbeTarget': _capacityProbeTarget,
        'policies': LevelSimulationPolicy.values
            .map((policy) => policy.name)
            .toList(growable: false),
        'policyAggregation':
            'best deterministic policy per layout (one outcome per layout)',
        'objectiveOnlyLevelIds': _objectiveOnlyLevelIds.toList()..sort(),
        'solvabilityStatement':
            'A clear from a native competent policy is constructive route '
            'evidence. Missing policy routes are not proof of impossibility; '
            'the absent exhaustive solver artifact is still required for that.',
      },
      'iterationSummaries': iterationSummaries,
      'metrics': metrics,
      'levels': targetRows
          .map((row) => row.toJson(tunedReport, tunedBestByLevel))
          .toList(growable: false),
    };

    await File(config.outputPath).writeAsString(tunedJson);
    await File(
      config.reportPath,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');

    stdout.writeln('Retuned ${targetRows.length} levels.');
    stdout.writeln('Catalog: ${config.outputPath}');
    stdout.writeln('Report: ${config.reportPath}');
    stdout.writeln(
      'All-level MAE: ${_fixed(metrics['meanAbsoluteRateError'])}; '
      'score-bearing MAE: '
      '${_fixed(metrics['scoreBearingMeanAbsoluteRateError'])}; '
      'max: ${_fixed(metrics['maxRateError'])}.',
    );
    stdout.writeln(
      'Layouts without a competent-policy clear: '
      '${metrics['layoutsWithoutPolicyClear']}.',
    );
  } on Object catch (error, stackTrace) {
    stderr.writeln('Level retune failed: $error');
    if (error is! FormatException && error is! FileSystemException) {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

const int _capacityProbeTarget = 1000000000;

/// These levels present only the authored hand/sequence/variety objective.
/// Adding a score target would be a hidden second win condition. In particular,
/// Level 11 must finish on the third Pair, as its player-facing brief promises.
const Set<int> _objectiveOnlyLevelIds = <int>{
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  32,
  42,
  43,
  44,
  45,
  56,
  57,
  74,
  87,
  93,
};

Map<String, Object?> _decodeRoot(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Catalog root is not an object');
  }
  return Map<String, Object?>.from(decoded);
}

List<Map<String, Object?>> _rawLevels(Map<String, Object?> root) {
  final value = root['levels'];
  if (value is! List) throw const FormatException(r'$.levels is not a list');
  return value
      .map((entry) => (entry! as Map).cast<String, Object?>())
      .toList(growable: false);
}

void _syncResourceCopy(Map<String, Object?> raw, int id) {
  switch (id) {
    case 50:
      raw['description'] =
          '50% blocked. Reach the chapter target in four plays.';
    case 80:
      raw['description'] =
          'Choose three of six Jokers; score the target in four plays and '
          'two discards.';
    case 91:
      raw['hint'] =
          'The strongest raw trio is not always the most consistent over '
          'four plays.';
  }
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) throw FormatException('$label is not an object');
  return value.cast<String, Object?>();
}

Map<int, _LevelSpec> _parseSpecs(String source) {
  final lines = const LineSplitter().convert(source.trim());
  if (lines.length != 101) {
    throw FormatException(
      'Expected header plus 100 spec rows, got ${lines.length}',
    );
  }
  final header = lines.first.split(',');
  int column(String name) {
    final index = header.indexOf(name);
    if (index < 0) throw FormatException('Missing CSV column $name');
    return index;
  }

  final levelColumn = column('level');
  final nameColumn = column('name');
  final ratioColumn = column('targetRatio');
  final rateColumn = column('desiredRate');
  final handsColumn = column('newHands');
  final discardsColumn = column('newDiscards');
  final result = <int, _LevelSpec>{};
  for (final line in lines.skip(1)) {
    final fields = line.split(',');
    if (fields.length != header.length) {
      throw FormatException('Malformed CSV row: $line');
    }
    final level = int.parse(fields[levelColumn]);
    result[level] = _LevelSpec(
      level: level,
      name: fields[nameColumn],
      targetRatio: double.parse(fields[ratioColumn]),
      desiredRate: double.parse(fields[rateColumn]),
      hands: int.parse(fields[handsColumn]),
      discards: int.parse(fields[discardsColumn]),
    );
  }
  return result;
}

Map<int, _LevelOverride> _parseOverrides(String source) {
  final lines = const LineSplitter().convert(source.trim());
  if (lines.isEmpty || lines.first != 'level,target,discards,reason') {
    throw const FormatException(
      'Override CSV header must be level,target,discards,reason',
    );
  }
  final result = <int, _LevelOverride>{};
  for (final line in lines.skip(1)) {
    final fields = line.split(',');
    if (fields.length != 4) {
      throw FormatException('Malformed override row: $line');
    }
    final level = int.parse(fields[0]);
    final target = fields[1].isEmpty ? null : int.parse(fields[1]);
    final discards = fields[2].isEmpty ? null : int.parse(fields[2]);
    if (level < 1 || level > 100 || result.containsKey(level)) {
      throw FormatException('Invalid or duplicate override level $level');
    }
    if (target != null && (target <= 0 || target % 5 != 0)) {
      throw FormatException(
        'Level $level target override must be positive and divisible by 5',
      );
    }
    if (discards != null && discards < 0) {
      throw FormatException('Level $level discard override cannot be negative');
    }
    if (target == null && discards == null) {
      throw FormatException('Level $level override changes nothing');
    }
    result[level] = _LevelOverride(
      target: target,
      discards: discards,
      reason: fields[3],
    );
  }
  return result;
}

void _validateInputs(
  List<Map<String, Object?>> levels,
  Map<int, _LevelSpec> specs,
) {
  if (levels.length != 100 || specs.length != 100) {
    throw FormatException(
      'Expected 100 catalog/spec levels, got ${levels.length}/${specs.length}',
    );
  }
  for (var index = 0; index < levels.length; index++) {
    final raw = levels[index];
    final id = raw['id'];
    if (id != index + 1) {
      throw FormatException('Catalog index $index has level id $id');
    }
    final spec = specs[id]!;
    if (raw['name'] != spec.name && id != 86) {
      throw FormatException(
        'Level $id name mismatch: ${raw['name']} vs ${spec.name}',
      );
    }
    if (spec.hands <= 0 || spec.discards < 0) {
      throw FormatException('Level $id has an invalid resource budget');
    }
    if (spec.desiredRate <= 0 || spec.desiredRate >= 1) {
      throw FormatException('Level $id desired rate must be between 0 and 1');
    }
    if (!_objectiveOnlyLevelIds.contains(id) && spec.targetRatio <= 0) {
      throw FormatException('Level $id needs a positive target ratio');
    }
  }
}

int _median(List<int> sorted) {
  if (sorted.isEmpty) throw StateError('Cannot take an empty median');
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : ((sorted[middle - 1] + sorted[middle]) / 2).round();
}

int _roundedTarget(double value) => math.max(5, (value / 5).round() * 5);

int _selectThreshold(List<int> sorted, double desiredRate) {
  if (sorted.isEmpty) throw StateError('Cannot select an empty threshold');
  final index = ((1 - desiredRate) * sorted.length).floor().clamp(
    0,
    sorted.length - 1,
  );
  return _roundedTarget(sorted[index].toDouble());
}

int _refinedTarget({
  required int current,
  required List<int> scores,
  required double actualRate,
  required double desiredRate,
}) {
  final resolution = 1 / scores.length;
  final tolerance = math.max(0.025, resolution * 0.55);
  if ((actualRate - desiredRate).abs() <= tolerance) return current;

  final sorted = scores.toList()..sort();
  final measuredPercentile = _selectThreshold(sorted, desiredRate);
  if (actualRate > desiredRate) {
    final scale = math
        .sqrt(actualRate / desiredRate)
        .clamp(1.03, 1.25)
        .toDouble();
    final scaled = _roundedTarget(current * scale);
    return math.max(current + 5, math.max(measuredPercentile, scaled));
  }

  final scale = actualRate <= 0
      ? 0.75
      : math.sqrt(actualRate / desiredRate).clamp(0.75, 0.97).toDouble();
  final scaled = _roundedTarget(current * scale);
  return math.max(
    5,
    math.min(current - 5, math.min(measuredPercentile, scaled)),
  );
}

Map<String, Object?> _metrics(
  LevelCampaignPolicyReport report,
  List<_TargetRow> rows,
) {
  final bestById = _bestPolicyMetrics(report);
  final errors = <double>[];
  final scoreErrors = <double>[];
  final perfect = <int>[];
  for (final row in rows) {
    final actual = bestById[row.id]!.clearRate;
    final error = (actual - row.desiredRate).abs();
    errors.add(error);
    if (!row.objectiveOnly) scoreErrors.add(error);
    if (actual == 1) perfect.add(row.id);
  }

  final layoutAttempts = <String, List<LevelPolicyAttempt>>{};
  for (final attempt in report.policyAttempts) {
    final result = attempt.result;
    final key = '${result.levelId}:${result.layoutId}';
    layoutAttempts.putIfAbsent(key, () => <LevelPolicyAttempt>[]).add(attempt);
  }
  final withoutRoute =
      layoutAttempts.entries
          .where(
            (entry) => !entry.value.any((attempt) => attempt.result.cleared),
          )
          .map((entry) => entry.key)
          .toList()
        ..sort();

  final ratiosByChapter = <String, List<double>>{};
  for (final row in rows.where((row) => !row.objectiveOnly)) {
    ratiosByChapter
        .putIfAbsent(row.chapter, () => <double>[])
        .add(row.target / row.capacityMedian);
  }
  final chapterRatios = <String, double>{};
  for (final entry in ratiosByChapter.entries) {
    final values = entry.value..sort();
    chapterRatios[entry.key] = values.length.isOdd
        ? values[values.length ~/ 2]
        : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
  }

  double average(List<double> values) =>
      values.reduce((left, right) => left + right) / values.length;
  final maxError = errors.reduce(math.max);
  final scoreMaxError = scoreErrors.reduce(math.max);
  return <String, Object?>{
    'attempts': report.attempts,
    'policyAttempts': report.attempts,
    'bestPolicyLayouts': bestById.values
        .map((metrics) => metrics.layoutCount)
        .reduce((left, right) => left + right),
    'clearRate':
        bestById.values
            .map((metrics) => metrics.clears)
            .reduce((left, right) => left + right) /
        bestById.values
            .map((metrics) => metrics.layoutCount)
            .reduce((left, right) => left + right),
    'meanAbsoluteRateError': average(errors),
    'scoreBearingMeanAbsoluteRateError': average(scoreErrors),
    'scoreBearingMaxRateError': scoreMaxError,
    'maxRateError': maxError,
    'perfectClearLevelIds': perfect,
    'layoutsWithoutPolicyClear': withoutRoute.length,
    'layoutKeysWithoutPolicyClear': withoutRoute,
    'chapterMedianTargetRatios': chapterRatios,
    'rateGatePassed': average(errors) < 0.10 && maxError < 0.20,
    'scoreBearingRateGatePassed':
        average(scoreErrors) < 0.10 && scoreMaxError < 0.20,
    'exhaustiveSolverArtifactAvailable': false,
  };
}

Map<int, _BestPolicyMetrics> _bestPolicyMetrics(
  LevelCampaignPolicyReport report,
) {
  final byLayout = <String, List<LevelPolicyAttempt>>{};
  for (final attempt in report.policyAttempts) {
    final result = attempt.result;
    final key = '${result.levelId}:${result.layoutId}';
    byLayout.putIfAbsent(key, () => <LevelPolicyAttempt>[]).add(attempt);
  }
  final scoresByLevel = <int, List<int>>{};
  final clearsByLevel = <int, int>{};
  for (final attempts in byLayout.values) {
    final levelId = attempts.first.result.levelId;
    final bestScore = attempts
        .map((attempt) => attempt.result.totalScore)
        .reduce(math.max);
    scoresByLevel.putIfAbsent(levelId, () => <int>[]).add(bestScore);
    if (attempts.any((attempt) => attempt.result.cleared)) {
      clearsByLevel.update(levelId, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  return <int, _BestPolicyMetrics>{
    for (final entry in scoresByLevel.entries)
      entry.key: _BestPolicyMetrics(
        bestScores: entry.value,
        clears: clearsByLevel[entry.key] ?? 0,
      ),
  };
}

String _fixed(Object? value) =>
    value is num ? value.toStringAsFixed(4) : '$value';

class _LevelSpec {
  const _LevelSpec({
    required this.level,
    required this.name,
    required this.targetRatio,
    required this.desiredRate,
    required this.hands,
    required this.discards,
  });

  final int level;
  final String name;
  final double targetRatio;
  final double desiredRate;
  final int hands;
  final int discards;
}

class _LevelOverride {
  const _LevelOverride({
    required this.target,
    required this.discards,
    required this.reason,
  });

  final int? target;
  final int? discards;
  final String reason;
}

class _TargetRow {
  _TargetRow({
    required this.id,
    required this.name,
    required this.chapter,
    required this.objectiveOnly,
    required this.oldTarget,
    required this.oldHands,
    required this.oldDiscards,
    required this.hands,
    required this.discards,
    required this.targetRatio,
    required this.desiredRate,
    required this.capacityMedian,
    required this.target,
    required this.ratioReferenceTarget,
  });

  final int id;
  final String name;
  final String chapter;
  final bool objectiveOnly;
  final int oldTarget;
  final int oldHands;
  final int oldDiscards;
  final int hands;
  final int discards;
  final double targetRatio;
  final double desiredRate;
  final int capacityMedian;
  int target;
  final int ratioReferenceTarget;
  int selectedIteration = 0;
  String? overrideReason;

  Map<String, Object?> toJson(
    LevelCampaignPolicyReport report,
    Map<int, _BestPolicyMetrics> bestByLevel,
  ) {
    final level = report.levels.singleWhere((entry) => entry.levelId == id);
    final best = bestByLevel[id]!;
    return <String, Object?>{
      'level': id,
      'name': name,
      'chapter': chapter,
      'objectiveOnly': objectiveOnly,
      'oldTarget': oldTarget,
      'newTarget': target,
      'staleRatioReferenceTarget': ratioReferenceTarget,
      'selectedIteration': selectedIteration,
      if (overrideReason != null) 'overrideReason': overrideReason,
      'targetRatio': targetRatio,
      'capacityMedian': capacityMedian,
      'oldHands': oldHands,
      'oldDiscards': oldDiscards,
      'hands': hands,
      'discards': discards,
      'desiredRate': desiredRate,
      'measuredRate': best.clearRate,
      'absoluteRateError': (best.clearRate - desiredRate).abs(),
      'bestPolicyLayoutClears': best.clears,
      'bestPolicyLayoutCount': best.layoutCount,
      'policyAttempts': level.attempts,
      'policyClears': level.clears,
      'policyMedianScore': level.medianScore,
      'policyFailedLayouts': level.uniqueLayoutFailures.toList()..sort(),
    };
  }
}

class _TargetCandidate {
  const _TargetCandidate({
    required this.iteration,
    required this.target,
    required this.absoluteError,
  });

  final int iteration;
  final int target;
  final double absoluteError;
}

class _BestPolicyMetrics {
  _BestPolicyMetrics({required List<int> bestScores, required this.clears})
    : bestScores = List<int>.unmodifiable(bestScores);

  final List<int> bestScores;
  final int clears;
  int get layoutCount => bestScores.length;
  double get clearRate => layoutCount == 0 ? 0 : clears / layoutCount;
}

class _Configuration {
  const _Configuration({
    required this.catalogPath,
    required this.specPath,
    required this.overridePath,
    required this.outputPath,
    required this.reportPath,
    required this.iterations,
    required this.showHelp,
  });

  final String catalogPath;
  final String specPath;
  final String overridePath;
  final String outputPath;
  final String reportPath;
  final int iterations;
  final bool showHelp;

  factory _Configuration.parse(List<String> arguments) {
    var catalog = 'assets/data/levels-v8.5.2.generated.json';
    var spec = 'tool/level_mode_redesign_targets.csv';
    var overrides = 'tool/level_mode_balance_overrides.csv';
    var output = 'build/levels-v8.6.2.retuned.json';
    var report = 'build/level-mode-retune-v8.6.2.json';
    var iterations = 2;
    var showHelp = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String value(String option) {
        final prefix = '$option=';
        if (argument.startsWith(prefix)) {
          return argument.substring(prefix.length);
        }
        if (argument != option || index + 1 >= arguments.length) {
          throw FormatException('Expected $option VALUE');
        }
        return arguments[++index];
      }

      if (argument == '--help' || argument == '-h') {
        showHelp = true;
      } else if (argument == '--catalog' || argument.startsWith('--catalog=')) {
        catalog = value('--catalog');
      } else if (argument == '--spec' || argument.startsWith('--spec=')) {
        spec = value('--spec');
      } else if (argument == '--overrides' ||
          argument.startsWith('--overrides=')) {
        overrides = value('--overrides');
      } else if (argument == '--output' || argument.startsWith('--output=')) {
        output = value('--output');
      } else if (argument == '--report' || argument.startsWith('--report=')) {
        report = value('--report');
      } else if (argument == '--iterations' ||
          argument.startsWith('--iterations=')) {
        iterations = int.parse(value('--iterations'));
        if (iterations <= 0) {
          throw const FormatException('--iterations must be positive');
        }
      } else {
        throw FormatException('Unknown argument: $argument\n\n$_usage');
      }
    }
    return _Configuration(
      catalogPath: catalog,
      specPath: spec,
      overridePath: overrides,
      outputPath: output,
      reportPath: report,
      iterations: iterations,
      showHelp: showHelp,
    );
  }
}

const String _usage = '''
Native WILDCARD Level Mode retuner

Usage:
  dart run tool/retune_level_mode.dart [options]

Options:
  --catalog PATH  Source production catalog.
  --spec PATH     100-row redesign CSV.
  --overrides PATH  Focused target/discard override CSV.
  --output PATH   Retuned catalog output (never overwrites by default).
  --report PATH   Structured tuning/validation report.
  --iterations N  Measured target candidates after the capacity probe (default 2).
  --help          Show this help.
''';

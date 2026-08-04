import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/level_mode/level_catalog.dart';
import 'package:wildcard/domain/level_mode/level_definition.dart';
import 'package:wildcard/domain/level_mode/level_simulation_harness.dart';

Future<void> main(List<String> arguments) async {
  try {
    final config = _Configuration.parse(arguments);
    if (config.showHelp) {
      stdout.writeln(_usage);
      return;
    }
    final source = File(config.catalogPath);
    if (!source.existsSync()) {
      throw FileSystemException('Catalog does not exist', source.path);
    }
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Catalog is not an object');
    }
    final root = decoded.cast<String, Object?>();
    final rawLevels = (root['levels']! as List<Object?>)
        .map((entry) => (entry! as Map).cast<String, Object?>())
        .toList(growable: false);
    final harness = const LevelSimulationHarness();
    final results = <Map<String, Object?>>[];

    for (final id in config.levelIds) {
      if (id < 1 || id > rawLevels.length) {
        throw FormatException('Unknown level $id');
      }
      final raw = rawLevels[id - 1];
      final rules = (raw['rules']! as Map).cast<String, Object?>();
      final objective = (raw['objective']! as Map).cast<String, Object?>();
      if (objective['target_score'] != 0) {
        throw FormatException('Level $id is not objective-only');
      }
      final currentDiscards = rules['discards']! as int;
      for (var discards = currentDiscards; discards >= 0; discards--) {
        rules['discards'] = discards;
        final catalog = LevelCatalog.fromJsonString(jsonEncode(root));
        final level = catalog.level(id);
        final report = harness.runCampaignPolicies(
          levels: <LevelDefinition>[level],
        );
        final byLayout = <String, List<LevelPolicyAttempt>>{};
        for (final attempt in report.policyAttempts) {
          byLayout
              .putIfAbsent(
                attempt.result.layoutId,
                () => <LevelPolicyAttempt>[],
              )
              .add(attempt);
        }
        final clears = byLayout.values
            .where(
              (attempts) => attempts.any((attempt) => attempt.result.cleared),
            )
            .length;
        final rate = clears / byLayout.length;
        results.add(<String, Object?>{
          'level': id,
          'name': level.name,
          'hands': level.rules.hands,
          'discards': discards,
          'desiredRate': level.targetSuccess,
          'measuredRate': rate,
          'absoluteRateError': (rate - level.targetSuccess).abs(),
          'layoutClears': clears,
          'layoutCount': byLayout.length,
        });
      }
      rules['discards'] = currentDiscards;
    }

    final output = <String, Object?>{
      'formatVersion': 1,
      'catalog': source.path,
      'policyAggregation': 'best deterministic policy per layout',
      'results': results,
      'bestByLevel': <String, Object?>{
        for (final id in config.levelIds)
          '$id':
              (results.where((row) => row['level'] == id).toList()
                    ..sort((left, right) {
                      final error = (left['absoluteRateError']! as double)
                          .compareTo(right['absoluteRateError']! as double);
                      if (error != 0) return error;
                      // Prefer the less restrictive option when both rates tie.
                      return (right['discards']! as int).compareTo(
                        left['discards']! as int,
                      );
                    }))
                  .first,
      },
    };
    final encoded = '${const JsonEncoder.withIndent('  ').convert(output)}\n';
    if (config.outputPath case final path?) {
      await File(path).writeAsString(encoded);
    }
    stdout.write(encoded);
  } on Object catch (error, stackTrace) {
    stderr.writeln('Objective budget sweep failed: $error');
    if (error is! FormatException && error is! FileSystemException) {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

class _Configuration {
  const _Configuration({
    required this.catalogPath,
    required this.levelIds,
    required this.outputPath,
    required this.showHelp,
  });

  final String catalogPath;
  final List<int> levelIds;
  final String? outputPath;
  final bool showHelp;

  factory _Configuration.parse(List<String> arguments) {
    var catalog = 'build/levels-v8.6.2.retuned.json';
    var levelIds = <int>[];
    String? output;
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
      } else if (argument == '--levels' || argument.startsWith('--levels=')) {
        levelIds = value('--levels').split(',').map(int.parse).toList();
      } else if (argument == '--output' || argument.startsWith('--output=')) {
        output = value('--output');
      } else {
        throw FormatException('Unknown argument: $argument\n\n$_usage');
      }
    }
    if (!showHelp && levelIds.isEmpty) {
      throw const FormatException('--levels must not be empty');
    }
    return _Configuration(
      catalogPath: catalog,
      levelIds: levelIds,
      outputPath: output,
      showHelp: showHelp,
    );
  }
}

const String _usage = '''
Focused WILDCARD objective-only discard sweep

Usage:
  dart run tool/sweep_objective_budgets.dart \\
    --catalog build/levels-v8.6.2.retuned.json \\
    --levels 11,12,32,42,93 \\
    --output build/objective-budget-sweep.json
''';

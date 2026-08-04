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

    for (final sweep in config.sweeps.entries) {
      final id = sweep.key;
      if (id < 1 || id > rawLevels.length) {
        throw FormatException('Unknown level $id');
      }
      final raw = rawLevels[id - 1];
      final objective = (raw['objective']! as Map).cast<String, Object?>();
      for (final target in sweep.value) {
        objective['target_score'] = target;
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
          'target': target,
          'desiredRate': level.targetSuccess,
          'measuredRate': rate,
          'absoluteRateError': (rate - level.targetSuccess).abs(),
          'layoutClears': clears,
          'layoutCount': byLayout.length,
        });
      }
    }

    final output = <String, Object?>{
      'formatVersion': 1,
      'catalog': source.path,
      'policyAggregation': 'best deterministic policy per layout',
      'results': results,
      'bestByLevel': <String, Object?>{
        for (final id in config.sweeps.keys)
          '$id':
              (results.where((row) => row['level'] == id).toList()
                    ..sort((left, right) {
                      final error = (left['absoluteRateError']! as double)
                          .compareTo(right['absoluteRateError']! as double);
                      if (error != 0) return error;
                      return (left['target']! as int).compareTo(
                        right['target']! as int,
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
    stderr.writeln('Level target sweep failed: $error');
    if (error is! FormatException && error is! FileSystemException) {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

class _Configuration {
  const _Configuration({
    required this.catalogPath,
    required this.sweeps,
    required this.outputPath,
    required this.showHelp,
  });

  final String catalogPath;
  final Map<int, List<int>> sweeps;
  final String? outputPath;
  final bool showHelp;

  factory _Configuration.parse(List<String> arguments) {
    var catalog = 'build/levels-v8.6.2.retuned.json';
    var sweeps = <int, List<int>>{};
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
      } else if (argument == '--sweeps' || argument.startsWith('--sweeps=')) {
        sweeps = _parseSweeps(value('--sweeps'));
      } else if (argument == '--output' || argument.startsWith('--output=')) {
        output = value('--output');
      } else {
        throw FormatException('Unknown argument: $argument\n\n$_usage');
      }
    }
    if (!showHelp && sweeps.isEmpty) {
      throw const FormatException('--sweeps must not be empty');
    }
    return _Configuration(
      catalogPath: catalog,
      sweeps: sweeps,
      outputPath: output,
      showHelp: showHelp,
    );
  }
}

Map<int, List<int>> _parseSweeps(String source) {
  final result = <int, List<int>>{};
  for (final entry in source.split(';')) {
    final parts = entry.split('=');
    if (parts.length != 2) throw FormatException('Invalid sweep $entry');
    final id = int.parse(parts.first);
    final targets = parts.last
        .split(',')
        .map(int.parse)
        .toList(growable: false);
    if (targets.isEmpty || targets.any((target) => target <= 0)) {
      throw FormatException('Invalid targets for level $id');
    }
    result[id] = targets;
  }
  return result;
}

const String _usage = '''
Focused WILDCARD Level target sweep

Usage:
  dart run tool/sweep_level_targets.dart \\
    --catalog build/levels-v8.6.2.retuned.json \\
    --sweeps "40=460,480,500;58=525,550,575" \\
    --output build/level-target-sweep.json
''';

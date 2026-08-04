import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/level_mode/level_catalog.dart';
import 'package:wildcard/domain/level_mode/level_simulation_harness.dart';

Future<void> main(List<String> arguments) async {
  try {
    final configuration = _ValidationConfiguration.parse(arguments);
    if (configuration.showHelp) {
      stdout.writeln(_usage);
      return;
    }

    final catalogFile = File(configuration.catalogPath);
    if (!catalogFile.existsSync()) {
      throw FileSystemException(
        'Level catalog does not exist',
        catalogFile.path,
      );
    }
    final catalog = LevelCatalog.fromJsonString(
      await catalogFile.readAsString(),
    );
    final harness = const LevelSimulationHarness();
    final policyReport = harness.runCampaignPolicies(
      levels: catalog.levels,
      policies: configuration.policies,
      maxLevels: configuration.maxLevels,
      maxLayoutsPerLevel: configuration.maxLayoutsPerLevel,
    );

    String? solverJson;
    if (configuration.solverPath case final solverPath?) {
      final solverFile = File(solverPath);
      if (!solverFile.existsSync()) {
        throw FileSystemException(
          'Solver route artifact does not exist',
          solverFile.path,
        );
      }
      solverJson = await solverFile.readAsString();
    }
    final solverReport = harness.replaySolverRoutes(
      levels: catalog.levels,
      solverRouteJson: solverJson,
    );
    final output = <String, Object?>{
      'formatVersion': 1,
      'catalog': <String, Object?>{
        'path': catalogFile.path,
        'schemaVersion': catalog.schemaVersion,
        'sourceGameVersion': catalog.sourceGameVersion,
        'sourceCommit': catalog.sourceCommit,
        'sourceBranch': catalog.sourceBranch,
        'shippingLevels': catalog.levels.length,
        'shippingLayouts': catalog.layoutCount,
      },
      'configuration': <String, Object?>{
        'policies': configuration.policies
            .map((policy) => policy.name)
            .toList(growable: false),
        'maxLevels': configuration.maxLevels,
        'maxLayoutsPerLevel': configuration.maxLayoutsPerLevel,
        'solverPath': configuration.solverPath,
      },
      'competentPolicyReport': policyReport.toJson(),
      'solverReplay': _solverJson(solverReport),
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(output);
    if (configuration.outputPath case final outputPath?) {
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString('$encoded\n');
    }
    stdout.writeln(encoded);
  } on Object catch (error, stackTrace) {
    stderr.writeln('Level Mode validation failed: $error');
    if (error is! FormatException && error is! FileSystemException) {
      stderr.writeln(stackTrace);
    }
    exitCode = 1;
  }
}

Map<String, Object?> _solverJson(LevelSolverReplayReport report) {
  final failedResults = report.results
      .where((result) => !result.valid || !result.cleared)
      .map(
        (result) => <String, Object?>{
          'levelId': result.levelId,
          'layoutId': result.layoutId,
          'outcome': result.outcome.name,
          'validationErrors': result.validationErrors,
        },
      )
      .toList(growable: false);
  return <String, Object?>{
    'artifactAvailable': report.artifactAvailable,
    'unavailableReason': report.unavailableReason,
    'routesSupplied': report.routesSupplied,
    'routesPassed': report.routesPassed,
    'allRoutesPassed': report.allRoutesPassed,
    'successfulLayoutCount': report.successfulLayoutKeys.length,
    'missingLayoutCount': report.missingLayoutKeys.length,
    'missingLayoutKeys': report.missingLayoutKeys.toList()..sort(),
    'failedRoutes': failedResults,
  };
}

class _ValidationConfiguration {
  const _ValidationConfiguration({
    required this.catalogPath,
    required this.solverPath,
    required this.outputPath,
    required this.policies,
    required this.maxLevels,
    required this.maxLayoutsPerLevel,
    required this.showHelp,
  });

  final String catalogPath;
  final String? solverPath;
  final String? outputPath;
  final List<LevelSimulationPolicy> policies;
  final int? maxLevels;
  final int? maxLayoutsPerLevel;
  final bool showHelp;

  factory _ValidationConfiguration.parse(List<String> arguments) {
    var catalogPath = _defaultCatalogPath();
    String? solverPath;
    String? outputPath;
    var policies = LevelSimulationPolicy.values;
    int? maxLevels;
    int? maxLayoutsPerLevel;
    var showHelp = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
        continue;
      }
      String valueFor(String option) {
        final prefix = '$option=';
        if (argument.startsWith(prefix)) {
          return argument.substring(prefix.length);
        }
        if (argument != option || index + 1 >= arguments.length) {
          throw FormatException('Expected $option VALUE');
        }
        return arguments[++index];
      }

      if (argument == '--catalog' || argument.startsWith('--catalog=')) {
        catalogPath = valueFor('--catalog');
      } else if (argument == '--solver' || argument.startsWith('--solver=')) {
        solverPath = valueFor('--solver');
      } else if (argument == '--output' || argument.startsWith('--output=')) {
        outputPath = valueFor('--output');
      } else if (argument == '--policies' ||
          argument.startsWith('--policies=')) {
        policies = _parsePolicies(valueFor('--policies'));
      } else if (argument == '--max-levels' ||
          argument.startsWith('--max-levels=')) {
        maxLevels = _positiveInt(valueFor('--max-levels'), '--max-levels');
      } else if (argument == '--max-layouts-per-level' ||
          argument.startsWith('--max-layouts-per-level=')) {
        maxLayoutsPerLevel = _positiveInt(
          valueFor('--max-layouts-per-level'),
          '--max-layouts-per-level',
        );
      } else {
        throw FormatException('Unknown argument: $argument\n\n$_usage');
      }
    }
    return _ValidationConfiguration(
      catalogPath: catalogPath,
      solverPath: solverPath,
      outputPath: outputPath,
      policies: List<LevelSimulationPolicy>.unmodifiable(policies),
      maxLevels: maxLevels,
      maxLayoutsPerLevel: maxLayoutsPerLevel,
      showHelp: showHelp,
    );
  }
}

List<LevelSimulationPolicy> _parsePolicies(String source) {
  final names = source
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) {
    throw const FormatException('--policies must not be empty');
  }
  final policies = <LevelSimulationPolicy>[];
  for (final name in names) {
    final policy = LevelSimulationPolicy.values.where(
      (candidate) => candidate.name == name,
    );
    if (policy.isEmpty) {
      throw FormatException(
        'Unknown policy "$name"; expected '
        '${LevelSimulationPolicy.values.map((value) => value.name).join(', ')}',
      );
    }
    policies.add(policy.single);
  }
  if (policies.toSet().length != policies.length) {
    throw const FormatException('--policies must not contain duplicates');
  }
  return policies;
}

int _positiveInt(String source, String option) {
  final value = int.tryParse(source);
  if (value == null || value <= 0) {
    throw FormatException('$option must be a positive integer');
  }
  return value;
}

String _defaultCatalogPath() {
  const candidates = <String>[
    'assets/data/levels-v8.5.2.generated.json',
    'flutter_app/assets/data/levels-v8.5.2.generated.json',
  ];
  return candidates.firstWhere(
    (path) => File(path).existsSync(),
    orElse: () => candidates.first,
  );
}

const String _usage = '''
Native WILDCARD Level Mode validation

Usage:
  dart run tool/level_mode_validation.dart [options]

Options:
  --catalog PATH                 Production level catalog JSON.
  --solver PATH                  Optional development solver-route JSON.
  --output PATH                  Also write the structured JSON report here.
  --policies LIST                Comma-separated handRanking,adaptivePlanning.
  --max-levels N                 Bound policy validation to the first N levels.
  --max-layouts-per-level N      Bound layouts per selected level.
  --help                         Show this help.

Without --solver, solverReplay is explicitly marked unavailable. Competent
policy results are never presented as solver-route evidence.
''';

import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/joker_catalog.dart';

const _expectedCounts = <String, int>{
  'common': 36,
  'uncommon': 36,
  'rare': 23,
  'wild': 7,
};
const _forcedRarityById = <String, String>{
  'copper': 'common',
  'presser': 'common',
  'polish': 'rare',
  'roller': 'rare',
};
const _minimumRarityById = <String, String>{
  'warm_up': 'uncommon',
  'marathoner': 'uncommon',
};

bool _isConstrainedId(String id) =>
    _forcedRarityById.containsKey(id) || _minimumRarityById.containsKey(id);

void main(List<String> arguments) {
  try {
    final options = _Options.parse(arguments);
    if (options.selfTest) {
      _runSelfTest();
      stdout.writeln('SELF_TEST=PASS');
      return;
    }

    final input = File(options.input!);
    if (!input.existsSync()) {
      throw ArgumentError('Input CSV does not exist: ${input.path}');
    }
    final assignments = _assignRarities(_readRankings(input));
    final csvOutput = File(
      options.csvOutput ?? _replaceExtension(input.path, '.rarities.csv'),
    );
    final jsonOutput = File(
      options.jsonOutput ?? _replaceExtension(input.path, '.rarities.json'),
    );
    _writeOutputs(
      inputPath: input.path,
      assignments: assignments,
      csvOutput: csvOutput,
      jsonOutput: jsonOutput,
    );

    final counts = _countAssignments(assignments);
    stdout.writeln(
      'RARITY_COUNTS='
      'common:${counts['common']},'
      'uncommon:${counts['uncommon']},'
      'rare:${counts['rare']},'
      'wild:${counts['wild']}',
    );
    stdout.writeln(
      'DESIGN_ANCHORS=copper:common,presser:common,polish:rare,roller:rare',
    );
    stdout.writeln(
      'MINIMUM_RARITIES=warm_up:uncommon,marathoner:uncommon; measured '
      'Rare/Wild tiers remain unchanged',
    );
    stdout.writeln('RARITY_CSV=${csvOutput.path}');
    stdout.writeln('RARITY_JSON=${jsonOutput.path}');
    stdout.writeln(
      'RARITY_MAP_JSON=${jsonEncode(<String, String>{for (final assignment in assignments) assignment.row.id: assignment.assignedRarity})}',
    );
  } on Object catch (error) {
    stderr.writeln('Rarity assignment failed: $error');
    exitCode = 2;
  }
}

List<_RankingRow> _readRankings(File input) {
  final records = _parseCsv(input.readAsStringSync());
  if (records.isEmpty) {
    throw const FormatException('Input CSV is empty.');
  }
  final headers = <String, int>{
    for (var index = 0; index < records.first.length; index++)
      records.first[index].trim().toLowerCase(): index,
  };
  for (final required in const [
    'joker',
    'windelta',
    'progressdelta',
    'avgscore',
  ]) {
    if (!headers.containsKey(required)) {
      throw FormatException('Input CSV is missing "$required".');
    }
  }

  String value(List<String> record, String header) {
    final index = headers[header]!;
    if (index >= record.length) return '';
    return record[index].trim();
  }

  double metric(List<String> record, String header, String id) {
    final raw = value(record, header);
    final parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Joker "$id" has invalid $header value "$raw".');
    }
    return parsed;
  }

  final rows = <_RankingRow>[];
  for (var index = 1; index < records.length; index++) {
    final record = records[index];
    if (record.every((field) => field.trim().isEmpty)) continue;
    final id = value(record, 'joker');
    if (id.isEmpty) {
      throw FormatException('CSV row ${index + 1} has no Joker id.');
    }
    if (id == 'BASELINE') continue;
    rows.add(
      _RankingRow(
        id: id,
        winDelta: metric(record, 'windelta', id),
        progressDelta: metric(record, 'progressdelta', id),
        avgScore: metric(record, 'avgscore', id),
      ),
    );
  }
  return rows;
}

List<_Assignment> _assignRarities(List<_RankingRow> sourceRows) {
  final catalogIds = jokerCatalog.map((joker) => joker.id).toSet();
  if (catalogIds.length != 102 || jokerCatalog.length != 102) {
    throw StateError(
      'Expected 102 unique public Jokers in the catalogue, found '
      '${jokerCatalog.length} rows / ${catalogIds.length} unique.',
    );
  }

  final seen = <String>{};
  final duplicates = <String>{};
  for (final row in sourceRows) {
    if (!seen.add(row.id)) duplicates.add(row.id);
  }
  final inputIds = sourceRows.map((row) => row.id).toSet();
  final missing = catalogIds.difference(inputIds).toList()..sort();
  final unknown = inputIds.difference(catalogIds).toList()..sort();
  if (sourceRows.length != 102 ||
      duplicates.isNotEmpty ||
      missing.isNotEmpty ||
      unknown.isNotEmpty) {
    final sortedDuplicates = duplicates.toList()..sort();
    throw StateError(
      'Expected exactly 102 unique public Joker rows; found '
      '${sourceRows.length} rows / ${inputIds.length} unique. '
      'Missing=${missing.join(',')}; unknown=${unknown.join(',')}; '
      'duplicates=${sortedDuplicates.join(',')}.',
    );
  }
  final constrainedIds = <String>{
    ..._forcedRarityById.keys,
    ..._minimumRarityById.keys,
  };
  if (!constrainedIds.every(catalogIds.contains)) {
    throw StateError(
      'Required constrained-rarity ids are absent from the public catalogue: '
      '${constrainedIds.difference(catalogIds).join(',')}.',
    );
  }

  final ranked = List<_RankingRow>.of(sourceRows)
    ..sort((left, right) {
      var result = right.winDelta.compareTo(left.winDelta);
      if (result != 0) return result;
      result = right.progressDelta.compareTo(left.progressDelta);
      if (result != 0) return result;
      result = right.avgScore.compareTo(left.avgScore);
      if (result != 0) return result;
      return left.id.compareTo(right.id);
    });

  final assignments = <_Assignment>[
    for (var index = 0; index < ranked.length; index++)
      _Assignment(
        row: ranked[index],
        rank: index + 1,
        initialRarity: _rarityForRank(index),
        assignedRarity: _rarityForRank(index),
      ),
  ];

  final forced =
      assignments
          .where((assignment) => _isConstrainedId(assignment.row.id))
          .toList()
        ..sort((left, right) => left.rank.compareTo(right.rank));
  for (final assignment in forced) {
    final forcedRarity = _forcedRarityById[assignment.row.id];
    final minimumRarity = _minimumRarityById[assignment.row.id];
    final targetRarity = forcedRarity ?? minimumRarity!;
    assignment.constraint = _constraintFor(assignment.row.id);
    final constraintSatisfied = forcedRarity != null
        ? assignment.assignedRarity == targetRarity
        : _rarityStrength(assignment.assignedRarity) >=
              _rarityStrength(targetRarity);
    if (constraintSatisfied) {
      assignment.adjustmentReason = forcedRarity != null
          ? 'constraint already satisfied'
          : 'minimum already satisfied; measured tier preserved';
      continue;
    }
    final cameFromStrongerTier =
        _rarityStrength(assignment.assignedRarity) >
        _rarityStrength(targetRarity);
    final candidates =
        assignments
            .where(
              (candidate) =>
                  candidate.assignedRarity == targetRarity &&
                  !_isConstrainedId(candidate.row.id),
            )
            .toList()
          ..sort(
            (left, right) => cameFromStrongerTier
                ? left.rank.compareTo(right.rank)
                : right.rank.compareTo(left.rank),
          );
    if (candidates.isEmpty) {
      throw StateError(
        'No boundary candidate available to move ${assignment.row.id} '
        'into $targetRarity.',
      );
    }
    final candidate = candidates.first;
    final previous = assignment.assignedRarity;
    assignment.assignedRarity = targetRarity;
    candidate.assignedRarity = previous;
    assignment.swappedWith = candidate.row.id;
    candidate.swappedWith = assignment.row.id;
    assignment.adjustmentReason =
        '${assignment.constraint}; nearest-boundary swap';
    candidate.adjustmentReason =
        'nearest-boundary swap for ${assignment.row.id}';
  }

  final counts = _countAssignments(assignments);
  for (final entry in _expectedCounts.entries) {
    if (counts[entry.key] != entry.value) {
      throw StateError(
        '${entry.key} count is ${counts[entry.key]}, expected ${entry.value}.',
      );
    }
  }
  for (final entry in _forcedRarityById.entries) {
    final assignment = assignments.singleWhere(
      (row) => row.row.id == entry.key,
    );
    if (assignment.assignedRarity != entry.value) {
      throw StateError('${entry.key} was not assigned ${entry.value}.');
    }
  }
  for (final entry in _minimumRarityById.entries) {
    final assignment = assignments.singleWhere(
      (row) => row.row.id == entry.key,
    );
    if (_rarityStrength(assignment.assignedRarity) <
        _rarityStrength(entry.value)) {
      throw StateError(
        '${entry.key} was assigned ${assignment.assignedRarity}, below its '
        '${entry.value} minimum.',
      );
    }
  }
  return assignments;
}

int _rarityStrength(String rarity) => switch (rarity) {
  'common' => 0,
  'uncommon' => 1,
  'rare' => 2,
  'wild' => 3,
  _ => throw ArgumentError.value(rarity, 'rarity', 'Unknown rarity'),
};

String _constraintFor(String id) {
  if (id == 'warm_up') {
    return 'semantic floor: +0.60 strictly dominates Common Opening Act '
        '+0.50; minimum Uncommon';
  }
  if (id == 'marathoner') {
    return 'semantic floor: +0.20 per displayed remaining play strictly '
        'dominates Common Copper/Opening Act; minimum Uncommon';
  }
  return 'design anchor: fixed ${_forcedRarityById[id]}';
}

String _rarityForRank(int zeroBasedRank) {
  if (zeroBasedRank < 7) return 'wild';
  if (zeroBasedRank < 30) return 'rare';
  if (zeroBasedRank < 66) return 'uncommon';
  return 'common';
}

Map<String, int> _countAssignments(List<_Assignment> assignments) {
  final counts = <String, int>{
    for (final rarity in _expectedCounts.keys) rarity: 0,
  };
  for (final assignment in assignments) {
    counts[assignment.assignedRarity] =
        (counts[assignment.assignedRarity] ?? 0) + 1;
  }
  return counts;
}

void _writeOutputs({
  required String inputPath,
  required List<_Assignment> assignments,
  required File csvOutput,
  required File jsonOutput,
}) {
  csvOutput.parent.createSync(recursive: true);
  jsonOutput.parent.createSync(recursive: true);

  const headers = <String>[
    'rank',
    'joker',
    'name',
    'winDelta',
    'progressDelta',
    'avgScore',
    'initialRarity',
    'assignedRarity',
    'constraint',
    'adjustmentReason',
    'forcedUncommon',
    'minimumRarity',
    'designAnchor',
    'swappedWith',
  ];
  final catalogById = <String, JokerDefinition>{
    for (final joker in jokerCatalog) joker.id: joker,
  };
  final csv = StringBuffer()..writeln(headers.map(_csvField).join(','));
  final jsonRows = <Map<String, Object?>>[];
  for (final assignment in assignments) {
    final values = <Object?>[
      assignment.rank,
      assignment.row.id,
      catalogById[assignment.row.id]!.name,
      assignment.row.winDelta,
      assignment.row.progressDelta,
      assignment.row.avgScore,
      assignment.initialRarity,
      assignment.assignedRarity,
      assignment.constraint,
      assignment.adjustmentReason,
      _forcedRarityById[assignment.row.id] == 'uncommon',
      _minimumRarityById[assignment.row.id],
      _forcedRarityById.containsKey(assignment.row.id),
      assignment.swappedWith,
    ];
    csv.writeln(
      values.map((value) => _csvField(value?.toString() ?? '')).join(','),
    );
    jsonRows.add(<String, Object?>{
      for (var index = 0; index < headers.length; index++)
        headers[index]: values[index],
    });
  }
  csvOutput.writeAsStringSync(csv.toString());

  final counts = _countAssignments(assignments);
  final jsonDocument = <String, Object?>{
    'schemaVersion': 1,
    'source': inputPath,
    'publicJokerCount': assignments.length,
    'ranking': <String>[
      'winDelta descending',
      'progressDelta descending',
      'avgScore descending',
      'joker id ascending',
    ],
    'targetCounts': _expectedCounts,
    'actualCounts': counts,
    'forcedRarities': _forcedRarityById,
    'minimumRarities': _minimumRarityById,
    'semanticFloors': <String, String>{
      'warm_up':
          'Warm-Up +0.60 strictly dominates Common Opening Act +0.50, so it '
          'cannot be Common. A measured Rare or Wild result is preserved.',
      'marathoner':
          'Marathoner +0.20 per displayed remaining play strictly dominates '
          'Common Copper Chip/Opening Act, so it cannot be Common. '
          'A measured Rare or Wild result is preserved.',
    },
    'designAnchors': <String, Object>{
      'rarityById': _forcedRarityById,
      'reason':
          'These identity-defining tiers remain fixed while the matched '
          'five-Joker harness ranks the rest of the pool.',
    },
    'rarityById': <String, String>{
      for (final assignment in assignments)
        assignment.row.id: assignment.assignedRarity,
    },
    'assignments': jsonRows,
  };
  jsonOutput.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(jsonDocument),
  );
}

List<List<String>> _parseCsv(String input) {
  final records = <List<String>>[];
  var record = <String>[];
  var field = StringBuffer();
  var quoted = false;

  for (var index = 0; index < input.length; index++) {
    final character = input[index];
    if (quoted) {
      if (character == '"') {
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = false;
        }
      } else {
        field.write(character);
      }
      continue;
    }
    if (character == '"') {
      quoted = true;
    } else if (character == ',') {
      record.add(field.toString());
      field = StringBuffer();
    } else if (character == '\n') {
      record.add(field.toString());
      records.add(record);
      record = <String>[];
      field = StringBuffer();
    } else if (character != '\r') {
      field.write(character);
    }
  }
  if (quoted) throw const FormatException('CSV ends inside a quoted field.');
  if (field.isNotEmpty || record.isNotEmpty) {
    record.add(field.toString());
    records.add(record);
  }
  return records;
}

String _csvField(String value) => '"${value.replaceAll('"', '""')}"';

String _replaceExtension(String path, String suffix) {
  final dot = path.lastIndexOf('.');
  final separator = path.lastIndexOf(RegExp(r'[/\\]'));
  return dot > separator ? '${path.substring(0, dot)}$suffix' : '$path$suffix';
}

void _runSelfTest() {
  final rows = <_RankingRow>[
    for (var index = 0; index < jokerCatalog.length; index++)
      _RankingRow(
        id: jokerCatalog[index].id,
        winDelta: (jokerCatalog.length - index).toDouble(),
        progressDelta: 0,
        avgScore: 0,
      ),
  ];

  // Exercise both swap directions: baseline anchors begin in Wild while the
  // fixed/minimum Uncommon Jokers begin in Common.
  final constrained = <String, _RankingRow>{
    for (final row in rows)
      if (_isConstrainedId(row.id)) row.id: row,
  };
  rows.removeWhere((row) => _isConstrainedId(row.id));
  rows.insertAll(0, <_RankingRow>[
    constrained['copper']!.copyWith(winDelta: 10002),
    constrained['presser']!.copyWith(winDelta: 10001),
  ]);
  rows.addAll(<_RankingRow>[
    constrained['polish']!.copyWith(winDelta: -10001),
    constrained['roller']!.copyWith(winDelta: -10002),
    constrained['warm_up']!.copyWith(winDelta: -10003),
    constrained['marathoner']!.copyWith(winDelta: -10004),
  ]);

  final assignments = _assignRarities(rows);
  final counts = _countAssignments(assignments);
  if (!_expectedCounts.entries.every(
    (entry) => counts[entry.key] == entry.value,
  )) {
    throw StateError('Self-test produced invalid counts: $counts');
  }
  for (final entry in _forcedRarityById.entries) {
    final assignment = assignments.singleWhere(
      (row) => row.row.id == entry.key,
    );
    if (assignment.assignedRarity != entry.value ||
        assignment.constraint == null ||
        assignment.swappedWith == null) {
      throw StateError(
        'Self-test did not enforce/provenance ${entry.key}=${entry.value}.',
      );
    }
  }
  for (final entry in _minimumRarityById.entries) {
    final assignment = assignments.singleWhere(
      (row) => row.row.id == entry.key,
    );
    if (assignment.assignedRarity != 'uncommon' ||
        assignment.constraint == null ||
        assignment.swappedWith == null) {
      throw StateError(
        'Self-test did not promote/provenance ${entry.key} to Uncommon.',
      );
    }
  }

  // A semantic minimum is not a fixed tier: natural Rare/Wild results stay.
  final naturallyStrong = <_RankingRow>[
    constrained['warm_up']!.copyWith(winDelta: 20002),
    constrained['marathoner']!.copyWith(winDelta: 20001),
    constrained['copper']!.copyWith(winDelta: 10002),
    constrained['presser']!.copyWith(winDelta: 10001),
    ...rows.where(
      (row) =>
          row.id != 'warm_up' &&
          row.id != 'marathoner' &&
          row.id != 'copper' &&
          row.id != 'presser',
    ),
  ];
  final strongAssignments = _assignRarities(naturallyStrong);
  for (final id in _minimumRarityById.keys) {
    final assignment = strongAssignments.singleWhere((row) => row.row.id == id);
    if (assignment.initialRarity != 'wild' ||
        assignment.assignedRarity != 'wild' ||
        assignment.swappedWith != null) {
      throw StateError(
        'Self-test did not preserve naturally Wild minimum Joker $id.',
      );
    }
  }
}

class _RankingRow {
  const _RankingRow({
    required this.id,
    required this.winDelta,
    required this.progressDelta,
    required this.avgScore,
  });

  final String id;
  final double winDelta;
  final double progressDelta;
  final double avgScore;

  _RankingRow copyWith({
    double? winDelta,
    double? progressDelta,
    double? avgScore,
  }) {
    return _RankingRow(
      id: id,
      winDelta: winDelta ?? this.winDelta,
      progressDelta: progressDelta ?? this.progressDelta,
      avgScore: avgScore ?? this.avgScore,
    );
  }
}

class _Assignment {
  _Assignment({
    required this.row,
    required this.rank,
    required this.initialRarity,
    required this.assignedRarity,
  });

  final _RankingRow row;
  final int rank;
  final String initialRarity;
  String assignedRarity;
  String? constraint;
  String? adjustmentReason;
  String? swappedWith;
}

class _Options {
  const _Options({
    required this.input,
    required this.csvOutput,
    required this.jsonOutput,
    required this.selfTest,
  });

  factory _Options.parse(List<String> arguments) {
    final values = <String, String>{};
    var selfTest = false;
    for (final argument in arguments) {
      if (argument == '--self-test') {
        selfTest = true;
        continue;
      }
      if (!argument.startsWith('--') || !argument.contains('=')) {
        throw FormatException(
          'Expected --input=path [--csv-output=path] '
          '[--json-output=path] or --self-test; got "$argument".',
        );
      }
      final separator = argument.indexOf('=');
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
    final unknown = values.keys.toSet().difference(const {
      'input',
      'csv-output',
      'json-output',
    });
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown option(s): ${unknown.join(', ')}.');
    }
    if (!selfTest && (values['input'] == null || values['input']!.isEmpty)) {
      throw const FormatException('--input is required.');
    }
    return _Options(
      input: values['input'],
      csvOutput: values['csv-output'],
      jsonOutput: values['json-output'],
      selfTest: selfTest,
    );
  }

  final String? input;
  final String? csvOutput;
  final String? jsonOutput;
  final bool selfTest;
}

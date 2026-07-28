import 'dart:convert';
import 'dart:io';

/// Safely applies the measured rarity JSON emitted by
/// `tool/assign_joker_rarities.dart`.
///
/// Preview and validate without writing:
/// `dart run tool/apply_joker_rarities.dart --input=path --check`
///
/// Apply after review (an external backup is written under `build/` first):
/// `dart run tool/apply_joker_rarities.dart --input=path --apply`
const int _expectedPublicJokers = 102;
const Map<String, int> _expectedTierCounts = <String, int>{
  'common': 36,
  'uncommon': 36,
  'rare': 23,
  'wild': 7,
};
const Set<String> _validRarities = <String>{
  'common',
  'uncommon',
  'rare',
  'wild',
};
const String _devJokerId = 'devx20';

void main(List<String> arguments) {
  try {
    final options = _Options.parse(arguments);
    if (options.selfTest) {
      _runSelfTest();
      stdout.writeln('SELF_TEST=PASS');
      return;
    }

    final assignmentFile = File(options.input!);
    final catalogFile = File(options.catalog);
    if (!assignmentFile.existsSync()) {
      throw ArgumentError(
        'Rarity assignment JSON does not exist: ${assignmentFile.path}',
      );
    }
    if (!catalogFile.existsSync()) {
      throw ArgumentError(
        'Joker catalogue does not exist: ${catalogFile.path}',
      );
    }

    final assignments = _readAssignments(assignmentFile.readAsStringSync());
    final original = catalogFile.readAsStringSync();
    final catalogue = _CatalogueSource.parse(original);
    final plan = _buildPlan(catalogue, assignments);

    _printSummary(
      mode: options.mode!,
      catalogPath: catalogFile.path,
      assignments: assignments,
      plan: plan,
    );
    if (options.mode == _Mode.check) {
      stdout.writeln('CHECK=PASS');
      return;
    }

    final backup = _applySafely(
      catalogFile: catalogFile,
      original: original,
      updated: plan.updatedSource,
      backupDirectory: options.backupDirectory,
    );
    stdout.writeln('BACKUP=${backup.path}');
    stdout.writeln('APPLY=PASS');
  } on Object catch (error) {
    stderr.writeln('Rarity catalogue update failed: $error');
    exitCode = 2;
  }
}

Map<String, String> _readAssignments(String input) {
  final decoded = jsonDecode(input);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Assignment JSON root must be an object.');
  }
  if (decoded['publicJokerCount'] != _expectedPublicJokers) {
    throw FormatException(
      'publicJokerCount must be $_expectedPublicJokers; '
      'found ${decoded['publicJokerCount']}.',
    );
  }

  final rows = decoded['assignments'];
  if (rows is! List<dynamic>) {
    throw const FormatException('Assignment JSON has no assignments array.');
  }
  final assignments = <String, String>{};
  final duplicates = <String>{};
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    if (row is! Map<String, dynamic>) {
      throw FormatException('assignments[$index] must be an object.');
    }
    final id = row['joker'];
    final rarity = row['assignedRarity'];
    if (id is! String || id.isEmpty) {
      throw FormatException(
        'assignments[$index].joker must be a non-empty id.',
      );
    }
    if (rarity is! String || !_validRarities.contains(rarity)) {
      throw FormatException(
        'assignments[$index] has invalid assignedRarity "$rarity".',
      );
    }
    if (assignments.containsKey(id)) duplicates.add(id);
    assignments[id] = rarity;
  }
  if (duplicates.isNotEmpty) {
    final sorted = duplicates.toList()..sort();
    throw StateError(
      'Duplicate Joker assignment row(s): ${sorted.join(', ')}.',
    );
  }
  if (rows.length != _expectedPublicJokers ||
      assignments.length != _expectedPublicJokers) {
    throw StateError(
      'Expected exactly $_expectedPublicJokers unique assignment rows; '
      'found ${rows.length} rows / ${assignments.length} unique.',
    );
  }
  if (assignments.containsKey(_devJokerId)) {
    throw StateError(
      'Owner-only $_devJokerId must not appear in public rarity assignments.',
    );
  }

  final rarityMap = decoded['rarityById'];
  if (rarityMap is! Map<String, dynamic>) {
    throw const FormatException('Assignment JSON has no rarityById object.');
  }
  final mappedAssignments = <String, String>{};
  for (final entry in rarityMap.entries) {
    if (entry.value is! String || !_validRarities.contains(entry.value)) {
      throw FormatException(
        'rarityById.${entry.key} has invalid rarity "${entry.value}".',
      );
    }
    mappedAssignments[entry.key] = entry.value! as String;
  }
  _requireSameAssignments(
    expected: assignments,
    actual: mappedAssignments,
    label: 'rarityById',
  );

  final counts = _countTiers(assignments.values);
  _requireExpectedCounts(counts, label: 'computed assignments');
  _validateDeclaredCounts(decoded['targetCounts'], label: 'targetCounts');
  _validateDeclaredCounts(decoded['actualCounts'], label: 'actualCounts');
  return assignments;
}

void _validateDeclaredCounts(Object? value, {required String label}) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Assignment JSON has no $label object.');
  }
  final counts = <String, int>{};
  for (final rarity in _validRarities) {
    final count = value[rarity];
    if (count is! int) {
      throw FormatException('$label.$rarity must be an integer.');
    }
    counts[rarity] = count;
  }
  final unknown = value.keys.toSet().difference(_validRarities);
  if (unknown.isNotEmpty) {
    throw FormatException('$label has unknown tier(s): ${unknown.join(', ')}.');
  }
  _requireExpectedCounts(counts, label: label);
}

void _requireSameAssignments({
  required Map<String, String> expected,
  required Map<String, String> actual,
  required String label,
}) {
  final missing = expected.keys.toSet().difference(actual.keys.toSet()).toList()
    ..sort();
  final unknown = actual.keys.toSet().difference(expected.keys.toSet()).toList()
    ..sort();
  final mismatched =
      expected.keys
          .where((id) => actual.containsKey(id) && expected[id] != actual[id])
          .toList()
        ..sort();
  if (missing.isNotEmpty || unknown.isNotEmpty || mismatched.isNotEmpty) {
    throw StateError(
      '$label does not exactly match assignments: '
      'missing=${missing.join(',')}; unknown=${unknown.join(',')}; '
      'mismatched=${mismatched.join(',')}.',
    );
  }
}

_UpdatePlan _buildPlan(
  _CatalogueSource catalogue,
  Map<String, String> assignments,
) {
  final sourceIds = catalogue.publicDefinitions.map((item) => item.id).toSet();
  final assignmentIds = assignments.keys.toSet();
  final missing = sourceIds.difference(assignmentIds).toList()..sort();
  final unknown = assignmentIds.difference(sourceIds).toList()..sort();
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw StateError(
      'Assignments do not exactly match the public catalogue: '
      'missing=${missing.join(',')}; unknown=${unknown.join(',')}.',
    );
  }

  var updated = catalogue.source;
  var changed = 0;
  final definitions = List<_JokerSourceDefinition>.of(
    catalogue.publicDefinitions,
  )..sort((left, right) => right.rarityStart.compareTo(left.rarityStart));
  for (final definition in definitions) {
    final target = assignments[definition.id]!;
    if (target == definition.rarity) continue;
    updated = updated.replaceRange(
      definition.rarityStart,
      definition.rarityEnd,
      target,
    );
    changed++;
  }

  final updatedCatalogue = _CatalogueSource.parse(updated);
  final updatedAssignments = <String, String>{
    for (final definition in updatedCatalogue.publicDefinitions)
      definition.id: definition.rarity,
  };
  _requireSameAssignments(
    expected: assignments,
    actual: updatedAssignments,
    label: 'updated catalogue',
  );
  if (catalogue.devDefinition.sourceText !=
      updatedCatalogue.devDefinition.sourceText) {
    throw StateError('Owner-only DEV ×20 definition would be modified.');
  }
  if (_redactPublicRarities(catalogue) !=
      _redactPublicRarities(updatedCatalogue)) {
    throw StateError('Planned update changes content beyond rarity values.');
  }

  return _UpdatePlan(
    updatedSource: updated,
    changed: changed,
    unchanged: _expectedPublicJokers - changed,
  );
}

String _redactPublicRarities(_CatalogueSource catalogue) {
  var redacted = catalogue.source;
  final definitions = List<_JokerSourceDefinition>.of(
    catalogue.publicDefinitions,
  )..sort((left, right) => right.rarityStart.compareTo(left.rarityStart));
  for (final definition in definitions) {
    redacted = redacted.replaceRange(
      definition.rarityStart,
      definition.rarityEnd,
      '<RARITY>',
    );
  }
  return redacted;
}

void _printSummary({
  required _Mode mode,
  required String catalogPath,
  required Map<String, String> assignments,
  required _UpdatePlan plan,
}) {
  final counts = _countTiers(assignments.values);
  stdout.writeln('MODE=${mode.name.toUpperCase()}');
  stdout.writeln('CATALOG=$catalogPath');
  stdout.writeln('PUBLIC_DEFINITIONS=$_expectedPublicJokers');
  stdout.writeln('ASSIGNMENT_IDS=${assignments.length}');
  stdout.writeln(
    'RARITY_COUNTS='
    'common:${counts['common']},'
    'uncommon:${counts['uncommon']},'
    'rare:${counts['rare']},'
    'wild:${counts['wild']}',
  );
  stdout.writeln('RARITY_FIELDS_CHANGED=${plan.changed}');
  stdout.writeln('RARITY_FIELDS_UNCHANGED=${plan.unchanged}');
  stdout.writeln('DEV_X20=UNCHANGED');
}

Map<String, int> _countTiers(Iterable<String> rarities) {
  final counts = <String, int>{for (final rarity in _validRarities) rarity: 0};
  for (final rarity in rarities) {
    counts[rarity] = (counts[rarity] ?? 0) + 1;
  }
  return counts;
}

void _requireExpectedCounts(Map<String, int> counts, {required String label}) {
  for (final entry in _expectedTierCounts.entries) {
    if (counts[entry.key] != entry.value) {
      throw StateError(
        '$label has ${entry.key}=${counts[entry.key]}; '
        'expected ${entry.value}.',
      );
    }
  }
}

File _applySafely({
  required File catalogFile,
  required String original,
  required String updated,
  String? backupDirectory,
}) {
  if (original == updated) {
    throw StateError(
      'No rarity fields differ. Refusing --apply because there is nothing '
      'to update.',
    );
  }
  final backupRoot = backupDirectory == null
      ? Directory(
          '${catalogFile.parent.parent.parent.path}'
          '${Platform.pathSeparator}build'
          '${Platform.pathSeparator}rarity-backups',
        )
      : Directory(backupDirectory);
  backupRoot.createSync(recursive: true);
  final stamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(RegExp(r'[-:]'), '')
      .replaceAll('.', '');
  final backup = File(
    '${backupRoot.path}${Platform.pathSeparator}'
    'joker_catalog.$stamp.dart',
  );
  if (backup.existsSync()) {
    throw StateError('Backup already exists: ${backup.path}');
  }
  backup.writeAsStringSync(original, flush: true);
  if (backup.readAsStringSync() != original) {
    throw StateError('Backup verification failed: ${backup.path}');
  }

  final nonce = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
  final temporary = File('${catalogFile.path}.$nonce.tmp');
  final swappedOriginal = File('${catalogFile.path}.$nonce.original');
  temporary.writeAsStringSync(updated, flush: true);
  if (temporary.readAsStringSync() != updated) {
    temporary.deleteSync();
    throw StateError('Temporary catalogue verification failed.');
  }

  catalogFile.renameSync(swappedOriginal.path);
  try {
    temporary.renameSync(catalogFile.path);
  } on Object {
    swappedOriginal.renameSync(catalogFile.path);
    rethrow;
  }

  try {
    if (catalogFile.readAsStringSync() != updated) {
      final failed = File('${catalogFile.path}.$nonce.failed');
      catalogFile.renameSync(failed.path);
      swappedOriginal.renameSync(catalogFile.path);
      throw StateError(
        'Applied catalogue verification failed. Original restored; '
        'failed output retained at ${failed.path}.',
      );
    }
    swappedOriginal.deleteSync();
  } on Object {
    if (!catalogFile.existsSync() && swappedOriginal.existsSync()) {
      swappedOriginal.renameSync(catalogFile.path);
    }
    rethrow;
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
  return backup;
}

class _CatalogueSource {
  const _CatalogueSource({
    required this.source,
    required this.publicDefinitions,
    required this.devDefinition,
  });

  factory _CatalogueSource.parse(String source) {
    const listMarker =
        'const List<JokerDefinition> jokerCatalog = <JokerDefinition>';
    final markerStart = source.indexOf(listMarker);
    if (markerStart < 0 || source.indexOf(listMarker, markerStart + 1) >= 0) {
      throw StateError('Expected exactly one public jokerCatalog declaration.');
    }
    final listOpen = source.indexOf('[', markerStart + listMarker.length);
    if (listOpen < 0) {
      throw StateError('Public jokerCatalog has no opening bracket.');
    }
    final listClose = _matchingDelimiter(source, listOpen, '[', ']');
    final definitions = _parseDefinitions(
      source,
      start: listOpen + 1,
      end: listClose,
    );
    final ids = <String>{};
    final duplicates = <String>{};
    for (final definition in definitions) {
      if (!ids.add(definition.id)) duplicates.add(definition.id);
    }
    if (definitions.length != _expectedPublicJokers ||
        ids.length != _expectedPublicJokers ||
        duplicates.isNotEmpty) {
      final sortedDuplicates = duplicates.toList()..sort();
      throw StateError(
        'Expected $_expectedPublicJokers unique public JokerDefinition blocks; '
        'found ${definitions.length} blocks / ${ids.length} unique; '
        'duplicates=${sortedDuplicates.join(',')}.',
      );
    }
    if (ids.contains(_devJokerId)) {
      throw StateError('Owner-only $_devJokerId appears in jokerCatalog.');
    }

    const devMarker = 'const JokerDefinition devTwentyXJoker = JokerDefinition';
    final devStart = source.indexOf(devMarker, listClose);
    if (devStart < 0 ||
        source.indexOf(devMarker, devStart + devMarker.length) >= 0) {
      throw StateError('Expected exactly one DEV ×20 definition.');
    }
    final devOpen = source.indexOf('(', devStart + devMarker.length);
    if (devOpen < 0) throw StateError('DEV ×20 definition has no body.');
    final devClose = _matchingDelimiter(source, devOpen, '(', ')');
    final devDefinition = _parseDefinition(source, devStart, devClose + 1);
    if (devDefinition.id != _devJokerId || devDefinition.rarity != 'wild') {
      throw StateError(
        'DEV ×20 identity changed: id=${devDefinition.id}, '
        'rarity=${devDefinition.rarity}.',
      );
    }

    return _CatalogueSource(
      source: source,
      publicDefinitions: definitions,
      devDefinition: devDefinition,
    );
  }

  final String source;
  final List<_JokerSourceDefinition> publicDefinitions;
  final _JokerSourceDefinition devDefinition;
}

List<_JokerSourceDefinition> _parseDefinitions(
  String source, {
  required int start,
  required int end,
}) {
  final definitions = <_JokerSourceDefinition>[];
  var cursor = start;
  while (true) {
    final token = _findCodeToken(source, 'JokerDefinition', cursor, end);
    if (token < 0) break;
    var open = token + 'JokerDefinition'.length;
    while (open < end && _isWhitespace(source.codeUnitAt(open))) {
      open++;
    }
    if (open >= end || source[open] != '(') {
      throw StateError(
        'Unexpected JokerDefinition token at source offset $token.',
      );
    }
    final close = _matchingDelimiter(source, open, '(', ')');
    if (close >= end) {
      throw StateError('JokerDefinition at offset $token leaves public list.');
    }
    definitions.add(_parseDefinition(source, token, close + 1));
    cursor = close + 1;
  }
  return definitions;
}

_JokerSourceDefinition _parseDefinition(String source, int start, int end) {
  final block = source.substring(start, end);
  final idMatches = RegExp(
    r"^[ \t]*id:[ \t]*'([^'\r\n]+)'[ \t]*,[ \t]*$",
    multiLine: true,
  ).allMatches(block).toList();
  final rarityMatches = RegExp(
    r'^[ \t]*rarity:[ \t]*JokerRarity\.'
    r'(common|uncommon|rare|wild)[ \t]*,[ \t]*$',
    multiLine: true,
  ).allMatches(block).toList();
  if (idMatches.length != 1 || rarityMatches.length != 1) {
    throw StateError(
      'JokerDefinition at source offset $start must contain exactly one '
      'literal id and rarity; found ids=${idMatches.length}, '
      'rarities=${rarityMatches.length}.',
    );
  }
  final id = idMatches.single.group(1)!;
  final rarityMatch = rarityMatches.single;
  final rarity = rarityMatch.group(1)!;
  final rarityOffset = rarityMatch.group(0)!.lastIndexOf(rarity);
  if (rarityOffset < 0) {
    throw StateError('Unable to locate rarity for Joker "$id".');
  }
  return _JokerSourceDefinition(
    id: id,
    rarity: rarity,
    rarityStart: start + rarityMatch.start + rarityOffset,
    rarityEnd: start + rarityMatch.start + rarityOffset + rarity.length,
    sourceText: block,
  );
}

int _findCodeToken(String source, String token, int start, int end) {
  var index = start;
  var quote = '';
  var lineComment = false;
  var blockComment = false;
  while (index < end) {
    final character = source[index];
    final next = index + 1 < end ? source[index + 1] : '';
    if (lineComment) {
      if (character == '\n') lineComment = false;
      index++;
      continue;
    }
    if (blockComment) {
      if (character == '*' && next == '/') {
        blockComment = false;
        index += 2;
      } else {
        index++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (character == r'\') {
        index += 2;
      } else {
        if (character == quote) quote = '';
        index++;
      }
      continue;
    }
    if (character == '/' && next == '/') {
      lineComment = true;
      index += 2;
      continue;
    }
    if (character == '/' && next == '*') {
      blockComment = true;
      index += 2;
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
      index++;
      continue;
    }
    if (source.startsWith(token, index) &&
        _hasIdentifierBoundaries(source, index, token.length)) {
      return index;
    }
    index++;
  }
  return -1;
}

int _matchingDelimiter(
  String source,
  int openIndex,
  String open,
  String close,
) {
  var depth = 0;
  var index = openIndex;
  var quote = '';
  var lineComment = false;
  var blockComment = false;
  while (index < source.length) {
    final character = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    if (lineComment) {
      if (character == '\n') lineComment = false;
      index++;
      continue;
    }
    if (blockComment) {
      if (character == '*' && next == '/') {
        blockComment = false;
        index += 2;
      } else {
        index++;
      }
      continue;
    }
    if (quote.isNotEmpty) {
      if (character == r'\') {
        index += 2;
      } else {
        if (character == quote) quote = '';
        index++;
      }
      continue;
    }
    if (character == '/' && next == '/') {
      lineComment = true;
      index += 2;
      continue;
    }
    if (character == '/' && next == '*') {
      blockComment = true;
      index += 2;
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
    } else if (character == open) {
      depth++;
    } else if (character == close) {
      depth--;
      if (depth == 0) return index;
    }
    index++;
  }
  throw StateError(
    'No matching "$close" for "$open" at source offset $openIndex.',
  );
}

bool _hasIdentifierBoundaries(String source, int start, int length) {
  bool identifierAt(int index) {
    if (index < 0 || index >= source.length) return false;
    final unit = source.codeUnitAt(index);
    return (unit >= 48 && unit <= 57) ||
        (unit >= 65 && unit <= 90) ||
        (unit >= 97 && unit <= 122) ||
        unit == 95;
  }

  return !identifierAt(start - 1) && !identifierAt(start + length);
}

bool _isWhitespace(int unit) =>
    unit == 0x20 || unit == 0x09 || unit == 0x0a || unit == 0x0d;

void _runSelfTest() {
  final assignments = <String, String>{};
  final rows = <Map<String, Object?>>[];
  final rarityMap = <String, String>{};
  final definitions = StringBuffer();
  for (var index = 0; index < _expectedPublicJokers; index++) {
    final id = 'joker_$index';
    final rarity = switch (index) {
      < 36 => 'common',
      < 72 => 'uncommon',
      < 95 => 'rare',
      _ => 'wild',
    };
    assignments[id] = rarity;
    rarityMap[id] = rarity;
    rows.add(<String, Object?>{'joker': id, 'assignedRarity': rarity});
    definitions.writeln('''
  JokerDefinition(
    id: '$id',
    name: 'Joker $index',
    rarity: JokerRarity.${index.isEven ? 'wild' : 'common'},
    description: 'Self test.',
    price: 1,
    unlock: 0,
    effect: JokerEffect.fake,
  ),''');
  }
  final json = jsonEncode(<String, Object?>{
    'publicJokerCount': _expectedPublicJokers,
    'targetCounts': _expectedTierCounts,
    'actualCounts': _expectedTierCounts,
    'rarityById': rarityMap,
    'assignments': rows,
  });
  final source =
      '''
class JokerDefinition {}
const List<JokerDefinition> jokerCatalog = <JokerDefinition>[
$definitions
];
const JokerDefinition devTwentyXJoker = JokerDefinition(
  id: 'devx20',
  name: 'DEV ×20',
  rarity: JokerRarity.wild,
  description: 'Owner-only.',
  price: 0,
  unlock: 0,
  effect: JokerEffect.devTwentyX,
);
''';

  final parsedAssignments = _readAssignments(json);
  final catalogue = _CatalogueSource.parse(source);
  final plan = _buildPlan(catalogue, parsedAssignments);
  if (plan.changed == 0 ||
      !plan.updatedSource.contains('id: \'devx20\'') ||
      !plan.updatedSource.contains('rarity: JokerRarity.wild')) {
    throw StateError('Happy-path self-test did not produce a guarded plan.');
  }

  _expectFailure(
    () => _CatalogueSource.parse(
      source.replaceFirst("id: 'joker_101'", "id: 'joker_100'"),
    ),
    'duplicate source id',
  );
  final missingRows = List<Map<String, Object?>>.of(rows)..removeLast();
  _expectFailure(
    () => _readAssignments(
      jsonEncode(<String, Object?>{
        'publicJokerCount': _expectedPublicJokers,
        'targetCounts': _expectedTierCounts,
        'actualCounts': _expectedTierCounts,
        'rarityById': rarityMap,
        'assignments': missingRows,
      }),
    ),
    'missing assignment',
  );
  final duplicateRows = List<Map<String, Object?>>.of(rows)
    ..[101] = Map<String, Object?>.of(rows[100]);
  _expectFailure(
    () => _readAssignments(
      jsonEncode(<String, Object?>{
        'publicJokerCount': _expectedPublicJokers,
        'targetCounts': _expectedTierCounts,
        'actualCounts': _expectedTierCounts,
        'rarityById': rarityMap,
        'assignments': duplicateRows,
      }),
    ),
    'duplicate assignment',
  );
  final unknownAssignments = Map<String, String>.of(assignments)
    ..remove('joker_101')
    ..['unknown'] = 'wild';
  _expectFailure(
    () => _buildPlan(catalogue, unknownAssignments),
    'unknown assignment',
  );
  final devAssignments = Map<String, String>.of(assignments)
    ..remove('joker_101')
    ..[_devJokerId] = 'wild';
  _expectFailure(() => _buildPlan(catalogue, devAssignments), 'DEV assignment');

  // Also exercise the parser and DEV guard against the live catalogue when
  // the self-test is launched from the Flutter project root.
  final liveFile = File('lib/domain/joker_catalog.dart');
  if (liveFile.existsSync()) {
    final liveCatalogue = _CatalogueSource.parse(liveFile.readAsStringSync());
    final liveAssignments = <String, String>{};
    for (
      var index = 0;
      index < liveCatalogue.publicDefinitions.length;
      index++
    ) {
      liveAssignments[liveCatalogue.publicDefinitions[index].id] =
          switch (index) {
            < 36 => 'common',
            < 72 => 'uncommon',
            < 95 => 'rare',
            _ => 'wild',
          };
    }
    final livePlan = _buildPlan(liveCatalogue, liveAssignments);
    if (livePlan.changed == 0) {
      throw StateError('Live-catalogue self-test produced no planned changes.');
    }
  }
}

void _expectFailure(void Function() operation, String label) {
  try {
    operation();
  } on Object {
    return;
  }
  throw StateError('Self-test expected failure for $label.');
}

class _JokerSourceDefinition {
  const _JokerSourceDefinition({
    required this.id,
    required this.rarity,
    required this.rarityStart,
    required this.rarityEnd,
    required this.sourceText,
  });

  final String id;
  final String rarity;
  final int rarityStart;
  final int rarityEnd;
  final String sourceText;
}

class _UpdatePlan {
  const _UpdatePlan({
    required this.updatedSource,
    required this.changed,
    required this.unchanged,
  });

  final String updatedSource;
  final int changed;
  final int unchanged;
}

enum _Mode { check, apply }

class _Options {
  const _Options({
    required this.input,
    required this.catalog,
    required this.mode,
    required this.backupDirectory,
    required this.selfTest,
  });

  factory _Options.parse(List<String> arguments) {
    final values = <String, String>{};
    _Mode? mode;
    var selfTest = false;
    for (final argument in arguments) {
      if (argument == '--self-test') {
        selfTest = true;
        continue;
      }
      if (argument == '--check' || argument == '--apply') {
        final next = argument == '--check' ? _Mode.check : _Mode.apply;
        if (mode != null) {
          throw const FormatException(
            'Choose exactly one of --check or --apply.',
          );
        }
        mode = next;
        continue;
      }
      if (!argument.startsWith('--') || !argument.contains('=')) {
        throw FormatException(
          'Expected --input=path (--check|--apply) '
          '[--catalog=path] [--backup-dir=path] or --self-test; '
          'got "$argument".',
        );
      }
      final separator = argument.indexOf('=');
      final key = argument.substring(2, separator);
      if (values.containsKey(key)) {
        throw FormatException('Duplicate option --$key.');
      }
      values[key] = argument.substring(separator + 1);
    }
    final unknown = values.keys.toSet().difference(const <String>{
      'input',
      'catalog',
      'backup-dir',
    });
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown option(s): ${unknown.join(', ')}.');
    }
    if (selfTest) {
      if (arguments.length != 1) {
        throw const FormatException('--self-test cannot be combined.');
      }
    } else {
      if (values['input'] == null || values['input']!.isEmpty) {
        throw const FormatException('--input is required.');
      }
      if (mode == null) {
        throw const FormatException(
          'Choose exactly one of --check or --apply.',
        );
      }
    }
    return _Options(
      input: values['input'],
      catalog: values['catalog'] ?? 'lib/domain/joker_catalog.dart',
      mode: mode,
      backupDirectory: values['backup-dir'],
      selfTest: selfTest,
    );
  }

  final String? input;
  final String catalog;
  final _Mode? mode;
  final String? backupDirectory;
  final bool selfTest;
}

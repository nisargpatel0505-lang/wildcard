import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/joker_catalog.dart';

const int _expectedPublicJokerCount = 102;
const String _devJokerId = 'devx20';

const Map<JokerRarity, PriceBand> _runShopBands = <JokerRarity, PriceBand>{
  JokerRarity.common: PriceBand(4, 6),
  JokerRarity.uncommon: PriceBand(5, 7),
  JokerRarity.rare: PriceBand(6, 8),
  JokerRarity.wild: PriceBand(10, 12),
};

void main(List<String> arguments) {
  try {
    final options = _Options.parse(arguments);
    if (options.help) {
      _printHelp();
      return;
    }
    if (options.selfTest) {
      _runSelfTest();
      stdout.writeln('PASS: Joker run-shop price audit self-test.');
      return;
    }

    final report = auditJokerRunShopPrices();
    final catalogFile = File(options.catalog);
    if (!catalogFile.existsSync()) {
      throw ArgumentError(
        'Joker catalogue does not exist: ${catalogFile.path}',
      );
    }
    final original = catalogFile.readAsStringSync();
    final catalogue = _CatalogueSource.parse(original);
    _validateSourceMatchesRuntime(catalogue);
    final plan = _buildPricePlan(catalogue);
    _requireAuditMatchesPlan(report, plan);

    if (options.mode == _Mode.check) {
      _printResult(
        options: options,
        report: report,
        plan: plan,
        applied: false,
      );
      if (!report.passed) exitCode = 1;
      return;
    }

    if (report.validationErrors.isNotEmpty) {
      throw StateError(
        'Catalogue validation failed; refusing to apply run-shop prices.',
      );
    }
    if (plan.changes.isEmpty) {
      throw StateError(
        'No public price fields differ. Refusing --apply because there is '
        'nothing to update.',
      );
    }
    final backup = _applySafely(
      catalogFile: catalogFile,
      original: original,
      updated: plan.updatedSource,
      backupDirectory: options.backupDirectory,
    );
    final appliedCatalogue = _CatalogueSource.parse(
      catalogFile.readAsStringSync(),
    );
    _verifyAppliedPlan(catalogue, appliedCatalogue);
    _printResult(
      options: options,
      report: report,
      plan: plan,
      applied: true,
      backupPath: backup.path,
    );
  } on Object catch (error) {
    stderr.writeln('Joker run-shop price operation failed: $error');
    exitCode = 2;
  }
}

JokerPriceAuditReport auditJokerRunShopPrices() {
  final validationErrors = <String>[];
  final definitionsById = <String, JokerDefinition>{};
  final duplicateIds = <String>{};
  final seenEffects = <JokerEffect>{};
  final duplicateEffects = <JokerEffect>{};

  for (final joker in jokerCatalog) {
    if (definitionsById.containsKey(joker.id)) {
      duplicateIds.add(joker.id);
    } else {
      definitionsById[joker.id] = joker;
    }
    if (!seenEffects.add(joker.effect)) duplicateEffects.add(joker.effect);
  }

  if (jokerCatalog.length != _expectedPublicJokerCount) {
    validationErrors.add(
      'Expected $_expectedPublicJokerCount public Jokers, '
      'found ${jokerCatalog.length}.',
    );
  }
  if (duplicateIds.isNotEmpty) {
    validationErrors.add(
      'Duplicate public Joker ids: ${_sortedStrings(duplicateIds).join(', ')}.',
    );
  }
  if (duplicateEffects.isNotEmpty) {
    final names = duplicateEffects.map((effect) => effect.name).toList()
      ..sort();
    validationErrors.add(
      'Duplicate public Joker effects: ${names.join(', ')}.',
    );
  }

  final declaredStarterIds = starterJokerIds.toSet();
  if (declaredStarterIds.length != starterJokerIds.length) {
    validationErrors.add('starterJokerIds contains duplicate ids.');
  }
  for (final starterId in starterJokerIds) {
    final joker = definitionsById[starterId];
    if (joker == null) {
      validationErrors.add(
        'Starter id "$starterId" is missing from the public catalogue.',
      );
      continue;
    }
    if (!joker.starter) {
      validationErrors.add(
        'Starter id "$starterId" is not marked starter: true.',
      );
    }
    if (joker.unlock != 0) {
      validationErrors.add(
        'Starter id "$starterId" has unlock ${joker.unlock}; expected 0.',
      );
    }
  }

  for (final joker in jokerCatalog) {
    if (joker.id.isEmpty) {
      validationErrors.add('A public Joker has an empty id.');
    }
    if (joker.price < 0) {
      validationErrors.add(
        '${joker.id} has negative run-shop price ${joker.price}.',
      );
    }
    if (joker.unlock < 0) {
      validationErrors.add(
        '${joker.id} has negative unlock value ${joker.unlock}.',
      );
    }
    if (joker.starter && !declaredStarterIds.contains(joker.id)) {
      validationErrors.add(
        '${joker.id} is marked starter but is absent from starterJokerIds.',
      );
    }
    if (!joker.starter && declaredStarterIds.contains(joker.id)) {
      validationErrors.add(
        '${joker.id} is listed in starterJokerIds but not marked starter.',
      );
    }
    if (joker.unlock == 0 && !joker.starter) {
      validationErrors.add(
        '${joker.id} is a free unlock but is not a declared starter.',
      );
    }
    if (joker.starter && joker.unlock != 0) {
      validationErrors.add(
        '${joker.id} is a starter but is not a free unlock.',
      );
    }
  }

  final findings = <JokerPriceFinding>[];
  for (final joker in jokerCatalog) {
    final band = _runShopBands[joker.rarity]!;
    if (!band.contains(joker.price)) {
      findings.add(
        JokerPriceFinding(
          id: joker.id,
          name: joker.name,
          rarity: joker.rarity,
          actualPrice: joker.price,
          suggestedPrice: band.clamp(joker.price),
          expectedBand: band,
          starter: joker.starter,
          freeUnlock: joker.unlock == 0,
        ),
      );
    }
  }
  findings.sort((left, right) {
    final rarityOrder = left.rarity.index.compareTo(right.rarity.index);
    return rarityOrder != 0 ? rarityOrder : left.id.compareTo(right.id);
  });

  return JokerPriceAuditReport(
    publicJokerCount: jokerCatalog.length,
    starterCount: jokerCatalog.where((joker) => joker.starter).length,
    freeUnlockCount: jokerCatalog.where((joker) => joker.unlock == 0).length,
    validationErrors: validationErrors,
    findings: findings,
  );
}

void _validateSourceMatchesRuntime(_CatalogueSource catalogue) {
  final runtimeById = <String, JokerDefinition>{
    for (final joker in jokerCatalog) joker.id: joker,
  };
  final sourceIds = catalogue.publicDefinitions.map((item) => item.id).toSet();
  final runtimeIds = runtimeById.keys.toSet();
  final missing = runtimeIds.difference(sourceIds).toList()..sort();
  final unknown = sourceIds.difference(runtimeIds).toList()..sort();
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw StateError(
      'Parsed source does not exactly match the compiled public catalogue: '
      'missing=${missing.join(',')}; unknown=${unknown.join(',')}.',
    );
  }
  for (final definition in catalogue.publicDefinitions) {
    final runtime = runtimeById[definition.id]!;
    if (definition.rarity != runtime.rarity ||
        definition.price != runtime.price) {
      throw StateError(
        'Parsed source differs from compiled ${definition.id}: '
        'source=${definition.rarity.name}/${definition.price}, '
        'runtime=${runtime.rarity.name}/${runtime.price}.',
      );
    }
  }
}

_PriceUpdatePlan _buildPricePlan(_CatalogueSource catalogue) {
  var updated = catalogue.source;
  final changes = <_PriceChange>[];
  final definitions = List<_JokerSourceDefinition>.of(
    catalogue.publicDefinitions,
  )..sort((left, right) => right.priceStart.compareTo(left.priceStart));
  for (final definition in definitions) {
    final band = _runShopBands[definition.rarity]!;
    final target = band.clamp(definition.price);
    if (target == definition.price) continue;
    changes.add(
      _PriceChange(
        id: definition.id,
        rarity: definition.rarity,
        before: definition.price,
        after: target,
      ),
    );
    updated = updated.replaceRange(
      definition.priceStart,
      definition.priceEnd,
      '$target',
    );
  }
  changes.sort((left, right) {
    final rarityOrder = left.rarity.index.compareTo(right.rarity.index);
    return rarityOrder != 0 ? rarityOrder : left.id.compareTo(right.id);
  });

  final updatedCatalogue = _CatalogueSource.parse(updated);
  _verifyAppliedPlan(catalogue, updatedCatalogue);
  return _PriceUpdatePlan(updatedSource: updated, changes: changes);
}

void _verifyAppliedPlan(_CatalogueSource original, _CatalogueSource updated) {
  if (original.devDefinition.sourceText != updated.devDefinition.sourceText) {
    throw StateError('Owner-only DEV ×20 definition would be modified.');
  }
  if (_redactPublicPrices(original) != _redactPublicPrices(updated)) {
    throw StateError('Planned update changes content beyond public prices.');
  }
  final originalIds = original.publicDefinitions.map((item) => item.id).toSet();
  final updatedIds = updated.publicDefinitions.map((item) => item.id).toSet();
  if (originalIds.length != _expectedPublicJokerCount ||
      updatedIds.length != _expectedPublicJokerCount ||
      originalIds.difference(updatedIds).isNotEmpty ||
      updatedIds.difference(originalIds).isNotEmpty) {
    throw StateError('Public catalogue identity changed during price update.');
  }
  for (final definition in updated.publicDefinitions) {
    final band = _runShopBands[definition.rarity]!;
    if (!band.contains(definition.price)) {
      throw StateError(
        'Updated ${definition.id} price ${definition.price} remains outside '
        '${definition.rarity.name} band ${band.minimum}-${band.maximum}.',
      );
    }
  }
}

void _requireAuditMatchesPlan(
  JokerPriceAuditReport report,
  _PriceUpdatePlan plan,
) {
  final findings = <String, String>{
    for (final finding in report.findings)
      finding.id: '${finding.actualPrice}->${finding.suggestedPrice}',
  };
  final changes = <String, String>{
    for (final change in plan.changes)
      change.id: '${change.before}->${change.after}',
  };
  if (findings.length != changes.length ||
      findings.keys.toSet().difference(changes.keys.toSet()).isNotEmpty ||
      changes.keys.toSet().difference(findings.keys.toSet()).isNotEmpty) {
    throw StateError('Runtime audit and guarded source update plan disagree.');
  }
  for (final entry in findings.entries) {
    if (changes[entry.key] != entry.value) {
      throw StateError(
        'Runtime audit and source plan disagree for ${entry.key}: '
        '${entry.value} vs ${changes[entry.key]}.',
      );
    }
  }
}

String _redactPublicPrices(_CatalogueSource catalogue) {
  var redacted = catalogue.source;
  final definitions = List<_JokerSourceDefinition>.of(
    catalogue.publicDefinitions,
  )..sort((left, right) => right.priceStart.compareTo(left.priceStart));
  for (final definition in definitions) {
    redacted = redacted.replaceRange(
      definition.priceStart,
      definition.priceEnd,
      '<PRICE>',
    );
  }
  return redacted;
}

void _printResult({
  required _Options options,
  required JokerPriceAuditReport report,
  required _PriceUpdatePlan plan,
  required bool applied,
  String? backupPath,
}) {
  if (options.json) {
    stdout.writeln(
      const JsonEncoder.withIndent(' ').convert(<String, Object?>{
        'mode': options.mode.name,
        'catalog': options.catalog,
        'sourceGuardsPassed': true,
        'devX20': 'unchanged',
        'applied': applied,
        'backup': backupPath,
        'plannedChangeCount': plan.changes.length,
        'plannedChanges': plan.changes
            .map((change) => change.toJson())
            .toList(),
        'postApplyPriceBandsPassed': applied,
        'audit': report.toJson(),
      }),
    );
    return;
  }

  _printHumanReport(report);
  stdout.writeln('');
  stdout.writeln('Mode: ${options.mode.name.toUpperCase()}');
  stdout.writeln('Catalogue source: ${options.catalog}');
  stdout.writeln('Guarded public definitions: $_expectedPublicJokerCount');
  stdout.writeln('Planned public price edits: ${plan.changes.length}');
  stdout.writeln('Source-only-price guard: PASS');
  stdout.writeln('DEV ×20: UNCHANGED');
  if (applied) {
    stdout.writeln('Backup: $backupPath');
    stdout.writeln('Post-apply price bands: PASS');
    stdout.writeln('APPLY=PASS');
  } else {
    stdout.writeln(report.passed ? 'CHECK=PASS' : 'CHECK=OUT_OF_BAND');
  }
}

void _printHumanReport(JokerPriceAuditReport report) {
  stdout.writeln('WILDCARD Joker run-shop price audit');
  stdout.writeln(
    'Scope: run-shop prices only. Collection unlock cost and the wider '
    'collection sink are driven separately by rarity, unlock thresholds, '
    'and chest acquisition.',
  );
  stdout.writeln('');
  stdout.writeln(
    'Public catalogue: ${report.publicJokerCount}/'
    '$_expectedPublicJokerCount Jokers',
  );
  stdout.writeln(
    'Starters/free unlocks: ${report.starterCount}/'
    '${report.freeUnlockCount}',
  );
  stdout.writeln('Bands: Common 4-6, Uncommon 5-7, Rare 6-8, Wild 10-12 coins');
  stdout.writeln('');

  if (report.validationErrors.isEmpty) {
    stdout.writeln('Catalogue and starter/free-unlock validation: PASS');
  } else {
    stdout.writeln('Catalogue and starter/free-unlock validation: FAIL');
    for (final error in report.validationErrors) {
      stdout.writeln('  - $error');
    }
  }

  if (report.findings.isEmpty) {
    stdout.writeln('Run-shop price bands: PASS');
  } else {
    stdout.writeln(
      'Run-shop price bands: FAIL (${report.findings.length} out of band)',
    );
    for (final finding in report.findings) {
      stdout.writeln(
        '  - ${finding.id} (${finding.name}, ${finding.rarity.name}): '
        '${finding.actualPrice} -> ${finding.suggestedPrice} '
        '[expected ${finding.expectedBand.minimum}-'
        '${finding.expectedBand.maximum}]',
      );
    }
  }
}

void _printHelp() {
  stdout.writeln('''
Usage:
  dart run tool/joker_shop_price_audit.dart --check [--json]
  dart run tool/joker_shop_price_audit.dart --apply [--json]
  dart run tool/joker_shop_price_audit.dart --self-test

Options:
  --catalog=path      Catalogue source (default: lib/domain/joker_catalog.dart)
  --backup-dir=path   Override build/price-backups for --apply

With no arguments, the tool defaults to the read-only --check mode.
--apply changes only public JokerDefinition price fields to the nearest
rarity-band value. It validates exactly 102 public definitions, verifies
DEV ×20 is untouched, and writes a verified backup before replacing source.
''');
}

void _runSelfTest() {
  _expect(_runShopBands.length == JokerRarity.values.length, 'all rarities');
  for (final rarity in JokerRarity.values) {
    final band = _runShopBands[rarity]!;
    _expect(band.contains(band.minimum), '${rarity.name} lower boundary');
    _expect(band.contains(band.maximum), '${rarity.name} upper boundary');
    _expect(!band.contains(band.minimum - 1), '${rarity.name} below boundary');
    _expect(!band.contains(band.maximum + 1), '${rarity.name} above boundary');
    _expect(
      band.clamp(band.minimum - 20) == band.minimum,
      '${rarity.name} lower clamp',
    );
    _expect(
      band.clamp(band.maximum + 20) == band.maximum,
      '${rarity.name} upper clamp',
    );
  }

  final blocks = <String>[];
  var expectedChanges = 0;
  for (var index = 0; index < _expectedPublicJokerCount; index++) {
    final rarity = JokerRarity.values[index % JokerRarity.values.length];
    final band = _runShopBands[rarity]!;
    final shouldChange = index % 9 == 0;
    final price = shouldChange ? band.minimum - 1 : band.maximum;
    if (shouldChange) expectedChanges++;
    blocks.add('''
  JokerDefinition(
    id: 'joker_$index',
    name: 'Joker $index',
    rarity: JokerRarity.${rarity.name},
    description: 'Self test.',
    price: $price,
    unlock: 10,
    effect: JokerEffect.fake,
  ),''');
  }
  final source =
      '''
class JokerDefinition {}
const List<JokerDefinition> jokerCatalog = <JokerDefinition>[
${blocks.join('\n')}
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
  final catalogue = _CatalogueSource.parse(source);
  final plan = _buildPricePlan(catalogue);
  _expect(
    plan.changes.length == expectedChanges,
    'expected price change count',
  );
  _expect(
    plan.updatedSource.contains("id: 'devx20'") &&
        plan.updatedSource.contains('price: 0'),
    'DEV definition remains intact',
  );
  _expectFailure(
    () => _CatalogueSource.parse(source.replaceFirst(blocks.last, '')),
    'exact public count',
  );
  _expectFailure(
    () => _CatalogueSource.parse(
      source.replaceFirst("id: 'devx20'", "id: 'wrong-dev'"),
    ),
    'DEV identity',
  );

  final temporaryRoot = Directory.systemTemp.createTempSync(
    'wildcard_price_audit_',
  );
  try {
    final testCatalog = File(
      '${temporaryRoot.path}${Platform.pathSeparator}joker_catalog.dart',
    )..writeAsStringSync(source);
    final backupRoot = Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}backups',
    );
    final backup = _applySafely(
      catalogFile: testCatalog,
      original: source,
      updated: plan.updatedSource,
      backupDirectory: backupRoot.path,
    );
    _expect(backup.readAsStringSync() == source, 'verified backup contents');
    _expect(
      testCatalog.readAsStringSync() == plan.updatedSource,
      'verified applied contents',
    );
    _verifyAppliedPlan(
      catalogue,
      _CatalogueSource.parse(testCatalog.readAsStringSync()),
    );
  } finally {
    temporaryRoot.deleteSync(recursive: true);
  }

  final liveFile = File('lib/domain/joker_catalog.dart');
  if (liveFile.existsSync()) {
    final liveCatalogue = _CatalogueSource.parse(liveFile.readAsStringSync());
    _validateSourceMatchesRuntime(liveCatalogue);
    final livePlan = _buildPricePlan(liveCatalogue);
    _requireAuditMatchesPlan(auditJokerRunShopPrices(), livePlan);
  }
}

void _expect(bool condition, String description) {
  if (!condition) throw StateError('Self-test failed: $description');
}

void _expectFailure(void Function() operation, String description) {
  try {
    operation();
  } on Object {
    return;
  }
  throw StateError('Self-test expected failure: $description');
}

List<String> _sortedStrings(Iterable<String> values) => values.toList()..sort();

File _applySafely({
  required File catalogFile,
  required String original,
  required String updated,
  String? backupDirectory,
}) {
  if (catalogFile.readAsStringSync() != original) {
    throw StateError('Catalogue changed after planning; refusing to apply.');
  }
  if (original == updated) {
    throw StateError('Refusing to apply an unchanged catalogue.');
  }
  final backupRoot = backupDirectory == null
      ? Directory(
          '${catalogFile.parent.parent.parent.path}'
          '${Platform.pathSeparator}build'
          '${Platform.pathSeparator}price-backups',
        )
      : Directory(backupDirectory);
  backupRoot.createSync(recursive: true);
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[-:.]'),
    '',
  );
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
    if (definitions.length != _expectedPublicJokerCount ||
        ids.length != _expectedPublicJokerCount ||
        duplicates.isNotEmpty) {
      final sortedDuplicates = duplicates.toList()..sort();
      throw StateError(
        'Expected $_expectedPublicJokerCount unique public JokerDefinition '
        'blocks; found ${definitions.length} blocks / ${ids.length} unique; '
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
    if (devDefinition.id != _devJokerId ||
        devDefinition.rarity != JokerRarity.wild ||
        devDefinition.price != 0) {
      throw StateError(
        'DEV ×20 identity changed: id=${devDefinition.id}, '
        'rarity=${devDefinition.rarity.name}, '
        'price=${devDefinition.price}.',
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
  final priceMatches = RegExp(
    r'^[ \t]*price:[ \t]*(\d+)[ \t]*,[ \t]*$',
    multiLine: true,
  ).allMatches(block).toList();
  if (idMatches.length != 1 ||
      rarityMatches.length != 1 ||
      priceMatches.length != 1) {
    throw StateError(
      'JokerDefinition at source offset $start must contain exactly one '
      'literal id, rarity and price; found ids=${idMatches.length}, '
      'rarities=${rarityMatches.length}, prices=${priceMatches.length}.',
    );
  }
  final id = idMatches.single.group(1)!;
  final rarity = JokerRarity.values.byName(rarityMatches.single.group(1)!);
  final priceMatch = priceMatches.single;
  final priceText = priceMatch.group(1)!;
  final priceOffset = priceMatch.group(0)!.lastIndexOf(priceText);
  if (priceOffset < 0) {
    throw StateError('Unable to locate price for Joker "$id".');
  }
  return _JokerSourceDefinition(
    id: id,
    rarity: rarity,
    price: int.parse(priceText),
    priceStart: start + priceMatch.start + priceOffset,
    priceEnd: start + priceMatch.start + priceOffset + priceText.length,
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

class PriceBand {
  const PriceBand(this.minimum, this.maximum);

  final int minimum;
  final int maximum;

  bool contains(int price) => price >= minimum && price <= maximum;

  int clamp(int price) => price.clamp(minimum, maximum);

  Map<String, int> toJson() => <String, int>{
    'minimum': minimum,
    'maximum': maximum,
  };
}

class JokerPriceFinding {
  const JokerPriceFinding({
    required this.id,
    required this.name,
    required this.rarity,
    required this.actualPrice,
    required this.suggestedPrice,
    required this.expectedBand,
    required this.starter,
    required this.freeUnlock,
  });

  final String id;
  final String name;
  final JokerRarity rarity;
  final int actualPrice;
  final int suggestedPrice;
  final PriceBand expectedBand;
  final bool starter;
  final bool freeUnlock;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'name': name,
    'rarity': rarity.name,
    'actualRunShopPrice': actualPrice,
    'suggestedRunShopPrice': suggestedPrice,
    'expectedBand': expectedBand.toJson(),
    'starter': starter,
    'freeUnlock': freeUnlock,
  };
}

class JokerPriceAuditReport {
  const JokerPriceAuditReport({
    required this.publicJokerCount,
    required this.starterCount,
    required this.freeUnlockCount,
    required this.validationErrors,
    required this.findings,
  });

  final int publicJokerCount;
  final int starterCount;
  final int freeUnlockCount;
  final List<String> validationErrors;
  final List<JokerPriceFinding> findings;

  bool get passed => validationErrors.isEmpty && findings.isEmpty;

  Map<String, Object> toJson() => <String, Object>{
    'schema': 2,
    'scope': 'run-shop prices only',
    'collectionEconomyNote':
        'Collection unlock cost and sink are driven separately by rarity, '
        'unlock thresholds, and chest acquisition.',
    'passed': passed,
    'expectedPublicJokerCount': _expectedPublicJokerCount,
    'publicJokerCount': publicJokerCount,
    'starterCount': starterCount,
    'freeUnlockCount': freeUnlockCount,
    'bands': <String, Object>{
      for (final entry in _runShopBands.entries)
        entry.key.name: entry.value.toJson(),
    },
    'validationErrors': validationErrors,
    'outOfBandCount': findings.length,
    'outOfBand': findings.map((finding) => finding.toJson()).toList(),
  };
}

class _JokerSourceDefinition {
  const _JokerSourceDefinition({
    required this.id,
    required this.rarity,
    required this.price,
    required this.priceStart,
    required this.priceEnd,
    required this.sourceText,
  });

  final String id;
  final JokerRarity rarity;
  final int price;
  final int priceStart;
  final int priceEnd;
  final String sourceText;
}

class _PriceChange {
  const _PriceChange({
    required this.id,
    required this.rarity,
    required this.before,
    required this.after,
  });

  final String id;
  final JokerRarity rarity;
  final int before;
  final int after;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'rarity': rarity.name,
    'before': before,
    'after': after,
  };
}

class _PriceUpdatePlan {
  const _PriceUpdatePlan({required this.updatedSource, required this.changes});

  final String updatedSource;
  final List<_PriceChange> changes;
}

enum _Mode { check, apply }

class _Options {
  const _Options({
    required this.mode,
    required this.catalog,
    required this.backupDirectory,
    required this.json,
    required this.selfTest,
    required this.help,
  });

  factory _Options.parse(List<String> arguments) {
    _Mode? mode;
    var json = false;
    var selfTest = false;
    var help = false;
    final values = <String, String>{};
    for (final argument in arguments) {
      switch (argument) {
        case '--check':
        case '--apply':
          final next = argument == '--check' ? _Mode.check : _Mode.apply;
          if (mode != null) {
            throw const FormatException(
              'Choose at most one of --check or --apply.',
            );
          }
          mode = next;
        case '--json':
          if (json) throw const FormatException('Duplicate --json option.');
          json = true;
        case '--self-test':
          if (selfTest) {
            throw const FormatException('Duplicate --self-test option.');
          }
          selfTest = true;
        case '--help':
        case '-h':
          help = true;
        default:
          if (!argument.startsWith('--') || !argument.contains('=')) {
            throw FormatException('Unknown option "$argument".');
          }
          final separator = argument.indexOf('=');
          final key = argument.substring(2, separator);
          if (values.containsKey(key)) {
            throw FormatException('Duplicate option --$key.');
          }
          values[key] = argument.substring(separator + 1);
      }
    }
    final unknown = values.keys.toSet().difference(const <String>{
      'catalog',
      'backup-dir',
    });
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown option(s): ${unknown.join(', ')}.');
    }
    if (selfTest && (arguments.length != 1 || json || mode != null || help)) {
      throw const FormatException('--self-test cannot be combined.');
    }
    if (help && arguments.length != 1) {
      throw const FormatException('--help cannot be combined.');
    }
    final catalog = values['catalog'] ?? 'lib/domain/joker_catalog.dart';
    if (catalog.isEmpty) {
      throw const FormatException('--catalog cannot be empty.');
    }
    final backupDirectory = values['backup-dir'];
    if (backupDirectory != null && backupDirectory.isEmpty) {
      throw const FormatException('--backup-dir cannot be empty.');
    }
    return _Options(
      mode: mode ?? _Mode.check,
      catalog: catalog,
      backupDirectory: backupDirectory,
      json: json,
      selfTest: selfTest,
      help: help,
    );
  }

  final _Mode mode;
  final String catalog;
  final String? backupDirectory;
  final bool json;
  final bool selfTest;
  final bool help;
}

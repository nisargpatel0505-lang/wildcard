import 'dart:convert';

import '../game_rules.dart';
import '../joker_catalog.dart';
import 'level_definition.dart';

typedef LevelAssetReader = Future<String> Function(String assetPath);

/// The validated authored Level Mode campaign.
class LevelCatalog {
  LevelCatalog._({
    required this.schemaVersion,
    required this.sourceGameVersion,
    required this.sourceCommit,
    required this.sourceBranch,
    required this.balanceBaseline,
    required this.sourceFiles,
    required this.notes,
    required this.levels,
  }) : byId = Map<int, LevelDefinition>.unmodifiable(<int, LevelDefinition>{
         for (final level in levels) level.id: level,
       });

  static const int supportedSchemaVersion = 2;
  static const int requiredLevelCount = 100;
  static const String defaultAssetPath =
      'assets/data/levels-v8.5.2.generated.json';

  final int schemaVersion;
  final String sourceGameVersion;
  final String sourceCommit;
  final String sourceBranch;
  final String balanceBaseline;
  final List<String> sourceFiles;
  final List<String> notes;
  final List<LevelDefinition> levels;
  final Map<int, LevelDefinition> byId;

  int get layoutCount =>
      levels.fold<int>(0, (total, level) => total + level.layouts.length);

  LevelDefinition level(int id) =>
      byId[id] ??
      (throw RangeError.range(id, 1, requiredLevelCount, 'levelId'));

  static Future<LevelCatalog> load(
    LevelAssetReader readAsset, {
    String assetPath = defaultAssetPath,
    Map<String, JokerDefinition>? jokerDefinitions,
  }) async => LevelCatalog.fromJsonString(
    await readAsset(assetPath),
    jokerDefinitions: jokerDefinitions,
  );

  factory LevelCatalog.fromJsonString(
    String source, {
    Map<String, JokerDefinition>? jokerDefinitions,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid Level Mode JSON: ${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('Level Mode catalog root must be an object');
    }
    return LevelCatalog.fromJson(
      Map<String, Object?>.from(decoded),
      jokerDefinitions: jokerDefinitions,
    );
  }

  factory LevelCatalog.fromJson(
    Map<String, Object?> json, {
    Map<String, JokerDefinition>? jokerDefinitions,
  }) {
    _rejectUnknownKeys(json, _rootKeys, r'$');
    final schema = _int(json['schemaVersion'], r'$.schemaVersion');
    if (schema != supportedSchemaVersion) {
      _fail(
        r'$.schemaVersion',
        'unsupported schema $schema; expected $supportedSchemaVersion',
      );
    }
    final rawLevels = _list(json['levels'], r'$.levels');
    final catalog = LevelCatalog._(
      schemaVersion: schema,
      sourceGameVersion: _nonEmptyString(
        json['sourceGameVersion'],
        r'$.sourceGameVersion',
      ),
      sourceCommit: _nonEmptyString(json['sourceCommit'], r'$.sourceCommit'),
      sourceBranch: _nonEmptyString(json['sourceBranch'], r'$.sourceBranch'),
      balanceBaseline: _nonEmptyString(
        json['balanceBaseline'],
        r'$.balanceBaseline',
      ),
      sourceFiles: List<String>.unmodifiable(
        _stringList(json['sourceFiles'], r'$.sourceFiles'),
      ),
      notes: List<String>.unmodifiable(_stringList(json['notes'], r'$.notes')),
      levels: List<LevelDefinition>.unmodifiable(
        rawLevels.indexed.map(
          (entry) => LevelDefinition.fromJson(
            _map(entry.$2, '\$.levels[${entry.$1}]'),
            path: '\$.levels[${entry.$1}]',
          ),
        ),
      ),
    );
    catalog.validate(jokerDefinitions: jokerDefinitions ?? jokersById);
    return catalog;
  }

  /// Revalidates an already parsed catalog. Tests and development tooling can
  /// inject an explicit registry; production defaults to the native catalogue.
  void validate({required Map<String, JokerDefinition> jokerDefinitions}) {
    if (levels.length != requiredLevelCount) {
      _fail(
        r'$.levels',
        'expected exactly $requiredLevelCount levels, found ${levels.length}',
      );
    }
    final ids = levels.map((level) => level.id).toList(growable: false);
    if (ids.toSet().length != ids.length) {
      _fail(r'$.levels', 'level IDs must be unique');
    }
    for (var index = 0; index < levels.length; index++) {
      final level = levels[index];
      final path = '\$.levels[$index]';
      if (level.id != index + 1) {
        _fail(
          '$path.id',
          'levels must be sequential in order; expected ${index + 1}, '
              'found ${level.id}',
        );
      }
      _validateLevel(level, path, jokerDefinitions);
    }
  }
}

void _validateLevel(
  LevelDefinition level,
  String path,
  Map<String, JokerDefinition> jokerDefinitions,
) {
  final rules = level.rules;
  final objective = level.objective;

  if (rules.handSize <= 0 || rules.handSize > 52) {
    _fail('$path.rules.hand_size', 'must be between 1 and 52');
  }
  if (rules.maxSelect <= 0 || rules.maxSelect > rules.handSize) {
    _fail('$path.rules.max_select', 'must be between 1 and hand_size');
  }
  if (rules.hands <= 0) {
    _fail('$path.rules.hands', 'must be positive');
  }
  if (rules.discards < 0) {
    _fail('$path.rules.discards', 'must not be negative');
  }
  if (rules.blockFraction < 0 || rules.blockFraction >= 1) {
    _fail('$path.rules.block_fraction', 'must be in the range [0, 1)');
  }
  if (rules.blockFraction > 0 && rules.usesExplicitBlockedCards) {
    _fail(
      '$path.rules',
      'fractional and explicit card blocking cannot be combined',
    );
  }
  if (rules.expectedDeckSize < rules.handSize) {
    _fail('$path.rules', 'blocked deck is smaller than opening hand');
  }
  if (rules.repeatDecay < 0 || rules.repeatDecay >= 1) {
    _fail('$path.rules.repeat_decay', 'must be in the range [0, 1)');
  }
  if (rules.discardTargetTax < 0) {
    _fail('$path.rules.discard_target_tax', 'must not be negative');
  }
  if (rules.handScoreMultipliers.isNotEmpty &&
      rules.handScoreMultipliers.length != rules.hands) {
    _fail(
      '$path.rules.hand_score_multipliers',
      'must be empty or contain one factor per scoring hand',
    );
  }
  if (rules.handScoreMultipliers.any((value) => value <= 0)) {
    _fail('$path.rules.hand_score_multipliers', 'factors must be positive');
  }
  if (rules.colorRankMultipliers.values.any((value) => value < 0)) {
    _fail('$path.rules.color_rank_multiplier', 'factors must not be negative');
  }
  if (rules.stage <= 0 ||
      rules.heatsCleared < 0 ||
      rules.destroyed < 0 ||
      rules.copied < 0 ||
      rules.runCoins < 0 ||
      rules.modifierCount < 0 ||
      rules.handLevels.values.any((value) => value < 0)) {
    _fail('$path.rules', 'stage/counter fields contain an invalid value');
  }

  if (objective.targetScore < 0) {
    _fail('$path.objective.target_score', 'must not be negative');
  }
  if (!objective.hasConditions) {
    _fail('$path.objective', 'must contain at least one pass condition');
  }
  if (objective.requiredCounts.values.any((count) => count <= 0)) {
    _fail('$path.objective.required_counts', 'counts must be positive');
  }
  final totalRequired = objective.requiredCounts.values.fold<int>(
    0,
    (sum, count) => sum + count,
  );
  if (totalRequired > rules.hands) {
    _fail('$path.objective.required_counts', 'needs more hands than available');
  }
  if (objective.requiredSequence.length > rules.hands) {
    _fail(
      '$path.objective.required_sequence',
      'is longer than available hands',
    );
  }
  if (objective.minVariety < 0 ||
      objective.minVariety > HandType.values.length ||
      objective.minVariety > rules.hands) {
    _fail('$path.objective.min_variety', 'cannot be met with available hands');
  }
  if (objective.minQualityCount < 0 ||
      objective.minQualityCount > rules.hands) {
    _fail(
      '$path.objective.min_quality_count',
      'cannot be met with available hands',
    );
  }
  if (objective.minTypesFromCount < 0 ||
      objective.minTypesFromCount > objective.minTypesFrom.length ||
      objective.minTypesFromCount > rules.hands) {
    _fail(
      '$path.objective.min_types_from_count',
      'cannot be met by min_types_from',
    );
  }
  if (objective.checkpoints.length > rules.hands ||
      objective.checkpoints.any((score) => score <= 0)) {
    _fail('$path.objective.checkpoints', 'contains an invalid checkpoint');
  }
  for (var index = 1; index < objective.checkpoints.length; index++) {
    if (objective.checkpoints[index] <= objective.checkpoints[index - 1]) {
      _fail('$path.objective.checkpoints', 'must be strictly increasing');
    }
  }

  if (level.targetSuccess < 0 || level.targetSuccess > 1) {
    _fail('$path.targetSuccess', 'must be in the range [0, 1]');
  }
  if (level.layoutCount <= 0 || level.layoutCount != level.layouts.length) {
    _fail(
      '$path.layoutCount',
      'declares ${level.layoutCount}, but ${level.layouts.length} layouts exist',
    );
  }

  final jokerGroups = <Iterable<String>>[
    level.fixedJokerIds,
    level.jokerOptionIds,
    if (level.negativeJokerId != null) <String>[level.negativeJokerId!],
  ];
  final availableJokers = jokerGroups.expand((group) => group).toList();
  _requireUnique(availableJokers, '$path Joker lists');
  for (final jokerId in availableJokers) {
    _requireJoker(jokerId, path, jokerDefinitions);
  }
  if (level.chooseJokers < 0 ||
      level.chooseJokers > level.jokerOptionIds.length) {
    _fail('$path.chooseJokers', 'is not valid for the offered Joker list');
  }
  if ((level.jokerOptionIds.isEmpty) != (level.chooseJokers == 0)) {
    _fail(
      '$path.chooseJokers',
      'must be positive exactly when Joker options are present',
    );
  }
  if (level.temporaryJokerCount > 5) {
    _fail(path, 'temporary loadout exceeds the five-Joker slot limit');
  }

  final layoutIds = <String>[];
  for (var index = 0; index < level.layouts.length; index++) {
    final layout = level.layouts[index];
    final layoutPath = '$path.layouts[$index]';
    layoutIds.add(layout.id);
    if (layout.seed < 0) _fail('$layoutPath.seed', 'must not be negative');
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(layout.hash)) {
      _fail('$layoutPath.hash', 'must be a 16-character lowercase hex hash');
    }
    if (layout.deckCodes.length != rules.expectedDeckSize) {
      _fail(
        '$layoutPath.deckOrder',
        'blocked deck has ${layout.deckCodes.length} cards; expected '
            '${rules.expectedDeckSize}',
      );
    }
    if (layout.deckCodes.length < rules.handSize) {
      _fail('$layoutPath.deckOrder', 'deck is smaller than opening hand');
    }
    final cards = <String>[];
    for (var cardIndex = 0; cardIndex < layout.deckCodes.length; cardIndex++) {
      final code = layout.deckCodes[cardIndex];
      try {
        final card = LevelCardCodec.decode(code);
        cards.add(LevelCardCodec.encode(card));
        if (rules.blockedRanks.contains(card.rank)) {
          _fail('$layoutPath.deckOrder[$cardIndex]', 'uses a blocked rank');
        }
        if (rules.blockedSuits.contains(card.suit)) {
          _fail('$layoutPath.deckOrder[$cardIndex]', 'uses a blocked suit');
        }
      } on FormatException catch (error) {
        _fail('$layoutPath.deckOrder[$cardIndex]', error.message);
      }
    }
    _requireUnique(cards, '$layoutPath.deckOrder');
    _validateRecommendation(
      level,
      layout.recommendedJokerIds,
      '$layoutPath.recommendedJokers',
      jokerDefinitions,
    );
  }
  _requireUnique(layoutIds, '$path.layouts.id');

  if (level.recommendedLoadouts.isEmpty) {
    _fail('$path.recommendedLoadouts', 'must not be empty');
  }
  var representedLayouts = 0;
  for (var index = 0; index < level.recommendedLoadouts.length; index++) {
    final loadout = level.recommendedLoadouts[index];
    final loadoutPath = '$path.recommendedLoadouts[$index]';
    if (loadout.jokerIds.length != loadout.jokerNames.length) {
      _fail(loadoutPath, 'Joker ID and name counts differ');
    }
    _validateRecommendation(
      level,
      loadout.jokerIds,
      '$loadoutPath.jokerIds',
      jokerDefinitions,
    );
    for (
      var jokerIndex = 0;
      jokerIndex < loadout.jokerIds.length;
      jokerIndex++
    ) {
      final definition = jokerDefinitions[loadout.jokerIds[jokerIndex]]!;
      if (loadout.jokerNames[jokerIndex] != definition.name) {
        _fail(
          '$loadoutPath.jokerNames[$jokerIndex]',
          'does not match native Joker ${definition.name}',
        );
      }
    }
    if (loadout.layoutCount <= 0) {
      _fail('$loadoutPath.layoutCount', 'must be positive');
    }
    representedLayouts += loadout.layoutCount;
  }
  if (representedLayouts != level.layoutCount) {
    _fail(
      '$path.recommendedLoadouts',
      'represents $representedLayouts layouts; expected ${level.layoutCount}',
    );
  }
}

void _validateRecommendation(
  LevelDefinition level,
  List<String> jokerIds,
  String path,
  Map<String, JokerDefinition> jokerDefinitions,
) {
  _requireUnique(jokerIds, path);
  if (jokerIds.length != level.temporaryJokerCount) {
    _fail(
      path,
      'contains ${jokerIds.length} Jokers; expected ${level.temporaryJokerCount}',
    );
  }
  for (final jokerId in jokerIds) {
    _requireJoker(jokerId, path, jokerDefinitions);
    final available =
        level.fixedJokerIds.contains(jokerId) ||
        level.jokerOptionIds.contains(jokerId) ||
        level.negativeJokerId == jokerId;
    if (!available) {
      _fail(path, 'Joker $jokerId is not available in this level');
    }
  }
  if (!level.fixedJokerIds.every(jokerIds.contains)) {
    _fail(path, 'omits a fixed Joker');
  }
  if (level.negativeJokerId != null &&
      !jokerIds.contains(level.negativeJokerId)) {
    _fail(path, 'omits the required negative Joker');
  }
  final selectedCount = jokerIds.where(level.jokerOptionIds.contains).length;
  if (selectedCount != level.chooseJokers) {
    _fail(path, 'does not select exactly ${level.chooseJokers} offered Jokers');
  }
}

void _requireJoker(
  String jokerId,
  String path,
  Map<String, JokerDefinition> jokerDefinitions,
) {
  if (!jokerDefinitions.containsKey(jokerId)) {
    _fail(path, 'references missing native Joker ID $jokerId');
  }
}

void _requireUnique(Iterable<String> values, String path) {
  final list = values.toList(growable: false);
  if (list.toSet().length != list.length) _fail(path, 'contains duplicates');
}

const Set<String> _rootKeys = <String>{
  'schemaVersion',
  'sourceGameVersion',
  'sourceCommit',
  'sourceBranch',
  'balanceBaseline',
  'sourceFiles',
  'notes',
  'levels',
};

Never _fail(String path, String reason) =>
    throw FormatException('Invalid Level Mode catalog at $path: $reason');

void _rejectUnknownKeys(
  Map<String, Object?> json,
  Set<String> allowed,
  String path,
) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) _fail(path, 'unknown fields: ${unknown.join(', ')}');
}

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) _fail(path, 'expected an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) _fail(path, 'object keys must be strings');
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) _fail(path, 'expected an array');
  return List<Object?>.from(value);
}

String _nonEmptyString(Object? value, String path) {
  if (value is! String) _fail(path, 'expected a string');
  if (value.trim().isEmpty) _fail(path, 'must not be empty');
  return value;
}

int _int(Object? value, String path) {
  if (value is! int) _fail(path, 'expected an integer');
  return value;
}

List<String> _stringList(Object? value, String path) => _list(value, path)
    .indexed
    .map((entry) {
      return _nonEmptyString(entry.$2, '$path[${entry.$1}]');
    })
    .toList(growable: false);

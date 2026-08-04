import '../cards.dart';
import '../game_rules.dart';

/// A colour selector used by Level Mode rank-scoring rules.
enum LevelCardColor { red, black }

/// Converts the compact authored card format (for example `AS` or `10D`)
/// into the native card model used by the scoring engine.
abstract final class LevelCardCodec {
  static final RegExp _cardPattern = RegExp(r'^(10|[2-9JQKA])([SHCD])$');

  static PlayingCard decode(String code) {
    final match = _cardPattern.firstMatch(code);
    if (match == null) {
      throw FormatException('Invalid Level Mode card code: $code');
    }
    return PlayingCard(
      rank: CardRank.fromLabel(match.group(1)!),
      suit: switch (match.group(2)!) {
        'S' => CardSuit.spades,
        'H' => CardSuit.hearts,
        'C' => CardSuit.clubs,
        'D' => CardSuit.diamonds,
        final value => throw FormatException('Invalid card suit: $value'),
      },
    );
  }

  static String encode(PlayingCard card) =>
      '${card.rank.label}${suitCode(card.suit)}';

  static String suitCode(CardSuit suit) => switch (suit) {
    CardSuit.spades => 'S',
    CardSuit.hearts => 'H',
    CardSuit.clubs => 'C',
    CardSuit.diamonds => 'D',
  };
}

/// Immutable, level-only rule data. None of these fields changes Arcade rules.
class LevelRules {
  const LevelRules({
    required this.handSize,
    required this.maxSelect,
    required this.hands,
    required this.discards,
    required this.blockFraction,
    required this.blockedRanks,
    required this.blockedSuits,
    required this.highCardZero,
    required this.allowedHandTypes,
    required this.faceRankZero,
    required this.scoreColor,
    required this.colorRankMultipliers,
    required this.repeatDecay,
    required this.noRepeat,
    required this.discardTargetTax,
    required this.handScoreMultipliers,
    required this.disabledSuitRotation,
    required this.burnPlayedCards,
    required this.burnScoringCards,
    required this.burnPlayedRanks,
    required this.shrinkingDiscards,
    required this.jokerBlackout,
    required this.fadingJokers,
    required this.rotatingJoker,
    required this.stage,
    required this.heatsCleared,
    required this.destroyed,
    required this.copied,
    required this.runCoins,
    required this.handLevels,
    required this.hasModifier,
    required this.modifierCount,
    required this.nullField,
    required this.deadAir,
    required this.bossModifier,
  });

  final int handSize;
  final int maxSelect;
  final int hands;
  final int discards;
  final double blockFraction;
  final Set<CardRank> blockedRanks;
  final Set<CardSuit> blockedSuits;
  final bool highCardZero;
  final Set<HandType> allowedHandTypes;
  final bool faceRankZero;
  final LevelCardColor? scoreColor;
  final Map<LevelCardColor, double> colorRankMultipliers;
  final double repeatDecay;
  final bool noRepeat;
  final int discardTargetTax;
  final List<double> handScoreMultipliers;
  final List<CardSuit> disabledSuitRotation;
  final bool burnPlayedCards;
  final bool burnScoringCards;
  final bool burnPlayedRanks;
  final bool shrinkingDiscards;
  final bool jokerBlackout;
  final bool fadingJokers;
  final bool rotatingJoker;
  final int stage;
  final int heatsCleared;
  final int destroyed;
  final int copied;
  final int runCoins;
  final Map<HandType, int> handLevels;
  final bool hasModifier;
  final int modifierCount;
  final bool nullField;
  final bool deadAir;
  final bool bossModifier;

  bool get usesExplicitBlockedCards =>
      blockedRanks.isNotEmpty || blockedSuits.isNotEmpty;

  bool get usesPrevalidatedPartialDeck =>
      blockFraction > 0 || usesExplicitBlockedCards;

  /// Expected authored layout size after deterministic blocking rules.
  int get expectedDeckSize {
    if (blockFraction > 0) {
      return (baseCardSet().length * (1 - blockFraction)).round();
    }
    return baseCardSet()
        .where(
          (card) =>
              !blockedRanks.contains(card.rank) &&
              !blockedSuits.contains(card.suit),
        )
        .length;
  }

  factory LevelRules.fromJson(
    Map<String, Object?> json, {
    String path = r'$.rules',
  }) {
    _rejectUnknownKeys(json, _ruleKeys, path);
    final blockedRanks = _rankSet(json['blocked_ranks'], '$path.blocked_ranks');
    final blockedSuits = _suitSet(json['blocked_suits'], '$path.blocked_suits');
    final allowed = _handTypeSet(
      json['allowed_hand_types'],
      '$path.allowed_hand_types',
    );
    final disabledRotation = _suitList(
      json['disabled_suit_rotation'],
      '$path.disabled_suit_rotation',
    );
    if (disabledRotation.toSet().length != disabledRotation.length) {
      _fail('$path.disabled_suit_rotation', 'contains duplicate suits');
    }

    final scoreColorRaw = json['score_color'];
    final scoreColor = scoreColorRaw == null
        ? null
        : _cardColor(scoreColorRaw, '$path.score_color');
    final colorMultipliers = <LevelCardColor, double>{};
    final rawColorMultipliers = _map(
      json['color_rank_multiplier'],
      '$path.color_rank_multiplier',
    );
    for (final entry in rawColorMultipliers.entries) {
      colorMultipliers[_cardColor(entry.key, '$path.color_rank_multiplier')] =
          _double(entry.value, '$path.color_rank_multiplier.${entry.key}');
    }

    final handLevels = <HandType, int>{};
    final rawHandLevels = _map(json['hand_levels'], '$path.hand_levels');
    for (final entry in rawHandLevels.entries) {
      handLevels[_handType(entry.key, '$path.hand_levels')] = _int(
        entry.value,
        '$path.hand_levels.${entry.key}',
      );
    }

    return LevelRules(
      handSize: _int(json['hand_size'], '$path.hand_size'),
      maxSelect: _int(json['max_select'], '$path.max_select'),
      hands: _int(json['hands'], '$path.hands'),
      discards: _int(json['discards'], '$path.discards'),
      blockFraction: _double(json['block_fraction'], '$path.block_fraction'),
      blockedRanks: Set<CardRank>.unmodifiable(blockedRanks),
      blockedSuits: Set<CardSuit>.unmodifiable(blockedSuits),
      highCardZero: _bool(json['high_card_zero'], '$path.high_card_zero'),
      allowedHandTypes: Set<HandType>.unmodifiable(allowed),
      faceRankZero: _bool(json['face_rank_zero'], '$path.face_rank_zero'),
      scoreColor: scoreColor,
      colorRankMultipliers: Map<LevelCardColor, double>.unmodifiable(
        colorMultipliers,
      ),
      repeatDecay: _double(json['repeat_decay'], '$path.repeat_decay'),
      noRepeat: _bool(json['no_repeat'], '$path.no_repeat'),
      discardTargetTax: _int(
        json['discard_target_tax'],
        '$path.discard_target_tax',
      ),
      handScoreMultipliers: List<double>.unmodifiable(
        _list(
          json['hand_score_multipliers'],
          '$path.hand_score_multipliers',
        ).indexed.map(
          (entry) =>
              _double(entry.$2, '$path.hand_score_multipliers[${entry.$1}]'),
        ),
      ),
      disabledSuitRotation: List<CardSuit>.unmodifiable(disabledRotation),
      burnPlayedCards: _bool(
        json['burn_played_cards'],
        '$path.burn_played_cards',
      ),
      burnScoringCards: _bool(
        json['burn_scoring_cards'],
        '$path.burn_scoring_cards',
      ),
      burnPlayedRanks: json.containsKey('burn_played_ranks')
          ? _bool(json['burn_played_ranks'], '$path.burn_played_ranks')
          : false,
      shrinkingDiscards: _bool(
        json['shrinking_discards'],
        '$path.shrinking_discards',
      ),
      jokerBlackout: _bool(json['joker_blackout'], '$path.joker_blackout'),
      fadingJokers: _bool(json['fading_jokers'], '$path.fading_jokers'),
      rotatingJoker: _bool(json['rotating_joker'], '$path.rotating_joker'),
      stage: _int(json['stage'], '$path.stage'),
      heatsCleared: _int(json['heats_cleared'], '$path.heats_cleared'),
      destroyed: _int(json['destroyed'], '$path.destroyed'),
      copied: _int(json['copied'], '$path.copied'),
      runCoins: _int(json['run_coins'], '$path.run_coins'),
      handLevels: Map<HandType, int>.unmodifiable(handLevels),
      hasModifier: _bool(json['has_modifier'], '$path.has_modifier'),
      modifierCount: _int(json['modifier_count'], '$path.modifier_count'),
      nullField: _bool(json['null_field'], '$path.null_field'),
      deadAir: _bool(json['dead_air'], '$path.dead_air'),
      bossModifier: _bool(json['boss_modifier'], '$path.boss_modifier'),
    );
  }
}

/// The authored pass conditions for a single level table.
class LevelObjective {
  const LevelObjective({
    required this.targetScore,
    required this.requiredCounts,
    required this.requiredSequence,
    required this.minVariety,
    required this.forbiddenTypes,
    required this.minQualityCount,
    required this.minQuality,
    required this.minTypesFrom,
    required this.minTypesFromCount,
    required this.checkpoints,
  });

  final int targetScore;
  final Map<HandType, int> requiredCounts;
  final List<HandType> requiredSequence;
  final int minVariety;
  final Set<HandType> forbiddenTypes;
  final int minQualityCount;
  final HandType minQuality;
  final Set<HandType> minTypesFrom;
  final int minTypesFromCount;
  final List<int> checkpoints;

  bool get hasScoreTarget => targetScore > 0;

  bool get hasConditions =>
      hasScoreTarget ||
      requiredCounts.isNotEmpty ||
      requiredSequence.isNotEmpty ||
      minVariety > 0 ||
      forbiddenTypes.isNotEmpty ||
      minQualityCount > 0 ||
      minTypesFromCount > 0 ||
      checkpoints.isNotEmpty;

  factory LevelObjective.fromJson(
    Map<String, Object?> json, {
    String path = r'$.objective',
  }) {
    _rejectUnknownKeys(json, _objectiveKeys, path);
    final requiredCounts = <HandType, int>{};
    final rawCounts = _map(json['required_counts'], '$path.required_counts');
    for (final entry in rawCounts.entries) {
      requiredCounts[_handType(entry.key, '$path.required_counts')] = _int(
        entry.value,
        '$path.required_counts.${entry.key}',
      );
    }
    return LevelObjective(
      targetScore: _int(json['target_score'], '$path.target_score'),
      requiredCounts: Map<HandType, int>.unmodifiable(requiredCounts),
      requiredSequence: List<HandType>.unmodifiable(
        _handTypeList(json['required_sequence'], '$path.required_sequence'),
      ),
      minVariety: _int(json['min_variety'], '$path.min_variety'),
      forbiddenTypes: Set<HandType>.unmodifiable(
        _handTypeSet(json['forbidden_types'], '$path.forbidden_types'),
      ),
      minQualityCount: _int(
        json['min_quality_count'],
        '$path.min_quality_count',
      ),
      minQuality: _handType(json['min_quality'], '$path.min_quality'),
      minTypesFrom: Set<HandType>.unmodifiable(
        _handTypeSet(json['min_types_from'], '$path.min_types_from'),
      ),
      minTypesFromCount: _int(
        json['min_types_from_count'],
        '$path.min_types_from_count',
      ),
      checkpoints: List<int>.unmodifiable(
        _list(json['checkpoints'], '$path.checkpoints').indexed.map(
          (entry) => _int(entry.$2, '$path.checkpoints[${entry.$1}]'),
        ),
      ),
    );
  }
}

class LevelLayout {
  const LevelLayout({
    required this.id,
    required this.seed,
    required this.hash,
    required this.deckCodes,
    required this.recommendedJokerIds,
  });

  final String id;
  final int seed;
  final String hash;
  final List<String> deckCodes;
  final List<String> recommendedJokerIds;

  List<PlayingCard> get deckOrder =>
      List<PlayingCard>.unmodifiable(deckCodes.map(LevelCardCodec.decode));

  factory LevelLayout.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    _rejectUnknownKeys(json, _layoutKeys, path);
    return LevelLayout(
      id: _nonEmptyString(json['id'], '$path.id'),
      seed: _int(json['seed'], '$path.seed'),
      hash: _nonEmptyString(json['hash'], '$path.hash'),
      deckCodes: List<String>.unmodifiable(
        _list(json['deckOrder'], '$path.deckOrder').indexed.map(
          (entry) => _string(entry.$2, '$path.deckOrder[${entry.$1}]'),
        ),
      ),
      recommendedJokerIds: List<String>.unmodifiable(
        _list(json['recommendedJokers'], '$path.recommendedJokers').indexed.map(
          (entry) =>
              _nonEmptyString(entry.$2, '$path.recommendedJokers[${entry.$1}]'),
        ),
      ),
    );
  }
}

class LevelRecommendedLoadout {
  const LevelRecommendedLoadout({
    required this.jokerIds,
    required this.jokerNames,
    required this.layoutCount,
  });

  final List<String> jokerIds;
  final List<String> jokerNames;
  final int layoutCount;

  factory LevelRecommendedLoadout.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    _rejectUnknownKeys(json, _recommendedLoadoutKeys, path);
    return LevelRecommendedLoadout(
      jokerIds: List<String>.unmodifiable(
        _list(json['jokerIds'], '$path.jokerIds').indexed.map(
          (entry) => _nonEmptyString(entry.$2, '$path.jokerIds[${entry.$1}]'),
        ),
      ),
      jokerNames: List<String>.unmodifiable(
        _list(json['jokerNames'], '$path.jokerNames').indexed.map(
          (entry) => _nonEmptyString(entry.$2, '$path.jokerNames[${entry.$1}]'),
        ),
      ),
      layoutCount: _int(json['layoutCount'], '$path.layoutCount'),
    );
  }
}

class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.name,
    required this.chapter,
    required this.description,
    required this.rules,
    required this.objective,
    required this.fixedJokerIds,
    required this.jokerOptionIds,
    required this.chooseJokers,
    required this.negativeJokerId,
    required this.layoutCount,
    required this.curated,
    required this.targetSuccess,
    required this.hint,
    required this.visibleModifiers,
    required this.layouts,
    required this.recommendedLoadouts,
  });

  final int id;
  final String name;
  final String chapter;
  final String description;
  final LevelRules rules;
  final LevelObjective objective;
  final List<String> fixedJokerIds;
  final List<String> jokerOptionIds;
  final int chooseJokers;
  final String? negativeJokerId;
  final int layoutCount;
  final bool curated;
  final double targetSuccess;
  final String hint;
  final List<String> visibleModifiers;
  final List<LevelLayout> layouts;
  final List<LevelRecommendedLoadout> recommendedLoadouts;

  bool get requiresJokerSelection => chooseJokers > 0;

  int get temporaryJokerCount =>
      fixedJokerIds.length + chooseJokers + (negativeJokerId == null ? 0 : 1);

  LevelLayout layoutById(String layoutId) => layouts.firstWhere(
    (layout) => layout.id == layoutId,
    orElse: () => throw StateError('Level $id has no layout $layoutId'),
  );

  /// Validates a player choice without consulting account ownership: campaign
  /// Jokers are deliberately temporary and available to every player.
  void validateJokerSelection(Iterable<String> selectedIds) {
    final selected = selectedIds.toList(growable: false);
    if (selected.length != chooseJokers) {
      throw ArgumentError.value(
        selected,
        'selectedIds',
        'Level $id requires exactly $chooseJokers Joker choices',
      );
    }
    if (selected.toSet().length != selected.length) {
      throw ArgumentError.value(
        selected,
        'selectedIds',
        'Joker choices must be unique',
      );
    }
    final invalid = selected.where((joker) => !jokerOptionIds.contains(joker));
    if (invalid.isNotEmpty) {
      throw ArgumentError.value(
        invalid.toList(),
        'selectedIds',
        'Jokers are not offered by Level $id',
      );
    }
  }

  List<String> temporaryJokerIds(Iterable<String> selectedIds) {
    validateJokerSelection(selectedIds);
    return List<String>.unmodifiable(<String>[
      ...fixedJokerIds,
      ...selectedIds,
      ?negativeJokerId,
    ]);
  }

  /// Cards absent from a prevalidated layout, in canonical deck order.
  List<PlayingCard> blockedCardsFor(LevelLayout layout) {
    if (!layouts.any((candidate) => candidate.id == layout.id)) {
      throw ArgumentError.value(
        layout.id,
        'layout',
        'Layout does not belong to Level $id',
      );
    }
    final present = layout.deckCodes.toSet();
    return List<PlayingCard>.unmodifiable(
      baseCardSet().where(
        (card) => !present.contains(LevelCardCodec.encode(card)),
      ),
    );
  }

  factory LevelDefinition.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    _rejectUnknownKeys(json, _levelKeys, path);
    final layoutsRaw = _list(json['layouts'], '$path.layouts');
    final loadoutsRaw = _list(
      json['recommendedLoadouts'],
      '$path.recommendedLoadouts',
    );
    return LevelDefinition(
      id: _int(json['id'], '$path.id'),
      name: _nonEmptyString(json['name'], '$path.name'),
      chapter: _nonEmptyString(json['chapter'], '$path.chapter'),
      description: _nonEmptyString(json['description'], '$path.description'),
      rules: LevelRules.fromJson(
        _map(json['rules'], '$path.rules'),
        path: '$path.rules',
      ),
      objective: LevelObjective.fromJson(
        _map(json['objective'], '$path.objective'),
        path: '$path.objective',
      ),
      fixedJokerIds: List<String>.unmodifiable(
        _stringList(json['fixedJokers'], '$path.fixedJokers'),
      ),
      jokerOptionIds: List<String>.unmodifiable(
        _stringList(json['jokerOptions'], '$path.jokerOptions'),
      ),
      chooseJokers: _int(json['chooseJokers'], '$path.chooseJokers'),
      negativeJokerId: json['negativeJoker'] == null
          ? null
          : _nonEmptyString(json['negativeJoker'], '$path.negativeJoker'),
      layoutCount: _int(json['layoutCount'], '$path.layoutCount'),
      curated: _bool(json['curated'], '$path.curated'),
      targetSuccess: _double(json['targetSuccess'], '$path.targetSuccess'),
      hint: _nonEmptyString(json['hint'], '$path.hint'),
      visibleModifiers: List<String>.unmodifiable(
        _stringList(json['visibleModifiers'], '$path.visibleModifiers'),
      ),
      layouts: List<LevelLayout>.unmodifiable(
        layoutsRaw.indexed.map(
          (entry) => LevelLayout.fromJson(
            _map(entry.$2, '$path.layouts[${entry.$1}]'),
            path: '$path.layouts[${entry.$1}]',
          ),
        ),
      ),
      recommendedLoadouts: List<LevelRecommendedLoadout>.unmodifiable(
        loadoutsRaw.indexed.map(
          (entry) => LevelRecommendedLoadout.fromJson(
            _map(entry.$2, '$path.recommendedLoadouts[${entry.$1}]'),
            path: '$path.recommendedLoadouts[${entry.$1}]',
          ),
        ),
      ),
    );
  }
}

const Set<String> _levelKeys = <String>{
  'id',
  'name',
  'chapter',
  'description',
  'rules',
  'objective',
  'fixedJokers',
  'jokerOptions',
  'chooseJokers',
  'negativeJoker',
  'layoutCount',
  'curated',
  'targetSuccess',
  'hint',
  'visibleModifiers',
  'layouts',
  'recommendedLoadouts',
};

const Set<String> _ruleKeys = <String>{
  'hand_size',
  'max_select',
  'hands',
  'discards',
  'block_fraction',
  'blocked_ranks',
  'blocked_suits',
  'high_card_zero',
  'allowed_hand_types',
  'face_rank_zero',
  'score_color',
  'color_rank_multiplier',
  'repeat_decay',
  'no_repeat',
  'discard_target_tax',
  'hand_score_multipliers',
  'disabled_suit_rotation',
  'burn_played_cards',
  'burn_scoring_cards',
  'burn_played_ranks',
  'shrinking_discards',
  'joker_blackout',
  'fading_jokers',
  'rotating_joker',
  'stage',
  'heats_cleared',
  'destroyed',
  'copied',
  'run_coins',
  'hand_levels',
  'has_modifier',
  'modifier_count',
  'null_field',
  'dead_air',
  'boss_modifier',
};

const Set<String> _objectiveKeys = <String>{
  'target_score',
  'required_counts',
  'required_sequence',
  'min_variety',
  'forbidden_types',
  'min_quality_count',
  'min_quality',
  'min_types_from',
  'min_types_from_count',
  'checkpoints',
};

const Set<String> _layoutKeys = <String>{
  'id',
  'seed',
  'hash',
  'deckOrder',
  'recommendedJokers',
};

const Set<String> _recommendedLoadoutKeys = <String>{
  'jokerIds',
  'jokerNames',
  'layoutCount',
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

String _string(Object? value, String path) {
  if (value is! String) _fail(path, 'expected a string');
  return value;
}

String _nonEmptyString(Object? value, String path) {
  final result = _string(value, path);
  if (result.trim().isEmpty) _fail(path, 'must not be empty');
  return result;
}

int _int(Object? value, String path) {
  if (value is! int) _fail(path, 'expected an integer');
  return value;
}

double _double(Object? value, String path) {
  if (value is! num) _fail(path, 'expected a number');
  final result = value.toDouble();
  if (!result.isFinite) _fail(path, 'must be finite');
  return result;
}

bool _bool(Object? value, String path) {
  if (value is! bool) _fail(path, 'expected a boolean');
  return value;
}

List<String> _stringList(Object? value, String path) => _list(value, path)
    .indexed
    .map((entry) {
      return _nonEmptyString(entry.$2, '$path[${entry.$1}]');
    })
    .toList(growable: false);

HandType _handType(Object? value, String path) {
  final name = _nonEmptyString(value, path);
  try {
    return HandType.fromLegacy(name);
  } on FormatException {
    _fail(path, 'unknown hand type: $name');
  }
}

List<HandType> _handTypeList(Object? value, String path) => _list(value, path)
    .indexed
    .map((entry) {
      return _handType(entry.$2, '$path[${entry.$1}]');
    })
    .toList(growable: false);

Set<HandType> _handTypeSet(Object? value, String path) {
  final values = _handTypeList(value, path);
  if (values.toSet().length != values.length) {
    _fail(path, 'contains duplicate hand types');
  }
  return values.toSet();
}

Set<CardRank> _rankSet(Object? value, String path) {
  final raw = _stringList(value, path);
  final ranks = <CardRank>[];
  for (var i = 0; i < raw.length; i++) {
    try {
      ranks.add(CardRank.fromLabel(raw[i]));
    } on FormatException {
      _fail('$path[$i]', 'unknown rank: ${raw[i]}');
    }
  }
  if (ranks.toSet().length != ranks.length) _fail(path, 'contains duplicates');
  return ranks.toSet();
}

List<CardSuit> _suitList(Object? value, String path) {
  final raw = _stringList(value, path);
  return raw.indexed
      .map((entry) {
        try {
          return LevelCardCodec.decode('2${entry.$2}').suit;
        } on FormatException {
          _fail('$path[${entry.$1}]', 'unknown suit: ${entry.$2}');
        }
      })
      .toList(growable: false);
}

Set<CardSuit> _suitSet(Object? value, String path) {
  final suits = _suitList(value, path);
  if (suits.toSet().length != suits.length) _fail(path, 'contains duplicates');
  return suits.toSet();
}

LevelCardColor _cardColor(Object? value, String path) {
  final name = _nonEmptyString(value, path);
  return switch (name) {
    'red' => LevelCardColor.red,
    'black' => LevelCardColor.black,
    _ => _fail(path, 'unknown card colour: $name'),
  };
}

import 'dart:math' as math;

import 'cards.dart';
import 'random_streams.dart';

enum HandType {
  highCard('High Card'),
  pair('Pair'),
  twoPair('Two Pair'),
  threeOfAKind('Three of a Kind'),
  straight('Straight'),
  flush('Flush'),
  fullHouse('Full House'),
  fourOfAKind('Four of a Kind'),
  straightFlush('Straight Flush'),
  royalFlush('Royal Flush');

  const HandType(this.legacyName);

  final String legacyName;

  static HandType fromLegacy(String value) => HandType.values.firstWhere(
    (type) => type.legacyName == value,
    orElse: () => throw FormatException('Unknown hand type: $value'),
  );
}

/// Heat rules shipped in the recovered v7.1.0 (versionCode 45) phone APK.
enum HeatModifier {
  cold('cold', 'Cold Deck', 'One fewer discard this Heat.', minHeat: 3),
  heartless(
    'heartless',
    'Heartless',
    'Hearts score 0 rank this Heat.',
    minHeat: 3,
  ),
  inflation(
    'inflation',
    'Inflation',
    'Shop prices +2 after this Heat.',
    minHeat: 3,
  ),
  shortStack(
    'short',
    'Short Stack',
    'Hold 8 cards instead of 9 this Heat.',
    minHeat: 3,
  ),
  tax('tax', 'The Tax', 'Target +15% this Heat.', minHeat: 3),
  lowCeiling(
    'ceiling',
    'Low Ceiling',
    'Play at most 4 cards; 4-card straights and flushes count.',
    minHeat: 6,
  ),
  highStakes('rich', 'High Stakes', 'Target +25% this Heat.', minHeat: 6),
  deadAir('fog', 'Dead Air', 'Jokers give no xMult this Heat.', minHeat: 6),
  famine(
    'famine',
    'Famine',
    'Hold 7 cards instead of 9 this Heat.',
    minHeat: 9,
  ),
  frostbite(
    'frostbite',
    'Frostbite',
    'Spades score 0 rank this Heat.',
    minHeat: 9,
  ),
  nullField(
    'blackout',
    'Null Field',
    'All +Mult and xMult effects are disabled, including Neon and Glass.',
    minHeat: 13,
    isHard: true,
  ),
  echoChamber(
    'echo',
    'Echo Chamber',
    'Repeating the previous hand type halves final Mult.',
    minHeat: 15,
    isHard: true,
  ),
  levelLock(
    'boost_lock',
    'Level Lock',
    'Hand Boost levels are disabled this Heat.',
    minHeat: 18,
    isHard: true,
  ),
  closingTime(
    'pressure',
    'Closing Time',
    'One fewer hand this Heat.',
    minHeat: 21,
    isHard: true,
  ),
  counterfeit(
    'counterfeit',
    'Counterfeit',
    'Copied cards score 0 rank this Heat.',
    minHeat: 24,
    isHard: true,
  ),
  thinIce(
    'thin_ice',
    'Thin Ice',
    'A deck below 30 cards raises the target by 40%.',
    minHeat: 27,
    isHard: true,
  ),
  theHouse(
    'boss_house',
    'THE HOUSE',
    'Target +10% and two equipped Jokers are blocked for this Heat.',
    minHeat: 12,
    isHard: true,
    isBoss: true,
  );

  const HeatModifier(
    this.id,
    this.displayName,
    this.description, {
    required this.minHeat,
    this.isHard = false,
    this.isBoss = false,
  });

  final String id;
  final String displayName;
  final String description;
  final int minHeat;
  final bool isHard;
  final bool isBoss;

  static HeatModifier? fromLegacy(Object? value) {
    if (value == null || value == '') return null;
    return HeatModifier.values.cast<HeatModifier?>().firstWhere(
      (modifier) => modifier!.id == value,
      orElse: () => null,
    );
  }
}

enum RunMode { normal, daily, gauntlet }

enum RunDifficulty {
  easy('easy', 'Easy', 0.75, 0.60),
  medium('normal', 'Medium', 1.00, 1.00),
  hard('hard', 'Hard', 1.30, 1.60);

  const RunDifficulty(
    this.legacyId,
    this.displayName,
    this.targetMultiplier,
    this.stakeMultiplier,
  );

  final String legacyId;
  final String displayName;
  final double targetMultiplier;
  final double stakeMultiplier;

  static RunDifficulty fromLegacy(Object? value) =>
      RunDifficulty.values.firstWhere(
        (difficulty) => difficulty.legacyId == value,
        orElse: () => RunDifficulty.medium,
      );
}

const Map<HandType, int> handBasePoints = <HandType, int>{
  HandType.highCard: 5,
  HandType.pair: 20,
  HandType.twoPair: 40,
  HandType.threeOfAKind: 70,
  HandType.straight: 100,
  HandType.flush: 120,
  HandType.fullHouse: 160,
  HandType.fourOfAKind: 220,
  HandType.straightFlush: 320,
  HandType.royalFlush: 400,
};

const Map<HandType, int> handLevelBump = <HandType, int>{
  HandType.highCard: 10,
  HandType.pair: 15,
  HandType.twoPair: 25,
  HandType.threeOfAKind: 35,
  HandType.straight: 45,
  HandType.flush: 50,
  HandType.fullHouse: 60,
  HandType.fourOfAKind: 80,
  HandType.straightFlush: 100,
  HandType.royalFlush: 120,
};

const List<int> heatTargets = <int>[
  90,
  135,
  205,
  280,
  380,
  520,
  700,
  920,
  1150,
  1400,
  1700,
  2050,
];

const int endlessTargetStep = 600;
const int endlessAccelerationHeat = 20;
const int endlessSecondAccelerationHeat = 35;
const int handsPerHeat = 4;
const int discardsPerHeat = 5;
const int handSize = 9;
const int minimumDeckSize = 24;
const int maximumExactCardCopies = 2;
const int maxSelectedCards = 5;
const int maxJokers = 5;
const int maxHandLevel = 5;
const double baseMultiplier = 1.1;
const double rankScale = 0.6;
const int gauntletHeats = 8;

int runReward(int heat) => 2 + (heat * 0.75).ceil();
int accountReward(int heat) => 2 + heat ~/ 3;

List<HeatModifier> eligibleModifiers(int stage) => HeatModifier.values
    .where((modifier) => !modifier.isBoss && stage >= modifier.minHeat)
    .toList(growable: false);

class ScoringState {
  ScoringState({
    required this.rngSeed,
    RandomCounters? rngCounters,
    this.mode = RunMode.normal,
    this.difficulty = RunDifficulty.medium,
    this.stage = 1,
    this.stageScore = 0,
    this.handsLeft = handsPerHeat,
    this.discardsLeft = discardsPerHeat,
    this.handsPlayedThisStage = 0,
    this.runCoins = 0,
    List<String>? jokerIds,
    Set<String>? blockedJokerIds,
    Map<String, double>? jokerState,
    List<PlayingCard>? cards,
    this.deckCardsLeft = 0,
    Map<HandType, int>? handLevels,
    this.destroyedCount = 0,
    this.copiedCount = 0,
    this.shatteredCount = 0,
    this.stagesCleared = 0,
    HeatModifier? modifier,
    Iterable<HeatModifier>? modifierStack,
    this.previousHandType,
    this.previousGauntletModifierName,
    this.endless = false,
  }) : rngCounters = rngCounters ?? RandomCounters(),
       jokerIds = jokerIds ?? <String>[],
       blockedJokerIds = blockedJokerIds ?? <String>{},
       jokerState = jokerState ?? <String, double>{},
       cards = cards ?? baseCardSet(),
       handLevels = handLevels ?? <HandType, int>{},
       modifiers = _uniqueModifiers(
         modifierStack ??
             (modifier == null
                 ? const <HeatModifier>[]
                 : <HeatModifier>[modifier]),
       );

  int rngSeed;
  RandomCounters rngCounters;
  RunMode mode;
  RunDifficulty difficulty;
  int stage;
  int stageScore;
  int handsLeft;
  int discardsLeft;
  int handsPlayedThisStage;
  int runCoins;
  final List<String> jokerIds;
  final Set<String> blockedJokerIds;
  final Map<String, double> jokerState;
  final List<PlayingCard> cards;
  int deckCardsLeft;
  final Map<HandType, int> handLevels;
  int destroyedCount;
  int copiedCount;
  int shatteredCount;
  int stagesCleared;
  List<HeatModifier> modifiers;
  HandType? previousHandType;
  String? previousGauntletModifierName;
  bool endless;

  bool get isGauntlet => mode == RunMode.gauntlet;
  bool get isDaily => mode == RunMode.daily;

  /// Daily must be Medium so every player receives the same target curve.
  /// This intentionally fixes the v7.1.0 web bug where the last Normal picker
  /// choice leaked into a Daily started in the same process.
  RunDifficulty get balanceDifficulty =>
      mode == RunMode.normal ? difficulty : RunDifficulty.medium;
  bool get hasAnyModifier => modifiers.isNotEmpty;
  bool get hasBossModifier => modifiers.any((modifier) => modifier.isBoss);

  /// Compatibility accessor for old single-modifier call sites.
  HeatModifier? get modifier => modifiers.isEmpty ? null : modifiers.first;

  set modifier(HeatModifier? value) {
    modifiers = value == null ? <HeatModifier>[] : <HeatModifier>[value];
  }

  void setModifiers(Iterable<HeatModifier> values) {
    modifiers = _uniqueModifiers(values);
  }

  bool hasModifier(HeatModifier value) => modifiers.contains(value);

  bool isJokerActive(String id) =>
      jokerIds.contains(id) && !blockedJokerIds.contains(id);

  int get effectiveDiscards =>
      discardsPerHeat - (hasModifier(HeatModifier.cold) ? 1 : 0);

  int get effectiveHandSize =>
      handSize -
      (hasModifier(HeatModifier.shortStack) ? 1 : 0) -
      (hasModifier(HeatModifier.famine) ? 2 : 0);

  int get effectiveHandsPerHeat => math.max(
    1,
    handsPerHeat - (hasModifier(HeatModifier.closingTime) ? 1 : 0),
  );

  int get effectiveMaxSelect {
    if (hasModifier(HeatModifier.lowCeiling)) return 4;
    return isJokerActive('cheat') ? 6 : maxSelectedCards;
  }

  int get target {
    final safeStage = math.max(1, stage);
    var result = safeStage <= 12
        ? heatTargets[safeStage - 1]
        : _endlessTarget(safeStage);
    if (isGauntlet) {
      result = (heatTargets[safeStage.clamp(1, gauntletHeats) - 1] * 1.2)
          .round();
    } else {
      result = (result * balanceDifficulty.targetMultiplier).round();
    }
    if (hasModifier(HeatModifier.tax)) result = (result * 1.15).round();
    if (hasModifier(HeatModifier.highStakes)) {
      result = (result * 1.25).round();
    }
    if (hasModifier(HeatModifier.thinIce) && cards.length < 30) {
      result = (result * 1.40).round();
    }
    if (hasBossModifier) result = (result * 1.10).round();
    return result;
  }

  int handBase(HandType type) {
    final level = hasModifier(HeatModifier.levelLock)
        ? 0
        : (handLevels[type] ?? 0).clamp(0, maxHandLevel);
    return handBasePoints[type]! + handLevelBump[type]! * level;
  }

  double nextRandom(RandomStream stream) => rngCounters.next(stream, rngSeed);
}

int _endlessTarget(int stage) {
  final over20 = math.max(0, stage - endlessAccelerationHeat);
  final over35 = math.max(0, stage - endlessSecondAccelerationHeat);
  return heatTargets.last +
      endlessTargetStep * (stage - 12) +
      35 * over20 * over20 +
      65 * over35 * over35;
}

List<HeatModifier> _uniqueModifiers(Iterable<HeatModifier> source) {
  final result = <HeatModifier>[];
  for (final modifier in source) {
    if (!result.contains(modifier)) result.add(modifier);
  }
  return result;
}

/// Stateful, stream-compatible v7.1.0 modifier assignment.
class ModifierSelector {
  ModifierSelector(this.state);

  final ScoringState state;

  List<HeatModifier> assignForCurrentHeat() {
    state.blockedJokerIds.clear();
    late List<HeatModifier> selected;
    if (state.isGauntlet) {
      selected = _gauntletModifiers();
    } else if (state.stage == 12 && !state.endless) {
      selected = const <HeatModifier>[HeatModifier.theHouse];
    } else if (state.endless && state.stage > 50) {
      selected = _drawDistinct(2, requireHard: true);
    } else if (state.stage > 0 && state.stage % 3 == 0) {
      selected = _drawDistinct(1);
    } else {
      selected = const <HeatModifier>[];
    }
    state.setModifiers(selected);
    return List<HeatModifier>.unmodifiable(selected);
  }

  List<HeatModifier> _gauntletModifiers() {
    if (state.stage == gauntletHeats) {
      return const <HeatModifier>[HeatModifier.theHouse];
    }
    final pool = eligibleModifiers(math.min(12, state.stage + 5));
    if (pool.isEmpty) return const <HeatModifier>[];
    var chosen = _pick(pool);
    var guard = 0;
    while (pool.length > 1 &&
        chosen.displayName == state.previousGauntletModifierName &&
        guard++ < 8) {
      chosen = _pick(pool);
    }
    state.previousGauntletModifierName = chosen.displayName;
    return <HeatModifier>[chosen];
  }

  List<HeatModifier> _drawDistinct(int count, {bool requireHard = false}) {
    final pool = eligibleModifiers(state.stage).toList(growable: true);
    final result = <HeatModifier>[];
    if (requireHard) {
      final hard = pool.where((modifier) => modifier.isHard).toList();
      if (hard.isNotEmpty) {
        final chosen = _pick(hard);
        result.add(chosen);
        pool.remove(chosen);
      }
    }
    while (result.length < count && pool.isNotEmpty) {
      final index = (state.nextRandom(RandomStream.modifiers) * pool.length)
          .floor();
      result.add(pool.removeAt(index));
    }
    return result;
  }

  HeatModifier _pick(List<HeatModifier> pool) {
    final index = (state.nextRandom(RandomStream.modifiers) * pool.length)
        .floor();
    return pool[index];
  }
}

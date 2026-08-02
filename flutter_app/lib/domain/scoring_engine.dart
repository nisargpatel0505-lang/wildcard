import 'dart:math' as math;

import 'cards.dart';
import 'game_rules.dart';
import 'joker_catalog.dart';
import 'random_streams.dart';

enum ScoreEventType { card, rankJoker, retrigger, seven, mult, xMult }

enum LevelRankColor { red, black }

/// Immutable, per-play scoring rules used only by a Level Mode attempt.
///
/// The controller owns changing attempt state (the play number, hand history,
/// and currently disabled suit) and creates a fresh override for each preview
/// and committed score. Passing no override preserves the Arcade pipeline.
class LevelScoringOverride {
  LevelScoringOverride({
    this.highCardScoresZero = false,
    Set<HandType> allowedHandTypes = const <HandType>{},
    this.faceRanksScoreZero = false,
    this.scoringColor,
    this.redRankFactor = 1,
    this.blackRankFactor = 1,
    Map<HandType, int> previousHandCounts = const <HandType, int>{},
    this.repeatDecay = 0,
    this.repeatedHandsScoreZero = false,
    this.playIndex = 0,
    List<double> perPlayScoreFactors = const <double>[],
    this.disabledSuit,
    this.hasAuthoredModifier = false,
    this.authoredModifierCount = 0,
  }) : allowedHandTypes = Set<HandType>.unmodifiable(allowedHandTypes),
       previousHandCounts = Map<HandType, int>.unmodifiable(previousHandCounts),
       perPlayScoreFactors = List<double>.unmodifiable(perPlayScoreFactors) {
    if (redRankFactor < 0 || !redRankFactor.isFinite) {
      throw ArgumentError.value(redRankFactor, 'redRankFactor');
    }
    if (blackRankFactor < 0 || !blackRankFactor.isFinite) {
      throw ArgumentError.value(blackRankFactor, 'blackRankFactor');
    }
    if (repeatDecay < 0 || repeatDecay > 1 || !repeatDecay.isFinite) {
      throw ArgumentError.value(repeatDecay, 'repeatDecay');
    }
    if (playIndex < 0) throw ArgumentError.value(playIndex, 'playIndex');
    if (authoredModifierCount < 0) {
      throw ArgumentError.value(authoredModifierCount, 'authoredModifierCount');
    }
    if (previousHandCounts.values.any((count) => count < 0)) {
      throw ArgumentError.value(previousHandCounts, 'previousHandCounts');
    }
    if (perPlayScoreFactors.any((factor) => factor < 0 || !factor.isFinite)) {
      throw ArgumentError.value(perPlayScoreFactors, 'perPlayScoreFactors');
    }
  }

  final bool highCardScoresZero;
  final Set<HandType> allowedHandTypes;
  final bool faceRanksScoreZero;
  final LevelRankColor? scoringColor;
  final double redRankFactor;
  final double blackRankFactor;
  final Map<HandType, int> previousHandCounts;
  final double repeatDecay;
  final bool repeatedHandsScoreZero;

  /// Zero-based number of scoring hands already resolved in this level.
  final int playIndex;
  final List<double> perPlayScoreFactors;

  /// The visible suit disabled for this play, after rotation is resolved.
  final CardSuit? disabledSuit;

  /// Authored Level modifiers are rule descriptors, not Arcade
  /// [HeatModifier] values. Their count lives here so modifier-sensitive
  /// Jokers work without injecting fake Heat modifiers and their side effects.
  final bool hasAuthoredModifier;
  final int authoredModifierCount;

  int previousCount(HandType type) => previousHandCounts[type] ?? 0;

  double get perPlayFactor => playIndex < perPlayScoreFactors.length
      ? perPlayScoreFactors[playIndex]
      : 1;

  bool suppressesRank(PlayingCard card) {
    if (disabledSuit == card.suit) return true;
    if (faceRanksScoreZero &&
        const <CardRank>{
          CardRank.jack,
          CardRank.queen,
          CardRank.king,
        }.contains(card.rank)) {
      return true;
    }
    return switch (scoringColor) {
      LevelRankColor.red => !card.isRed,
      LevelRankColor.black => card.isRed,
      null => false,
    };
  }

  double rankFactor(PlayingCard card) =>
      card.isRed ? redRankFactor : blackRankFactor;
}

class ScoreEvent {
  const ScoreEvent({
    required this.type,
    this.cardIndex,
    this.jokerIndex,
    this.label,
    this.amount = 0,
    this.multiplier,
    this.hit,
  });

  final ScoreEventType type;
  final int? cardIndex;
  final int? jokerIndex;
  final String? label;
  final num amount;
  final double? multiplier;
  final bool? hit;
}

class AnalyzedHand {
  const AnalyzedHand({required this.type, required this.scoringCards});

  final HandType type;
  final Set<PlayingCard> scoringCards;
}

class ScoreResult {
  const ScoreResult({
    required this.handType,
    required this.base,
    required this.rankSum,
    required this.rankScore,
    required this.valuePoints,
    required this.multiplier,
    required this.total,
    required this.perCard,
    required this.scoringFlags,
    required this.events,
  });

  final HandType handType;
  final int base;
  final int rankSum;
  final int rankScore;
  final int valuePoints;
  final double multiplier;
  final int total;
  final List<int> perCard;
  final List<bool> scoringFlags;
  final List<ScoreEvent> events;

  int get scoringCount => scoringFlags.where((value) => value).length;
}

class GlassShatterResult {
  const GlassShatterResult({
    required this.shattered,
    required this.twoOrMoreScored,
  });

  final int shattered;
  final bool twoOrMoreScored;
}

enum JokerModifierVisualState {
  active,
  blocked,
  multiplierSuppressed,
  redundant,
}

class JokerModifierStatus {
  const JokerModifierStatus(this.state, this.label);

  static const active = JokerModifierStatus(
    JokerModifierVisualState.active,
    '',
  );

  final JokerModifierVisualState state;
  final String label;

  bool get blocked => state == JokerModifierVisualState.blocked;
  bool get multiplierSuppressed =>
      state == JokerModifierVisualState.multiplierSuppressed;
  bool get redundant => state == JokerModifierVisualState.redundant;
}

const Set<JokerEffect> _additiveMultiplierEffects = <JokerEffect>{
  JokerEffect.copperChip,
  JokerEffect.momentum,
  JokerEffect.suitUniform,
  JokerEffect.pairTrainer,
  JokerEffect.dumpsterValue,
  JokerEffect.fullTable,
  JokerEffect.deckMiser,
  JokerEffect.overtime,
  JokerEffect.butcher,
  JokerEffect.collector,
  JokerEffect.piggyBank,
  JokerEffect.heatSurge,
  JokerEffect.cleaner,
  JokerEffect.printer,
  JokerEffect.practiceMode,
  JokerEffect.openingAct,
  JokerEffect.clutchGear,
  JokerEffect.coldAdapter,
  JokerEffect.encore,
  JokerEffect.colorWash,
  JokerEffect.marathoner,
  JokerEffect.metronome,
  JokerEffect.comboist,
  JokerEffect.neonDealer,
  JokerEffect.hoarder,
  JokerEffect.ensemble,
  JokerEffect.warmUp,
  JokerEffect.chaosTheory,
  JokerEffect.safeCracker,
};

const Set<JokerEffect> _multiplicativeMultiplierEffects = <JokerEffect>{
  JokerEffect.devTwentyX,
  JokerEffect.pairPolisher,
  JokerEffect.flushFund,
  JokerEffect.straightWire,
  JokerEffect.highRoller,
  JokerEffect.lastCall,
  JokerEffect.powerCouple,
  JokerEffect.sniper,
  JokerEffect.boostFiend,
  JokerEffect.moddedOut,
  JokerEffect.tailor,
  JokerEffect.survivor,
  JokerEffect.doubleDown,
  JokerEffect.allIn,
  JokerEffect.frequencyMeter,
  JokerEffect.panicButton,
  JokerEffect.stormHarness,
  JokerEffect.guillotine,
  JokerEffect.redline,
  JokerEffect.masterClass,
  JokerEffect.dangerMusic,
  JokerEffect.rehearsalTape,
  JokerEffect.prismLens,
  JokerEffect.glassJoystick,
  JokerEffect.twinFlame,
  JokerEffect.trident,
  JokerEffect.quartet,
  JokerEffect.faceValue,
  JokerEffect.aceInTheHole,
  JokerEffect.rainbow,
  JokerEffect.underdog,
  JokerEffect.frontrunner,
  JokerEffect.perfectionist,
  JokerEffect.goldsmith,
  JokerEffect.wildWhisperer,
  JokerEffect.purist,
  JokerEffect.monochrome,
  JokerEffect.twinStudy,
  JokerEffect.rarityHunter,
  JokerEffect.overclock,
  JokerEffect.roulette,
  JokerEffect.bloodMoney,
  JokerEffect.fragileGenius,
  JokerEffect.highWire,
  JokerEffect.ruleBreaker,
};

/// Presentation status derived from the same rule channels used by scoring.
///
/// `multiplierSuppressed` is intentionally distinct from a full block: Pair
/// Trainer can still train and Glass Joystick can still resolve its later
/// shatter hook even while their scoring multiplier is jammed.
JokerModifierStatus jokerModifierStatus(
  ScoringState state,
  JokerDefinition joker,
) {
  if (state.blockedJokerIds.contains(joker.id)) {
    return const JokerModifierStatus(
      JokerModifierVisualState.blocked,
      'BLOCKED BY THE HOUSE',
    );
  }
  if (state.hasModifier(HeatModifier.lowCeiling) &&
      const <JokerEffect>{
        JokerEffect.theCheat,
        JokerEffect.fullTable,
        JokerEffect.prismLens,
      }.contains(joker.effect)) {
    return const JokerModifierStatus(
      JokerModifierVisualState.blocked,
      'BLOCKED BY LOW CEILING',
    );
  }
  if (state.hasModifier(HeatModifier.lowCeiling) &&
      joker.effect == JokerEffect.pocketFlush) {
    return const JokerModifierStatus(
      JokerModifierVisualState.redundant,
      'REDUNDANT UNDER LOW CEILING',
    );
  }
  if (state.hasModifier(HeatModifier.heartless) &&
      joker.effect == JokerEffect.suitPresser) {
    return const JokerModifierStatus(
      JokerModifierVisualState.blocked,
      'BLOCKED BY HEARTLESS',
    );
  }
  if (state.hasModifier(HeatModifier.nullField) &&
      (_additiveMultiplierEffects.contains(joker.effect) ||
          _multiplicativeMultiplierEffects.contains(joker.effect))) {
    return const JokerModifierStatus(
      JokerModifierVisualState.multiplierSuppressed,
      'MULT OFF',
    );
  }
  if (state.hasModifier(HeatModifier.deadAir) &&
      _multiplicativeMultiplierEffects.contains(joker.effect)) {
    return const JokerModifierStatus(
      JokerModifierVisualState.multiplierSuppressed,
      '×MULT JAMMED',
    );
  }
  return JokerModifierStatus.active;
}

class WildcardScoringEngine {
  WildcardScoringEngine(this.state, {this.levelOverride});

  final ScoringState state;
  final LevelScoringOverride? levelOverride;

  List<_EquippedJoker> get _activeJokers => <_EquippedJoker>[
    for (var index = 0; index < state.jokerIds.length; index++)
      if (!state.blockedJokerIds.contains(state.jokerIds[index]) &&
          jokersById.containsKey(state.jokerIds[index]))
        _EquippedJoker(index, jokersById[state.jokerIds[index]]!),
  ];

  bool hasJoker(String id) => state.isJokerActive(id);

  bool get _hasEffectiveModifier =>
      state.hasAnyModifier ||
      (levelOverride?.hasAuthoredModifier ?? false) ||
      _effectiveModifierCount > 0;

  int get _effectiveModifierCount => levelOverride == null
      ? state.modifiers.length
      : math.max(state.modifiers.length, levelOverride!.authoredModifierCount);

  int _evaluationValue(PlayingCard card) =>
      hasJoker('alchemist') && card.rank == CardRank.two ? 15 : card.value;

  List<String> ensureBossBlocks() {
    if (!state.hasBossModifier) {
      state.blockedJokerIds.clear();
      return const <String>[];
    }
    final equipped = <String>[];
    for (final id in state.jokerIds) {
      if (!equipped.contains(id)) equipped.add(id);
    }
    final wanted = math.min(2, equipped.length);
    final kept = state.blockedJokerIds
        .where(equipped.contains)
        .take(wanted)
        .toList(growable: true);
    final available = equipped.where((id) => !kept.contains(id)).toList();
    while (kept.length < wanted && available.isNotEmpty) {
      final index = (state.nextRandom(RandomStream.boss) * available.length)
          .floor();
      kept.add(available.removeAt(index));
    }
    state.blockedJokerIds
      ..clear()
      ..addAll(kept);
    return List<String>.unmodifiable(kept);
  }

  HandType evaluateHand(List<PlayingCard> cards) {
    final values = cards.map(_evaluationValue).toList();
    final counts = <int, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (hasJoker('understudy') && values.isNotEmpty) {
      final highest = values.reduce(math.max);
      counts[highest] = (counts[highest] ?? 0) + 1;
    }
    final groups = counts.values.toList()..sort((a, b) => b.compareTo(a));
    final five = cards.length == 5;
    final flushFour =
        cards.length == 4 &&
        (state.hasModifier(HeatModifier.lowCeiling) || hasJoker('pocketflush'));
    final flush =
        (five || flushFour) &&
        _canFormFlush(cards, extraWildSlots: hasJoker('suit_swap') ? 1 : 0);

    final unique = values.toSet().toList()..sort();
    final straightLength = five
        ? 5
        : cards.length == 4 && state.hasModifier(HeatModifier.lowCeiling)
        ? 4
        : cards.length == 3 && hasJoker('shortcut')
        ? 3
        : 0;
    final straight =
        straightLength > 0 &&
        unique.length == straightLength &&
        (_isConsecutiveStraight(unique) ||
            (five && hasJoker('gap_filler') && _isSingleGapStraight(unique)));
    final royal = five && _sameInts(unique, const <int>[10, 11, 12, 13, 15]);

    if (straight && flush) {
      return royal ? HandType.royalFlush : HandType.straightFlush;
    }
    // Understudy can promote an existing four-of-a-kind to a synthetic count
    // of five. It must preserve the authoritative four-of-a-kind result.
    if (groups.isNotEmpty && groups[0] >= 4) return HandType.fourOfAKind;
    if (groups.length > 1 && groups[0] == 3 && groups[1] == 2) {
      return HandType.fullHouse;
    }
    if (flush) return HandType.flush;
    if (straight) return HandType.straight;
    if (groups.isNotEmpty && groups[0] == 3) return HandType.threeOfAKind;
    if (groups.length > 1 && groups[0] == 2 && groups[1] == 2) {
      return HandType.twoPair;
    }
    if (groups.isNotEmpty && groups[0] == 2) return HandType.pair;
    return HandType.highCard;
  }

  AnalyzedHand analyzeHand(List<PlayingCard> cards) {
    if (cards.length == 6) {
      AnalyzedHand? best;
      var bestEstimate = -1;
      for (var skipped = 0; skipped < 6; skipped++) {
        final subset = <PlayingCard>[
          for (var index = 0; index < cards.length; index++)
            if (index != skipped) cards[index],
        ];
        final type = evaluateHand(subset);
        final analysis = AnalyzedHand(
          type: type,
          scoringCards: scoringCards(subset, type),
        );
        final estimate = scoreHand(
          cards,
          commit: false,
          resolvedHand: analysis,
        ).total;
        if (estimate > bestEstimate) {
          bestEstimate = estimate;
          best = analysis;
        }
      }
      return best!;
    }
    final type = evaluateHand(cards);
    return AnalyzedHand(type: type, scoringCards: scoringCards(cards, type));
  }

  Set<PlayingCard> scoringCards(List<PlayingCard> cards, HandType type) {
    if (type == HandType.highCard) {
      var pool = cards;
      if (state.hasModifier(HeatModifier.heartless) ||
          state.hasModifier(HeatModifier.frostbite) ||
          levelOverride != null) {
        final liveCards = cards
            .where((card) => !_cardRankSuppressed(card))
            .toList();
        if (liveCards.isNotEmpty) pool = liveCards;
      }
      var best = pool.first;
      var bestValue = cardEffectiveRankForScoring(best);
      for (final card in pool) {
        final value = cardEffectiveRankForScoring(card);
        if (value > bestValue) {
          best = card;
          bestValue = value;
        }
      }
      return <PlayingCard>{best};
    }
    if (type == HandType.pair ||
        type == HandType.twoPair ||
        type == HandType.threeOfAKind ||
        type == HandType.fourOfAKind ||
        (type == HandType.fullHouse && hasJoker('understudy'))) {
      final counts = <int, int>{};
      for (final card in cards) {
        final value = _evaluationValue(card);
        counts[value] = (counts[value] ?? 0) + 1;
      }
      return cards
          .where((card) => counts[_evaluationValue(card)]! >= 2)
          .toSet();
    }
    return cards.toSet();
  }

  int cardEffectiveRankForScoring(PlayingCard card) {
    if (_cardRankSuppressed(card)) return 0;
    var value = _evaluationValue(card);
    for (final joker in _activeJokers) {
      value += _rankBonus(joker.definition.effect, card);
    }
    if (card.enhancement == CardEnhancement.gild) value += 8;
    if (hasJoker('royalscam') &&
        const <CardRank>{
          CardRank.jack,
          CardRank.queen,
          CardRank.king,
        }.contains(card.rank)) {
      value *= 2;
    }
    return _applyLevelRankFactor(value, card);
  }

  ScoreResult scoreHand(
    List<PlayingCard> cards, {
    bool commit = false,
    AnalyzedHand? resolvedHand,
  }) {
    if (cards.isEmpty) {
      throw ArgumentError.value(cards, 'cards', 'Cannot score');
    }
    final analyzed = resolvedHand ?? analyzeHand(cards);
    final events = <ScoreEvent>[];
    final perCard = <int>[];
    final flags = <bool>[];
    var rankSum = 0;
    final scoringIndices = <int>[
      for (var index = 0; index < cards.length; index++)
        if (analyzed.scoringCards.contains(cards[index])) index,
    ];
    final firstScoringIndex = scoringIndices.firstWhere(
      (index) => !_cardRankSuppressed(cards[index]),
      orElse: () => -1,
    );
    final lastScoringIndex = scoringIndices.isEmpty ? -1 : scoringIndices.last;

    for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
      final card = cards[cardIndex];
      final scores = analyzed.scoringCards.contains(card);
      flags.add(scores);
      if (!scores) {
        perCard.add(0);
        continue;
      }
      var value = 0;
      if (!_cardRankSuppressed(card)) {
        final levelRankFactor = levelOverride?.rankFactor(card) ?? 1;
        value = _applyLevelRankFactor(_evaluationValue(card), card);
        rankSum += value;
        events.add(
          ScoreEvent(
            type: ScoreEventType.card,
            cardIndex: cardIndex,
            amount: value,
            label: levelRankFactor == 1
                ? '+$value'
                : '${card.isRed ? 'RED' : 'BLACK'} '
                      '×${_formatFactor(levelRankFactor)} +$value',
          ),
        );
        for (final joker in _activeJokers) {
          final rawBonus = _rankBonus(
            joker.definition.effect,
            card,
            cardIndex: cardIndex,
            firstScoringIndex: firstScoringIndex,
            lastScoringIndex: lastScoringIndex,
          );
          if (rawBonus != 0) {
            final bonus = _applyLevelRankFactor(rawBonus, card);
            value += bonus;
            rankSum += bonus;
            events.add(
              ScoreEvent(
                type: ScoreEventType.rankJoker,
                cardIndex: cardIndex,
                jokerIndex: joker.index,
                amount: bonus,
                label: levelRankFactor == 1
                    ? '+$bonus Rank'
                    : 'RANK ×${_formatFactor(levelRankFactor)} +$bonus',
              ),
            );
          }
        }
        if (card.enhancement == CardEnhancement.gild) {
          final gildBonus = _applyLevelRankFactor(8, card);
          value += gildBonus;
          rankSum += gildBonus;
          events.add(
            ScoreEvent(
              type: ScoreEventType.card,
              cardIndex: cardIndex,
              amount: gildBonus,
              label: levelRankFactor == 1
                  ? 'GILD +8'
                  : 'GILD ×${_formatFactor(levelRankFactor)} +$gildBonus',
            ),
          );
        }
      } else {
        events.add(
          ScoreEvent(
            type: ScoreEventType.card,
            cardIndex: cardIndex,
            label: _rankSuppressionLabel(card),
          ),
        );
      }
      perCard.add(value);

      if (value > 0 &&
          hasJoker('royalscam') &&
          const <CardRank>{
            CardRank.jack,
            CardRank.queen,
            CardRank.king,
          }.contains(card.rank)) {
        rankSum += value;
        events.add(
          ScoreEvent(
            type: ScoreEventType.retrigger,
            cardIndex: cardIndex,
            jokerIndex: state.jokerIds.indexOf('royalscam'),
            amount: value,
            label: 'AGAIN +$value',
          ),
        );
      }
      if (value > 0 &&
          hasJoker('lucky7') &&
          card.rank == CardRank.seven &&
          commit) {
        final hit = state.nextRandom(RandomStream.luck) < 1 / 3;
        final bonus = hit ? value * 9 : 0;
        rankSum += bonus;
        events.add(
          ScoreEvent(
            type: ScoreEventType.seven,
            cardIndex: cardIndex,
            jokerIndex: state.jokerIds.indexOf('lucky7'),
            amount: bonus,
            hit: hit,
          ),
        );
      }
    }

    final rankScore = (rankSum * rankScale).round();
    final base = hasJoker('two_faced') && analyzed.type == HandType.twoPair
        ? handBasePoints[HandType.fullHouse]! +
              state.handBase(HandType.twoPair) -
              handBasePoints[HandType.twoPair]!
        : state.handBase(analyzed.type);
    final valuePoints = base + rankScore;
    var multiplier = baseMultiplier;

    if (!state.hasModifier(HeatModifier.nullField)) {
      for (var index = 0; index < cards.length; index++) {
        if (flags[index] && cards[index].enhancement == CardEnhancement.neon) {
          multiplier += 0.20;
          events.add(
            ScoreEvent(
              type: ScoreEventType.mult,
              cardIndex: index,
              jokerIndex: -1,
              label: 'NEON +0.20',
              amount: 0.20,
              multiplier: multiplier,
            ),
          );
        }
      }
      for (final joker in _activeJokers) {
        final additive = _additiveMultiplier(
          joker.definition.effect,
          analyzed.type,
          cards,
        );
        multiplier += additive;
        if (additive > 0.001) {
          events.add(
            ScoreEvent(
              type: ScoreEventType.mult,
              jokerIndex: joker.index,
              label: '+${additive.toStringAsFixed(2)} Mult',
              amount: additive,
              multiplier: multiplier,
            ),
          );
        }
      }
    }
    if (!state.hasModifier(HeatModifier.deadAir) &&
        !state.hasModifier(HeatModifier.nullField)) {
      for (final joker in _activeJokers) {
        final factor = _multiplicativeMultiplier(
          joker.definition.effect,
          analyzed.type,
          cards,
          commit: commit,
        );
        multiplier *= factor;
        if ((factor - 1).abs() > 0.001) {
          events.add(
            ScoreEvent(
              type: ScoreEventType.xMult,
              jokerIndex: joker.index,
              label: '×$factor',
              amount: factor,
              multiplier: multiplier,
            ),
          );
        }
      }
    }
    if (!state.hasModifier(HeatModifier.nullField)) {
      for (var index = 0; index < cards.length; index++) {
        if (flags[index] && cards[index].enhancement == CardEnhancement.glass) {
          multiplier *= 1.5;
          events.add(
            ScoreEvent(
              type: ScoreEventType.xMult,
              cardIndex: index,
              jokerIndex: -1,
              label: 'GLASS ×1.5',
              amount: 1.5,
              multiplier: multiplier,
            ),
          );
        }
      }
    }
    if (state.hasModifier(HeatModifier.echoChamber) &&
        state.previousHandType == analyzed.type) {
      multiplier *= 0.5;
      events.add(
        ScoreEvent(
          type: ScoreEventType.xMult,
          jokerIndex: -1,
          label: 'ECHO ×0.5',
          amount: 0.5,
          multiplier: multiplier,
        ),
      );
    }

    final levelRules = levelOverride;
    if (levelRules != null) {
      void applyLevelFactor(double factor, String label) {
        multiplier *= factor;
        events.add(
          ScoreEvent(
            type: ScoreEventType.xMult,
            jokerIndex: -1,
            label: label,
            amount: factor,
            multiplier: multiplier,
          ),
        );
      }

      final previousCount = levelRules.previousCount(analyzed.type);
      if (levelRules.highCardScoresZero && analyzed.type == HandType.highCard) {
        applyLevelFactor(0, 'LEVEL RULE · HIGH CARD ×0');
      } else if (levelRules.allowedHandTypes.isNotEmpty &&
          !levelRules.allowedHandTypes.contains(analyzed.type)) {
        applyLevelFactor(0, 'LEVEL RULE · HAND NOT ALLOWED ×0');
      } else if (levelRules.repeatedHandsScoreZero && previousCount > 0) {
        applyLevelFactor(0, 'LEVEL RULE · NO REPEAT ×0');
      }

      if (levelRules.repeatDecay > 0 && previousCount > 0) {
        // The authored wording says each repeat loses a share of its current
        // value, so decay compounds across prior occurrences. The supplied
        // public package omits solver routes; route replay can lock this
        // interpretation if that private validation artifact is recovered.
        final factor = math
            .pow(1 - levelRules.repeatDecay, previousCount)
            .toDouble();
        applyLevelFactor(factor, 'REPEAT DECAY ×${_formatFactor(factor)}');
      }
      final playFactor = levelRules.perPlayFactor;
      if ((playFactor - 1).abs() > 0.0000001) {
        applyLevelFactor(
          playFactor,
          'PLAY ${levelRules.playIndex + 1} '
          '×${_formatFactor(playFactor)}',
        );
      }
    }

    return ScoreResult(
      handType: analyzed.type,
      base: base,
      rankSum: rankSum,
      rankScore: rankScore,
      valuePoints: valuePoints,
      multiplier: multiplier,
      total: (valuePoints * multiplier).round(),
      perCard: List<int>.unmodifiable(perCard),
      scoringFlags: List<bool>.unmodifiable(flags),
      events: List<ScoreEvent>.unmodifiable(events),
    );
  }

  /// Resets state that is explicitly scoped to one Heat.
  void prepareHeatJokerState() {
    if (state.jokerIds.contains('metronome')) {
      state.jokerState['metronome'] = 0;
    }
    if (state.jokerIds.contains('perfectionist')) {
      state.jokerState['perfect'] = 1;
    }
    if (state.jokerIds.contains('comboist')) {
      state.jokerState['combo'] = 0;
    }
  }

  /// Applies post-score stateful hooks after an authoritative committed play.
  void applyOnScored(ScoreResult result) {
    if (hasJoker('trainer') && result.handType != HandType.highCard) {
      state.jokerState['trainer'] = (state.jokerState['trainer'] ?? 0) + 0.05;
    }
    if (hasJoker('metronome')) {
      state.jokerState['metronome'] = state.previousHandType == result.handType
          ? (state.jokerState['metronome'] ?? 0) + 1
          : 0;
    }
    if (hasJoker('perfectionist') &&
        state.previousHandType != null &&
        state.previousHandType != result.handType) {
      state.jokerState['perfect'] = 0;
    }
    if (hasJoker('comboist')) {
      final bit = 1 << result.handType.index;
      state.jokerState['combo'] =
          ((state.jokerState['combo'] ?? 0).round() | bit).toDouble();
    }
    if (hasJoker('blood_money') && state.runCoins > 0) {
      state.runCoins--;
    }
    if (hasJoker('fragile_genius')) {
      final hadPrevious = state.jokerState.containsKey('fragile');
      final previous = state.jokerState['fragile'] ?? 0;
      if (hadPrevious && result.total < previous) {
        state.jokerIds.removeWhere((id) => id == 'fragile_genius');
        state.jokerState.remove('fragile');
      } else {
        state.jokerState['fragile'] = result.total.toDouble();
      }
    }
    state.previousHandType = result.handType;
  }

  /// Resolves the card enhancement's 20% post-score shatter rolls.
  ///
  /// This is separate from Glass Joystick (the Joker), whose later-Heat roll is
  /// one in six. Luck is consumed only for scoring Glass cards while the deck is
  /// above the 24-card floor, in played-card order, matching the phone client.
  GlassShatterResult resolveGlassCardShatters(
    List<PlayingCard> played,
    List<bool> scoringFlags,
  ) {
    if (played.length != scoringFlags.length) {
      throw ArgumentError('played/scoringFlags length mismatch');
    }
    final scoredGlassCount = <int>[
      for (var index = 0; index < played.length; index++)
        if (scoringFlags[index] &&
            played[index].enhancement == CardEnhancement.glass)
          index,
    ].length;
    var shattered = 0;
    for (var index = 0; index < played.length; index++) {
      final card = played[index];
      if (!scoringFlags[index] ||
          card.enhancement != CardEnhancement.glass ||
          state.cards.length - shattered <= minimumDeckSize) {
        continue;
      }
      if (state.nextRandom(RandomStream.luck) >= 0.2) continue;
      final deckIndex = state.cards.indexWhere(
        (candidate) =>
            candidate.rank == card.rank &&
            candidate.suit == card.suit &&
            candidate.enhancement == CardEnhancement.glass,
      );
      if (deckIndex >= 0) {
        state.cards.removeAt(deckIndex);
        shattered++;
      }
    }
    state.shatteredCount += shattered;
    return GlassShatterResult(
      shattered: shattered,
      twoOrMoreScored: scoredGlassCount >= 2,
    );
  }

  /// Resolves Dividend and Glass Joystick in equipped order after a Heat clear.
  void applyHeatClearJokerHooks() {
    final equippedSnapshot = List<String>.from(state.jokerIds);
    for (final id in equippedSnapshot) {
      if (!state.isJokerActive(id)) continue;
      if (id == 'dividend') state.runCoins += 2;
      if (id == 'safe_cracker' && _effectiveModifierCount > 0) {
        state.jokerState['safecrack'] =
            (state.jokerState['safecrack'] ?? 0) + _effectiveModifierCount;
      }
      if (id == 'glass_joystick') {
        const key = 'glass_joystick_armed';
        if ((state.jokerState[key] ?? 0) == 0) {
          state.jokerState[key] = 1;
        } else if (state.nextRandom(RandomStream.luck) < 1 / 6) {
          state.jokerIds.removeWhere((jokerId) => jokerId == id);
          state.jokerState.remove(key);
        }
      }
    }
  }

  bool _cardRankSuppressed(PlayingCard card) =>
      state.cardRankSuppressed(card) ||
      (levelOverride?.suppressesRank(card) ?? false);

  // Native rank chips are integer-valued. Round at each authored rank
  // contribution so per-card chips, rankSum, rankScore, and the final equation
  // all describe the exact same arithmetic.
  int _applyLevelRankFactor(int value, PlayingCard card) =>
      (value * (levelOverride?.rankFactor(card) ?? 1)).round();

  String _rankSuppressionLabel(PlayingCard card) {
    if (state.cardRankSuppressed(card)) return '0';
    final rules = levelOverride;
    if (rules == null) return '0';
    if (rules.disabledSuit == card.suit) {
      return '${card.suit.name.toUpperCase()} DISABLED · 0';
    }
    if (rules.faceRanksScoreZero &&
        const <CardRank>{
          CardRank.jack,
          CardRank.queen,
          CardRank.king,
        }.contains(card.rank)) {
      return 'FACE RANK · 0';
    }
    return switch (rules.scoringColor) {
      LevelRankColor.red => 'RED CARDS ONLY · 0',
      LevelRankColor.black => 'BLACK CARDS ONLY · 0',
      null => 'LEVEL RULE · 0',
    };
  }

  int _rankBonus(
    JokerEffect effect,
    PlayingCard card, {
    int cardIndex = -1,
    int firstScoringIndex = -1,
    int lastScoringIndex = -1,
  }) => switch (effect) {
    JokerEffect.suitPresser => card.suit == CardSuit.hearts ? 4 : 0,
    JokerEffect.royalRetainer =>
      const <CardRank>{
            CardRank.jack,
            CardRank.queen,
            CardRank.king,
          }.contains(card.rank)
          ? 5
          : 0,
    JokerEffect.evenOdds => card.value.isEven ? 3 : 0,
    JokerEffect.aceMagnet => card.rank == CardRank.ace ? 10 : 0,
    JokerEffect.lowBall => card.value <= 6 ? card.value : 0,
    JokerEffect.inkTrade => !card.isRed ? 3 : 0,
    JokerEffect.tripleThreat =>
      card.rank == CardRank.three ? card.value * 2 : 0,
    JokerEffect.numberStation =>
      const <CardRank>{
            CardRank.two,
            CardRank.three,
            CardRank.four,
          }.contains(card.rank)
          ? 4
          : 0,
    JokerEffect.icePick => card.suit == CardSuit.diamonds ? 4 : 0,
    JokerEffect.unionBoss => card.suit == CardSuit.clubs ? 4 : 0,
    JokerEffect.gravedigger => card.suit == CardSuit.spades ? 4 : 0,
    JokerEffect.roseTint => card.isRed ? 3 : 0,
    JokerEffect.oddJob => card.value.isOdd ? 3 : 0,
    JokerEffect.primeTime =>
      const <CardRank>{
            CardRank.two,
            CardRank.three,
            CardRank.five,
            CardRank.seven,
          }.contains(card.rank)
          ? 4
          : 0,
    JokerEffect.kingpin => card.rank == CardRank.king ? 8 : 0,
    JokerEffect.glazier =>
      card.enhancement == CardEnhancement.glass
          ? _evaluationValue(card) * 2
          : 0,
    JokerEffect.closer =>
      cardIndex >= 0 && cardIndex == lastScoringIndex
          ? _evaluationValue(card) * 2
          : 0,
    JokerEffect.leadoff =>
      cardIndex >= 0 && cardIndex == firstScoringIndex ? 6 : 0,
    _ => 0,
  };

  double _additiveMultiplier(
    JokerEffect effect,
    HandType handType,
    List<PlayingCard> played,
  ) => switch (effect) {
    JokerEffect.copperChip => 0.20,
    JokerEffect.momentum => 0.10 * state.handsPlayedThisStage,
    JokerEffect.suitUniform => _allSameColor(played) ? 0.50 : 0,
    JokerEffect.pairTrainer => state.jokerState['trainer'] ?? 0,
    JokerEffect.dumpsterValue =>
      0.08 * (state.effectiveDiscards - state.discardsLeft),
    JokerEffect.fullTable => played.length == 5 ? 0.40 : 0,
    JokerEffect.deckMiser => 0.02 * state.deckCardsLeft,
    JokerEffect.overtime => 0.15 * math.max(0, state.stage - 9),
    JokerEffect.butcher => 0.30 * state.destroyedCount,
    JokerEffect.collector => 0.04 * state.copiedCount,
    JokerEffect.piggyBank => 0.05 * (state.runCoins ~/ 5),
    JokerEffect.heatSurge => 0.12 * state.stagesCleared,
    JokerEffect.cleaner => state.cards.length < 45 ? 0.25 : 0,
    JokerEffect.printer => 0.10 * state.copiedCount,
    JokerEffect.practiceMode =>
      0.15 * state.handLevels.values.where((level) => level > 0).length,
    JokerEffect.openingAct => state.handsPlayedThisStage == 0 ? 0.50 : 0,
    JokerEffect.clutchGear => state.handsLeft == 1 ? 0.60 : 0,
    JokerEffect.coldAdapter => state.hasModifier(HeatModifier.cold) ? 0.30 : 0,
    JokerEffect.encore => state.previousHandType == handType ? 0.30 : 0,
    JokerEffect.colorWash => _allSameColor(played) ? 0.45 : 0,
    JokerEffect.marathoner => 0.20 * state.handsLeft,
    JokerEffect.metronome =>
      0.30 *
          (state.previousHandType == handType
              ? (state.jokerState['metronome'] ?? 0) + 1
              : 0),
    JokerEffect.comboist =>
      0.15 *
          _bitCount(
            (state.jokerState['combo'] ?? 0).round() | (1 << handType.index),
          ),
    JokerEffect.neonDealer =>
      0.40 *
          played
              .where((card) => card.enhancement == CardEnhancement.neon)
              .length,
    JokerEffect.hoarder => 0.03 * math.max(0, state.cards.length - 40),
    JokerEffect.ensemble => 0.12 * state.jokerIds.length,
    JokerEffect.warmUp => state.handsPlayedThisStage == 0 ? 0.60 : 0,
    JokerEffect.chaosTheory => 0.50 * _effectiveModifierCount,
    JokerEffect.safeCracker => 0.35 * (state.jokerState['safecrack'] ?? 0),
    _ => 0,
  };

  double _multiplicativeMultiplier(
    JokerEffect effect,
    HandType handType,
    List<PlayingCard> played, {
    required bool commit,
  }) => switch (effect) {
    JokerEffect.devTwentyX => 20,
    JokerEffect.pairPolisher => handType != HandType.highCard ? 1.4 : 1,
    JokerEffect.flushFund => handType.legacyName.contains('Flush') ? 1.8 : 1,
    JokerEffect.straightWire =>
      handType.legacyName.contains('Straight') ? 1.8 : 1,
    JokerEffect.highRoller => 1.25,
    JokerEffect.lastCall => state.handsLeft == 1 ? 3 : 1,
    JokerEffect.powerCouple =>
      played.any((card) => card.rank == CardRank.ace) &&
              played.any((card) => card.rank == CardRank.king)
          ? 1.6
          : 1,
    JokerEffect.sniper => played.length == 1 ? 2.2 : 1,
    JokerEffect.boostFiend => (state.handLevels[handType] ?? 0) > 0 ? 1.3 : 1,
    JokerEffect.moddedOut => _hasEffectiveModifier ? 1.5 : 1,
    JokerEffect.tailor => _maxRankCount(state.cards) >= 5 ? 1.4 : 1,
    JokerEffect.survivor => _hasEffectiveModifier ? 2 : 1,
    JokerEffect.doubleDown => state.previousHandType == handType ? 2 : 1,
    JokerEffect.allIn => state.handsLeft == 1 ? 4 : 0.75,
    JokerEffect.frequencyMeter => _frequencyMeterTriggers(played) ? 1.4 : 1,
    JokerEffect.panicButton => state.discardsLeft == 0 ? 1.4 : 1,
    JokerEffect.stormHarness => _hasEffectiveModifier ? 1.4 : 1,
    JokerEffect.guillotine => state.cards.length < 42 ? 1.5 : 1,
    JokerEffect.redline => state.stageScore >= state.target * 0.55 ? 2.5 : 1,
    JokerEffect.masterClass =>
      math.pow(1.15, state.handLevels[handType] ?? 0).toDouble(),
    JokerEffect.dangerMusic =>
      math.pow(1.35, math.max(0, state.handsPlayedThisStage)).toDouble(),
    JokerEffect.rehearsalTape => state.handsPlayedThisStage == 0 ? 1.3 : 1,
    JokerEffect.prismLens => _fiveShareColor(played) ? 1.35 : 1,
    JokerEffect.glassJoystick => 3,
    JokerEffect.twinFlame => played.length == 2 ? 1.5 : 1,
    JokerEffect.trident => played.length == 3 ? 1.7 : 1,
    JokerEffect.quartet => played.length == 4 ? 1.6 : 1,
    JokerEffect.faceValue =>
      played.any(
            (card) => const <CardRank>{
              CardRank.jack,
              CardRank.queen,
              CardRank.king,
            }.contains(card.rank),
          )
          ? 1.5
          : 1,
    JokerEffect.aceInTheHole =>
      played.any((card) => card.rank == CardRank.ace) ? 1.6 : 1,
    JokerEffect.rainbow =>
      played.map((card) => card.suit).toSet().length >= 3 ? 1.8 : 1,
    JokerEffect.underdog => state.stageScore < state.target * .40 ? 2 : 1,
    JokerEffect.frontrunner => state.stageScore > state.target * .80 ? 1.6 : 1,
    JokerEffect.perfectionist =>
      (state.jokerState['perfect'] ?? 1) > 0 &&
              (state.previousHandType == null ||
                  state.previousHandType == handType)
          ? 2.5
          : 1,
    JokerEffect.goldsmith =>
      played.any((card) => card.enhancement == CardEnhancement.gild) ? 1.5 : 1,
    JokerEffect.wildWhisperer =>
      math
          .pow(
            1.35,
            played
                .where((card) => card.enhancement == CardEnhancement.wildsuit)
                .length,
          )
          .toDouble(),
    JokerEffect.purist =>
      played.every((card) => card.enhancement == null) ? 1.6 : 1,
    JokerEffect.monochrome => _deckHasColorShare(state.cards, .60) ? 1.7 : 1,
    JokerEffect.twinStudy =>
      _ranksWithAtLeastTwoCopies(state.cards) >= 4 ? 1.4 : 1,
    JokerEffect.rarityHunter =>
      math
          .pow(
            1.25,
            state.jokerIds.where((id) {
              final rarity = jokersById[id]?.rarity;
              return rarity == JokerRarity.rare || rarity == JokerRarity.wild;
            }).length,
          )
          .toDouble(),
    JokerEffect.overclock => 2.4,
    JokerEffect.roulette =>
      commit ? (state.nextRandom(RandomStream.luck) < .5 ? 2.5 : .6) : 1.55,
    JokerEffect.bloodMoney => 1.8,
    JokerEffect.fragileGenius => 4,
    JokerEffect.highWire =>
      state.discardsLeft == 0 && state.handsLeft == 1 ? 2.2 : 1,
    JokerEffect.ruleBreaker => state.hasBossModifier ? 2.2 : 1,
    _ => 1,
  };

  bool _frequencyMeterTriggers(List<PlayingCard> played) {
    final counts = <CardRank, int>{};
    for (final card in state.cards) {
      counts[card.rank] = (counts[card.rank] ?? 0) + 1;
    }
    CardRank? best;
    var bestCount = -1;
    var tied = false;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
        tied = false;
      } else if (entry.value == bestCount) {
        tied = true;
      }
    }
    return !tied && best != null && played.any((card) => card.rank == best);
  }
}

class _EquippedJoker {
  const _EquippedJoker(this.index, this.definition);

  final int index;
  final JokerDefinition definition;
}

String _formatFactor(double factor) {
  final fixed = factor.toStringAsFixed(2);
  return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
}

bool _sameInts(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

bool _allSameColor(List<PlayingCard> cards) =>
    cards.isNotEmpty &&
    (cards.every((card) => card.isRed) || cards.every((card) => !card.isRed));

bool _fiveShareColor(List<PlayingCard> cards) {
  final reds = cards.where((card) => card.isRed).length;
  return reds >= 5 || cards.length - reds >= 5;
}

bool _canFormFlush(List<PlayingCard> cards, {int extraWildSlots = 0}) {
  if (cards.isEmpty) return false;
  final suitCounts = <CardSuit, int>{};
  var wildSuitCards = 0;
  for (final card in cards) {
    if (card.enhancement == CardEnhancement.wildsuit) {
      wildSuitCards++;
      continue;
    }
    suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
  }
  final bestSuitCount = suitCounts.values.fold<int>(0, math.max);
  return bestSuitCount + wildSuitCards + extraWildSlots >= cards.length;
}

bool _isConsecutiveStraight(List<int> values) =>
    _straightOrders(values).any((ordered) {
      for (var index = 1; index < ordered.length; index++) {
        if (ordered[index] - ordered[index - 1] != 1) return false;
      }
      return true;
    });

bool _isSingleGapStraight(List<int> values) =>
    _straightOrders(values).any((ordered) {
      var gaps = 0;
      for (var index = 1; index < ordered.length; index++) {
        final difference = ordered[index] - ordered[index - 1];
        if (difference == 2) {
          gaps++;
        } else if (difference != 1) {
          return false;
        }
      }
      return gaps == 1;
    });

Iterable<List<int>> _straightOrders(List<int> values) sync* {
  // WILDCARD deliberately stores Ace as 15 (there is no rank value 14).
  // Normalize it to 14 for high-Ace adjacency and to 1 for wheel straights.
  final high = values.map((value) => value == 15 ? 14 : value).toList()..sort();
  yield high;
  if (values.contains(15)) {
    final aceLow = values.map((value) => value == 15 ? 1 : value).toList()
      ..sort();
    yield aceLow;
  }
}

int _bitCount(int value) {
  var count = 0;
  var remaining = value;
  while (remaining > 0) {
    count += remaining & 1;
    remaining >>= 1;
  }
  return count;
}

bool _deckHasColorShare(List<PlayingCard> cards, double threshold) {
  if (cards.isEmpty) return false;
  final redCount = cards.where((card) => card.isRed).length;
  final dominantCount = math.max(redCount, cards.length - redCount);
  return dominantCount / cards.length >= threshold;
}

int _ranksWithAtLeastTwoCopies(List<PlayingCard> cards) {
  final counts = <CardRank, int>{};
  for (final card in cards) {
    counts[card.rank] = (counts[card.rank] ?? 0) + 1;
  }
  return counts.values.where((count) => count >= 2).length;
}

int _maxRankCount(List<PlayingCard> cards) {
  final counts = <CardRank, int>{};
  for (final card in cards) {
    counts[card.rank] = (counts[card.rank] ?? 0) + 1;
  }
  return counts.values.fold<int>(0, math.max);
}

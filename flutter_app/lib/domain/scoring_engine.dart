import 'dart:math' as math;

import 'cards.dart';
import 'game_rules.dart';
import 'joker_catalog.dart';
import 'random_streams.dart';

enum ScoreEventType { card, rankJoker, retrigger, seven, mult, xMult }

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

class WildcardScoringEngine {
  WildcardScoringEngine(this.state);

  final ScoringState state;

  List<_EquippedJoker> get _activeJokers => <_EquippedJoker>[
    for (var index = 0; index < state.jokerIds.length; index++)
      if (!state.blockedJokerIds.contains(state.jokerIds[index]) &&
          jokersById.containsKey(state.jokerIds[index]))
        _EquippedJoker(index, jokersById[state.jokerIds[index]]!),
  ];

  bool hasJoker(String id) => state.isJokerActive(id);

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
    final values = cards.map((card) => card.value).toList();
    final counts = <int, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final groups = counts.values.toList()..sort((a, b) => b.compareTo(a));
    final five = cards.length == 5;
    final flushFour =
        cards.length == 4 &&
        (state.hasModifier(HeatModifier.lowCeiling) || hasJoker('pocketflush'));
    final nonWild = cards
        .where((card) => card.enhancement != CardEnhancement.wildsuit)
        .toList();
    final sameSuit =
        nonWild.isEmpty ||
        nonWild.every((card) => card.suit == nonWild.first.suit);
    final flush = (five || flushFour) && sameSuit;

    final unique = values.toSet().toList()..sort();
    var straight = false;
    var royal = false;
    if (five && unique.length == 5) {
      if (unique.last - unique.first == 4) straight = true;
      if (_sameInts(unique, const <int>[10, 11, 12, 13, 15])) {
        straight = true;
        royal = true;
      }
      if (_sameInts(unique, const <int>[2, 3, 4, 5, 15])) straight = true;
    }
    if (cards.length == 4 &&
        state.hasModifier(HeatModifier.lowCeiling) &&
        unique.length == 4) {
      if (unique.last - unique.first == 3 ||
          _sameInts(unique, const <int>[11, 12, 13, 15]) ||
          _sameInts(unique, const <int>[2, 3, 4, 15])) {
        straight = true;
      }
    }
    if (cards.length == 3 && hasJoker('shortcut') && unique.length == 3) {
      if (unique.last - unique.first == 2 ||
          _sameInts(unique, const <int>[12, 13, 15]) ||
          _sameInts(unique, const <int>[2, 3, 15])) {
        straight = true;
      }
    }

    if (straight && flush) {
      return royal ? HandType.royalFlush : HandType.straightFlush;
    }
    if (groups.isNotEmpty && groups[0] == 4) return HandType.fourOfAKind;
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
          state.hasModifier(HeatModifier.frostbite)) {
        final liveCards = cards
            .where((card) => !_rankSuppressed(card))
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
        type == HandType.fourOfAKind) {
      final counts = <int, int>{};
      for (final card in cards) {
        counts[card.value] = (counts[card.value] ?? 0) + 1;
      }
      return cards.where((card) => counts[card.value]! >= 2).toSet();
    }
    return cards.toSet();
  }

  int cardEffectiveRankForScoring(PlayingCard card) {
    if (_rankSuppressed(card)) return 0;
    var value = card.value;
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
    return value;
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

    for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
      final card = cards[cardIndex];
      final scores = analyzed.scoringCards.contains(card);
      flags.add(scores);
      if (!scores) {
        perCard.add(0);
        continue;
      }
      var value = 0;
      if (!_rankSuppressed(card)) {
        value = card.value;
        rankSum += card.value;
        events.add(
          ScoreEvent(
            type: ScoreEventType.card,
            cardIndex: cardIndex,
            amount: card.value,
            label: '+${card.value}',
          ),
        );
        for (final joker in _activeJokers) {
          final bonus = _rankBonus(joker.definition.effect, card);
          if (bonus != 0) {
            value += bonus;
            rankSum += bonus;
            events.add(
              ScoreEvent(
                type: ScoreEventType.rankJoker,
                cardIndex: cardIndex,
                jokerIndex: joker.index,
                amount: bonus,
                label: '+$bonus Rank',
              ),
            );
          }
        }
        if (card.enhancement == CardEnhancement.gild) {
          value += 8;
          rankSum += 8;
          events.add(
            ScoreEvent(
              type: ScoreEventType.card,
              cardIndex: cardIndex,
              amount: 8,
              label: 'GILD +8',
            ),
          );
        }
      } else {
        events.add(
          ScoreEvent(
            type: ScoreEventType.card,
            cardIndex: cardIndex,
            label: '0',
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
    final base = state.handBase(analyzed.type);
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

  /// Applies the post-score stateful hooks from the v7.1.0 client.
  void applyOnScored(ScoreResult result) {
    if (hasJoker('trainer') && result.handType != HandType.highCard) {
      state.jokerState['trainer'] = (state.jokerState['trainer'] ?? 0) + 0.05;
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

  bool _rankSuppressed(PlayingCard card) =>
      (state.hasModifier(HeatModifier.heartless) &&
          card.suit == CardSuit.hearts) ||
      (state.hasModifier(HeatModifier.frostbite) &&
          card.suit == CardSuit.spades) ||
      (state.hasModifier(HeatModifier.counterfeit) && card.copied);

  int _rankBonus(JokerEffect effect, PlayingCard card) => switch (effect) {
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
    JokerEffect.butcher => 0.50 * state.destroyedCount,
    JokerEffect.collector => 0.04 * state.copiedCount,
    JokerEffect.piggyBank => 0.05 * (state.runCoins ~/ 5),
    JokerEffect.heatSurge => 0.20 * state.stagesCleared,
    JokerEffect.cleaner => state.cards.length < 45 ? 0.25 : 0,
    JokerEffect.printer => 0.10 * state.copiedCount,
    JokerEffect.practiceMode =>
      0.15 * state.handLevels.values.where((level) => level > 0).length,
    JokerEffect.openingAct => state.handsPlayedThisStage == 0 ? 0.50 : 0,
    JokerEffect.clutchGear => state.handsLeft == 1 ? 0.60 : 0,
    JokerEffect.coldAdapter => state.hasModifier(HeatModifier.cold) ? 0.30 : 0,
    JokerEffect.encore => state.previousHandType == handType ? 0.30 : 0,
    JokerEffect.colorWash => _allSameColor(played) ? 0.45 : 0,
    _ => 0,
  };

  double _multiplicativeMultiplier(
    JokerEffect effect,
    HandType handType,
    List<PlayingCard> played,
  ) => switch (effect) {
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
    JokerEffect.moddedOut => state.hasAnyModifier ? 1.5 : 1,
    JokerEffect.tailor => _maxRankCount(state.cards) >= 5 ? 1.4 : 1,
    JokerEffect.survivor => state.hasAnyModifier ? 2 : 1,
    JokerEffect.doubleDown => state.previousHandType == handType ? 2 : 1,
    JokerEffect.allIn => state.handsLeft == 1 ? 4 : 0.75,
    JokerEffect.frequencyMeter => _frequencyMeterTriggers(played) ? 1.4 : 1,
    JokerEffect.panicButton => state.discardsLeft == 0 ? 1.4 : 1,
    JokerEffect.stormHarness => state.hasAnyModifier ? 1.4 : 1,
    JokerEffect.guillotine => state.cards.length < 42 ? 1.5 : 1,
    JokerEffect.redline => state.stageScore >= state.target * 0.55 ? 2.5 : 1,
    JokerEffect.masterClass =>
      math.pow(1.15, state.handLevels[handType] ?? 0).toDouble(),
    JokerEffect.dangerMusic =>
      math.pow(1.35, math.max(0, state.handsPlayedThisStage)).toDouble(),
    JokerEffect.rehearsalTape => state.handsPlayedThisStage == 0 ? 1.3 : 1,
    JokerEffect.prismLens => _fiveShareColor(played) ? 1.35 : 1,
    JokerEffect.glassJoystick => 3,
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

int _maxRankCount(List<PlayingCard> cards) {
  final counts = <CardRank, int>{};
  for (final card in cards) {
    counts[card.rank] = (counts[card.rank] ?? 0) + 1;
  }
  return counts.values.fold<int>(0, math.max);
}

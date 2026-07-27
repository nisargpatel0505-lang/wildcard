import 'dart:math' as math;

import 'cards.dart';
import 'deck_integrity.dart';
import 'economy.dart';
import 'game_rules.dart';
import 'joker_catalog.dart';
import 'random_streams.dart';
import 'scoring_engine.dart';

/// Deterministic policies used to stress the real scoring/economy rules.
///
/// These are deliberately described as policies rather than "players": even
/// the stronger policies can only approximate human planning. Keeping several
/// distinct policies is important because a single greedy bot can make a
/// healthy build look artificially weak (or strong).
enum SimulationStrategy {
  randomLegal,
  handRanking,
  adaptive,
  pairBuilder,
  flushBuilder,
}

class SimulationConfig {
  const SimulationConfig({
    required this.runs,
    this.firstSeed = 1,
    this.strategy = SimulationStrategy.handRanking,
    this.mode = RunMode.normal,
    this.difficulty = RunDifficulty.medium,
    this.maxHeat = 12,
    this.initialJokers = const <String>['copper', 'polish'],
    this.allJokersUnlocked = true,
    this.continueEndless = false,
    this.bossBlockedJokers,
    this.bossTargetMultiplier,
  });

  final int runs;
  final int firstSeed;
  final SimulationStrategy strategy;
  final RunMode mode;
  final RunDifficulty difficulty;
  final int maxHeat;
  final List<String> initialJokers;
  final bool allJokersUnlocked;

  /// Continue a Normal run after Heat 12 instead of banking the victory.
  ///
  /// This is explicit so existing 12-Heat balance tests keep their original
  /// meaning when [maxHeat] is raised for an Endless stress cohort.
  final bool continueEndless;

  /// Simulation-only THE HOUSE sensitivity knobs.
  ///
  /// Null means the production rule (two random blocked Jokers and a 1.10x
  /// target). These values never flow into the live controller or saved runs.
  final int? bossBlockedJokers;
  final double? bossTargetMultiplier;
}

class SimulatedRunResult {
  const SimulatedRunResult({
    required this.seed,
    required this.heatsCleared,
    required this.terminalHeat,
    required this.won,
    required this.totalScore,
    required this.handsPlayed,
    required this.discardsUsed,
    required this.finalRunCoins,
    required this.finalDeckSize,
    required this.finalJokers,
    required this.shopsVisited,
    required this.jokersBought,
    required this.suppliesBought,
    required this.modifierSlotsFaced,
    required this.bossHeatsFaced,
    required this.bossBlockedJokerSlots,
    required this.bossTargetTotal,
    required this.jokerTriggerEvents,
    required this.handsWithJokerTrigger,
    required this.handTypeCounts,
    required this.invariantFailures,
  });

  final int seed;
  final int heatsCleared;
  final int terminalHeat;
  final bool won;
  final int totalScore;
  final int handsPlayed;
  final int discardsUsed;
  final int finalRunCoins;
  final int finalDeckSize;
  final List<String> finalJokers;
  final int shopsVisited;
  final int jokersBought;
  final Map<SupplyId, int> suppliesBought;
  final int modifierSlotsFaced;
  final int bossHeatsFaced;
  final int bossBlockedJokerSlots;
  final int bossTargetTotal;
  final int jokerTriggerEvents;
  final int handsWithJokerTrigger;
  final Map<HandType, int> handTypeCounts;
  final List<String> invariantFailures;

  Map<String, Object?> toJson() => <String, Object?>{
    'seed': seed,
    'heatsCleared': heatsCleared,
    'terminalHeat': terminalHeat,
    'won': won,
    'totalScore': totalScore,
    'handsPlayed': handsPlayed,
    'discardsUsed': discardsUsed,
    'finalRunCoins': finalRunCoins,
    'finalDeckSize': finalDeckSize,
    'finalJokers': finalJokers,
    'shopsVisited': shopsVisited,
    'jokersBought': jokersBought,
    'suppliesBought': <String, int>{
      for (final entry in suppliesBought.entries) entry.key.name: entry.value,
    },
    'modifierSlotsFaced': modifierSlotsFaced,
    'bossHeatsFaced': bossHeatsFaced,
    'bossBlockedJokerSlots': bossBlockedJokerSlots,
    'bossTargetTotal': bossTargetTotal,
    'jokerTriggerEvents': jokerTriggerEvents,
    'handsWithJokerTrigger': handsWithJokerTrigger,
    'handTypeCounts': <String, int>{
      for (final entry in handTypeCounts.entries)
        entry.key.legacyName: entry.value,
    },
    'invariantFailures': invariantFailures,
  };
}

class SimulationBatchReport {
  SimulationBatchReport(this.config, List<SimulatedRunResult> results)
    : results = List<SimulatedRunResult>.unmodifiable(results);

  final SimulationConfig config;
  final List<SimulatedRunResult> results;

  int get wins => results.where((result) => result.won).length;
  double get winRate => results.isEmpty ? 0 : wins / results.length;
  int get invariantFailureCount => results.fold<int>(
    0,
    (total, result) => total + result.invariantFailures.length,
  );
  double get averageHeatsCleared => results.isEmpty
      ? 0
      : results.fold<int>(0, (sum, result) => sum + result.heatsCleared) /
            results.length;
  double get averageScore => results.isEmpty
      ? 0
      : results.fold<int>(0, (sum, result) => sum + result.totalScore) /
            results.length;

  double get averageShopsVisited => _average((result) => result.shopsVisited);
  double get averageJokersBought => _average((result) => result.jokersBought);
  double get averageSuppliesBought => _average(
    (result) => result.suppliesBought.values.fold<int>(0, (a, b) => a + b),
  );
  double get averageModifierSlotsFaced =>
      _average((result) => result.modifierSlotsFaced);
  double get averageBossHeatsFaced =>
      _average((result) => result.bossHeatsFaced);
  double get averageBossBlockedJokerSlots =>
      _average((result) => result.bossBlockedJokerSlots);
  double get averageBossTargetWhenFaced {
    final bossHeats = results.fold<int>(
      0,
      (sum, result) => sum + result.bossHeatsFaced,
    );
    if (bossHeats == 0) return 0;
    return results.fold<int>(0, (sum, result) => sum + result.bossTargetTotal) /
        bossHeats;
  }

  double get averageJokerTriggersPerHand {
    final hands = results.fold<int>(
      0,
      (sum, result) => sum + result.handsPlayed,
    );
    if (hands == 0) return 0;
    return results.fold<int>(
          0,
          (sum, result) => sum + result.jokerTriggerEvents,
        ) /
        hands;
  }

  double get jokerActiveHandRate {
    final hands = results.fold<int>(
      0,
      (sum, result) => sum + result.handsPlayed,
    );
    if (hands == 0) return 0;
    return results.fold<int>(
          0,
          (sum, result) => sum + result.handsWithJokerTrigger,
        ) /
        hands;
  }

  double _average(int Function(SimulatedRunResult result) read) =>
      results.isEmpty
      ? 0
      : results.fold<int>(0, (sum, result) => sum + read(result)) /
            results.length;

  Map<int, int> get terminalHeatHistogram {
    final histogram = <int, int>{};
    for (final result in results) {
      histogram[result.terminalHeat] =
          (histogram[result.terminalHeat] ?? 0) + 1;
    }
    return Map<int, int>.fromEntries(
      histogram.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
  }

  int percentileHeatsCleared(double percentile) {
    if (results.isEmpty) return 0;
    final sorted = results.map((result) => result.heatsCleared).toList()
      ..sort();
    final index = ((sorted.length - 1) * percentile.clamp(0, 1)).round();
    return sorted[index];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'runs': results.length,
    'strategy': config.strategy.name,
    'mode': config.mode.name,
    'difficulty': config.difficulty.name,
    'maxHeat': config.maxHeat,
    'continueEndless': config.continueEndless,
    'bossBlockedJokers': config.bossBlockedJokers,
    'bossTargetMultiplier': config.bossTargetMultiplier,
    'initialJokers': config.initialJokers,
    'allJokersUnlocked': config.allJokersUnlocked,
    'wins': wins,
    'winRate': winRate,
    'averageHeatsCleared': averageHeatsCleared,
    'medianHeatsCleared': percentileHeatsCleared(0.5),
    'p90HeatsCleared': percentileHeatsCleared(0.9),
    'averageScore': averageScore,
    'averageShopsVisited': averageShopsVisited,
    'averageJokersBought': averageJokersBought,
    'averageSuppliesBought': averageSuppliesBought,
    'averageModifierSlotsFaced': averageModifierSlotsFaced,
    'averageBossHeatsFaced': averageBossHeatsFaced,
    'averageBossBlockedJokerSlots': averageBossBlockedJokerSlots,
    'averageBossTargetWhenFaced': averageBossTargetWhenFaced,
    'averageJokerTriggersPerHand': averageJokerTriggersPerHand,
    'jokerActiveHandRate': jokerActiveHandRate,
    'terminalHeatHistogram': <String, int>{
      for (final entry in terminalHeatHistogram.entries)
        '${entry.key}': entry.value,
    },
    'invariantFailures': invariantFailureCount,
  };
}

class WildcardSimulationHarness {
  const WildcardSimulationHarness();

  SimulationBatchReport runBatch(SimulationConfig config) {
    if (config.runs < 1) throw ArgumentError.value(config.runs, 'runs');
    if (config.maxHeat < 1) {
      throw ArgumentError.value(config.maxHeat, 'maxHeat');
    }
    if (config.continueEndless && config.mode != RunMode.normal) {
      throw ArgumentError.value(
        config.mode,
        'mode',
        'Only Normal runs can continue into Endless',
      );
    }
    if (config.bossBlockedJokers case final blocked?) {
      if (blocked < 0 || blocked > maxJokers) {
        throw ArgumentError.value(blocked, 'bossBlockedJokers');
      }
    }
    if (config.bossTargetMultiplier case final multiplier?) {
      if (!multiplier.isFinite || multiplier <= 0) {
        throw ArgumentError.value(multiplier, 'bossTargetMultiplier');
      }
    }
    final results = <SimulatedRunResult>[];
    for (var index = 0; index < config.runs; index++) {
      results.add(_RunSimulation(config, config.firstSeed + index).run());
    }
    return SimulationBatchReport(config, results);
  }
}

class _RunSimulation {
  _RunSimulation(this.config, this.seed)
    : strategyRandom = _StrategyRandom(seed ^ 0x6D2B79F5),
      state = ScoringState(
        rngSeed: seed,
        mode: config.mode,
        difficulty: config.difficulty,
        jokerIds: config.initialJokers
            .where(jokersById.containsKey)
            .take(maxJokers)
            .toList(),
      ),
      supplyLedger = SupplyPurchaseLedger();

  final SimulationConfig config;
  final int seed;
  final _StrategyRandom strategyRandom;
  final ScoringState state;
  final SupplyPurchaseLedger supplyLedger;
  final List<String> failures = <String>[];
  final Map<HandType, int> handTypeCounts = <HandType, int>{};
  var totalScore = 0;
  var totalHands = 0;
  var totalDiscards = 0;
  var wildMissShops = 0;
  var shopsVisited = 0;
  var jokersBought = 0;
  var modifierSlotsFaced = 0;
  var bossHeatsFaced = 0;
  var bossBlockedJokerSlots = 0;
  var bossTargetTotal = 0;
  var jokerTriggerEvents = 0;
  var handsWithJokerTrigger = 0;
  final Map<SupplyId, int> suppliesBought = <SupplyId, int>{};
  List<PlayingCard>? _cachedHand;
  List<_ScoredPlay>? _cachedScoredPlays;
  List<PlayingCard>? _cachedBestPlay;

  SimulatedRunResult run() {
    normalizeDeckIntegrity(state.cards);
    var won = false;
    while (state.stage <= config.maxHeat) {
      final cleared = _playHeat();
      _checkInvariants('Heat ${state.stage} terminal');
      if (!cleared) break;
      state.stagesCleared++;
      final completed = _completionReached();
      _applyClearEconomyAndShop(includeShop: !completed);
      if (completed) {
        won = true;
        break;
      }
      state.stage++;
      state.stageScore = 0;
      state.previousHandType = null;
    }
    return SimulatedRunResult(
      seed: seed,
      heatsCleared: state.stagesCleared,
      terminalHeat: state.stage,
      won: won,
      totalScore: totalScore,
      handsPlayed: totalHands,
      discardsUsed: totalDiscards,
      finalRunCoins: state.runCoins,
      finalDeckSize: state.cards.length,
      finalJokers: List<String>.unmodifiable(state.jokerIds),
      shopsVisited: shopsVisited,
      jokersBought: jokersBought,
      suppliesBought: Map<SupplyId, int>.unmodifiable(suppliesBought),
      modifierSlotsFaced: modifierSlotsFaced,
      bossHeatsFaced: bossHeatsFaced,
      bossBlockedJokerSlots: bossBlockedJokerSlots,
      bossTargetTotal: bossTargetTotal,
      jokerTriggerEvents: jokerTriggerEvents,
      handsWithJokerTrigger: handsWithJokerTrigger,
      handTypeCounts: Map<HandType, int>.unmodifiable(handTypeCounts),
      invariantFailures: List<String>.unmodifiable(failures),
    );
  }

  bool _completionReached() {
    if (config.mode == RunMode.gauntlet) {
      return state.stagesCleared >= gauntletHeats;
    }
    if (config.continueEndless) {
      return state.stagesCleared >= config.maxHeat;
    }
    return state.stagesCleared >= 12;
  }

  bool _playHeat() {
    state.endless = state.stage > 12;
    ModifierSelector(state).assignForCurrentHeat();
    modifierSlotsFaced += state.modifiers.length;
    if (state.hasBossModifier) bossHeatsFaced++;
    final engine = WildcardScoringEngine(state);
    engine.ensureBossBlocks();
    _applyBossBlockOverride();
    engine.prepareHeatJokerState();
    if (state.hasBossModifier) {
      bossBlockedJokerSlots += state.blockedJokerIds.length;
      bossTargetTotal += _target;
    }
    state.handsLeft = state.effectiveHandsPerHeat;
    state.discardsLeft = state.effectiveDiscards;
    state.handsPlayedThisStage = 0;
    state.stageScore = 0;

    final heatDeck = _shuffledHeatDeck();
    final hand = <PlayingCard>[];
    _refillHand(hand, heatDeck);

    while (state.handsLeft > 0 && hand.isNotEmpty) {
      state.deckCardsLeft = heatDeck.length;
      var discardGuard = 0;
      while (state.discardsLeft > 0 && discardGuard++ < discardsPerHeat) {
        final discard = _chooseDiscard(hand, heatDeck, engine);
        if (discard.isEmpty) break;
        for (final card in discard) {
          hand.remove(card);
        }
        state.discardsLeft--;
        totalDiscards++;
        _refillHand(hand, heatDeck);
        state.deckCardsLeft = heatDeck.length;
        _clearPlayCache();
      }

      final selected = _choosePlay(hand, heatDeck, engine);
      if (selected.isEmpty || selected.length > state.effectiveMaxSelect) {
        failures.add('Heat ${state.stage}: strategy returned illegal play');
        return false;
      }
      state.deckCardsLeft = heatDeck.length;
      final result = engine.scoreHand(selected, commit: true);
      if (result.total < 0 || !result.multiplier.isFinite) {
        failures.add('Heat ${state.stage}: invalid score ${result.total}');
        return false;
      }
      state.stageScore += result.total;
      totalScore += result.total;
      totalHands++;
      handTypeCounts[result.handType] =
          (handTypeCounts[result.handType] ?? 0) + 1;
      final triggerCount = result.events
          .where((event) => (event.jokerIndex ?? -1) >= 0)
          .length;
      jokerTriggerEvents += triggerCount;
      if (triggerCount > 0) handsWithJokerTrigger++;
      state.handsLeft--;
      state.handsPlayedThisStage++;
      engine.applyOnScored(result);
      engine.resolveGlassCardShatters(selected, result.scoringFlags);
      for (final card in selected) {
        hand.remove(card);
      }
      _refillHand(hand, heatDeck);
      _clearPlayCache();
      _checkInvariants('Heat ${state.stage}, hand $totalHands');
      if (state.stageScore >= _target) return true;
    }
    return state.stageScore >= _target;
  }

  int get _target {
    final override = config.bossTargetMultiplier;
    if (override == null || !state.hasBossModifier) return state.target;
    final saved = List<HeatModifier>.from(state.modifiers);
    state.setModifiers(
      saved.where((modifier) => modifier != HeatModifier.theHouse),
    );
    final targetWithoutBoss = state.target;
    state.setModifiers(saved);
    return (targetWithoutBoss * override).round();
  }

  void _applyBossBlockOverride() {
    final requested = config.bossBlockedJokers;
    if (requested == null || !state.hasBossModifier) return;
    final equipped = state.jokerIds.toSet().toList(growable: false);
    final wanted = math.min(requested, equipped.length);
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
  }

  List<PlayingCard> _shuffledHeatDeck() {
    final deck = <PlayingCard>[
      for (final card in state.cards)
        card.copyWith(selected: false, isNew: false),
    ];
    for (var index = deck.length - 1; index > 0; index--) {
      final other = (state.nextRandom(RandomStream.deck) * (index + 1)).floor();
      final temporary = deck[index];
      deck[index] = deck[other];
      deck[other] = temporary;
    }
    return deck;
  }

  void _refillHand(List<PlayingCard> hand, List<PlayingCard> deck) {
    while (hand.length < state.effectiveHandSize && deck.isNotEmpty) {
      hand.add(deck.removeLast());
    }
  }

  List<PlayingCard> _chooseDiscard(
    List<PlayingCard> hand,
    List<PlayingCard> heatDeck,
    WildcardScoringEngine engine,
  ) {
    if (config.strategy == SimulationStrategy.randomLegal) {
      if (strategyRandom.nextDouble() >= 0.28) return const <PlayingCard>[];
      final count = 1 + strategyRandom.nextInt(math.min(3, hand.length));
      return _randomCards(hand, count);
    }
    if (state.discardsLeft <= 0) {
      return const <PlayingCard>[];
    }
    if (config.strategy == SimulationStrategy.adaptive) {
      return _chooseAdaptiveDiscard(hand, heatDeck, engine);
    }

    final best = _bestRankedPlay(hand, engine);
    final type = engine.evaluateHand(best);

    if (config.strategy == SimulationStrategy.handRanking &&
        type != HandType.highCard) {
      return const <PlayingCard>[];
    }

    final immediate = engine.scoreHand(best, commit: false).total;
    final remaining = math.max(1, _target - state.stageScore);
    final strongEnough = immediate >= (remaining * 0.62).round();
    if (type.index >= HandType.straight.index || strongEnough) {
      return const <PlayingCard>[];
    }

    final candidates = switch (config.strategy) {
      SimulationStrategy.pairBuilder => _pairDiscardCandidates(hand),
      SimulationStrategy.flushBuilder => _flushDiscardCandidates(hand),
      _ => _adaptiveDiscardCandidates(hand, best),
    };
    if (candidates.isEmpty) return const <PlayingCard>[];
    return candidates.take(math.min(3, candidates.length)).toList();
  }

  List<PlayingCard> _chooseAdaptiveDiscard(
    List<PlayingCard> hand,
    List<PlayingCard> heatDeck,
    WildcardScoringEngine engine,
  ) {
    if (heatDeck.isEmpty) return const <PlayingCard>[];

    final benchmark = _bestDiscardBenchmarkPlay(hand, engine);
    final bestPlay = benchmark.cards;
    final bestResult = benchmark.result;
    final immediate = benchmark.expectedScore;
    final remaining = math.max(1, _target - state.stageScore);
    final pace = remaining / math.max(1, state.handsLeft);
    if (bestResult.total >= remaining) return const <PlayingCard>[];
    if (bestResult.handType.index >= HandType.straight.index &&
        immediate >= pace * 0.82) {
      return const <PlayingCard>[];
    }

    final maxDiscard = math.min(
      state.effectiveMaxSelect,
      math.min(hand.length - 1, heatDeck.length),
    );
    if (maxDiscard < 1) return const <PlayingCard>[];

    final baseline = _projectedHandPotential(hand, heatDeck, 0, engine);
    final plans = _adaptiveDiscardPlans(hand, bestPlay, maxDiscard, engine);
    List<PlayingCard>? selected;
    var selectedValue = baseline;
    var selectedPotential = baseline;

    for (final plan in plans) {
      final kept = hand
          .where((card) => !plan.contains(card))
          .toList(growable: false);
      final potential = _projectedHandPotential(
        kept,
        heatDeck,
        plan.length,
        engine,
      );
      var resourceCost =
          plan.length * 0.9 +
          (state.discardsLeft <= state.handsLeft ? 3.5 : 1.5);
      if (state.isJokerActive('dumpster')) resourceCost -= 2.5;
      if (state.isJokerActive('panic_button') ||
          state.isJokerActive('high_wire')) {
        resourceCost -= state.discardsLeft <= 2 ? 3.0 : 1.0;
      }
      if (heatDeck.length < state.effectiveHandSize) {
        resourceCost += plan.length * 1.5;
      }
      final value = potential - math.max(0, resourceCost);
      if (value > selectedValue + 0.001 ||
          ((value - selectedValue).abs() < 0.001 &&
              plan.length < (selected?.length ?? 99))) {
        selected = plan;
        selectedValue = value;
        selectedPotential = potential;
      }
    }

    if (selected == null) return const <PlayingCard>[];
    final behindPace = immediate < pace * 0.88;
    var requiredGain = behindPace ? 1.5 : 7.0;
    if (bestResult.handType == HandType.highCard) requiredGain -= 2.0;
    if (state.discardsLeft == 1 && state.handsLeft > 1) requiredGain += 3.0;
    if (selectedPotential < baseline + requiredGain) {
      return const <PlayingCard>[];
    }
    return selected;
  }

  _ScoredPlay _bestDiscardBenchmarkPlay(
    List<PlayingCard> hand,
    WildcardScoringEngine engine,
  ) {
    final candidates = <List<PlayingCard>>[];
    final seen = <String>{};
    final handIndex = <PlayingCard, int>{
      for (var index = 0; index < hand.length; index++) hand[index]: index,
    };

    void add(Iterable<PlayingCard> source) {
      final cards = source.toSet().toList()
        ..sort((left, right) => handIndex[left]!.compareTo(handIndex[right]!));
      if (cards.isEmpty || cards.length > state.effectiveMaxSelect) return;
      final key = cards.map((card) => handIndex[card]).join(',');
      if (seen.add(key)) candidates.add(cards);
    }

    final byRank = <CardRank, List<PlayingCard>>{
      for (final rank in CardRank.values)
        rank: hand.where((card) => card.rank == rank).toList(),
    };
    final bySuit = <CardSuit, List<PlayingCard>>{
      for (final suit in CardSuit.values)
        suit: hand
            .where(
              (card) =>
                  card.suit == suit ||
                  card.enhancement == CardEnhancement.wildsuit,
            )
            .toList(),
    };
    final byStrength = List<PlayingCard>.from(hand)
      ..sort(
        (left, right) => engine
            .cardEffectiveRankForScoring(right)
            .compareTo(engine.cardEffectiveRankForScoring(left)),
      );
    for (final card in hand) {
      add(<PlayingCard>[card]);
    }
    for (
      var size = 2;
      size <= math.min(state.effectiveMaxSelect, hand.length);
      size++
    ) {
      add(byStrength.take(size));
    }
    final rankGroups =
        byRank.values.where((cards) => cards.length >= 2).toList()
          ..sort((left, right) {
            final size = right.length.compareTo(left.length);
            if (size != 0) return size;
            return right.first.value.compareTo(left.first.value);
          });
    for (final group in rankGroups) {
      add(group.take(state.effectiveMaxSelect));
    }
    if (rankGroups.length >= 2) {
      add(
        <PlayingCard>[
          ...rankGroups[0],
          ...rankGroups[1],
        ].take(state.effectiveMaxSelect),
      );
      for (final trips in rankGroups.where((cards) => cards.length >= 3)) {
        for (final pair in rankGroups.where((cards) => cards != trips)) {
          add(<PlayingCard>[...trips.take(3), ...pair.take(2)]);
        }
      }
    }
    for (final suited in bySuit.values) {
      if (suited.length < 3) continue;
      suited.sort(
        (left, right) => engine
            .cardEffectiveRankForScoring(right)
            .compareTo(engine.cardEffectiveRankForScoring(left)),
      );
      add(suited.take(math.min(state.effectiveMaxSelect, suited.length)));
    }
    for (final window in _straightRankWindows(_straightRequirement)) {
      final straight = <PlayingCard>[];
      for (final rank in window) {
        final options = byRank[rank]!;
        if (options.isEmpty) continue;
        options.sort(
          (left, right) => engine
              .cardEffectiveRankForScoring(right)
              .compareTo(engine.cardEffectiveRankForScoring(left)),
        );
        straight.add(options.first);
      }
      if (straight.length == window.length) add(straight);
    }

    final scored = <_ScoredPlay>[
      for (final cards in candidates) _scoreCandidatePlay(cards, engine),
    ]..sort(_compareScoredPlays);
    return scored.first;
  }

  _ScoredPlay _scoreCandidatePlay(
    List<PlayingCard> cards,
    WildcardScoringEngine engine,
  ) {
    final result = engine.scoreHand(cards, commit: false);
    return _ScoredPlay(
      List<PlayingCard>.unmodifiable(cards),
      result,
      _expectedPlayScore(cards, result, engine),
    );
  }

  List<List<PlayingCard>> _adaptiveDiscardPlans(
    List<PlayingCard> hand,
    List<PlayingCard> bestPlay,
    int maxDiscard,
    WildcardScoringEngine engine,
  ) {
    final result = <List<PlayingCard>>[];
    final seen = <String>{};
    final handIndex = <PlayingCard, int>{
      for (var index = 0; index < hand.length; index++) hand[index]: index,
    };
    final rankCounts = <CardRank, int>{};
    final suitCounts = <CardSuit, int>{};
    for (final card in hand) {
      rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }

    void addPlan(Iterable<PlayingCard> source) {
      final ordered = source.toSet().where(handIndex.containsKey).toList()
        ..sort((left, right) {
          final utility = _cardKeepUtility(
            left,
            engine,
            rankCounts,
            suitCounts,
          ).compareTo(_cardKeepUtility(right, engine, rankCounts, suitCounts));
          if (utility != 0) return utility;
          return handIndex[left]!.compareTo(handIndex[right]!);
        });
      final plan = ordered.take(maxDiscard).toList()
        ..sort((left, right) => handIndex[left]!.compareTo(handIndex[right]!));
      if (plan.isEmpty) return;
      final key = plan.map((card) => handIndex[card]).join(',');
      if (seen.add(key)) result.add(plan);
    }

    final weakest = List<PlayingCard>.from(hand)
      ..sort((left, right) {
        final utility = _cardKeepUtility(
          left,
          engine,
          rankCounts,
          suitCounts,
        ).compareTo(_cardKeepUtility(right, engine, rankCounts, suitCounts));
        if (utility != 0) return utility;
        return handIndex[left]!.compareTo(handIndex[right]!);
      });
    final weakPool = weakest.take(math.min(6, weakest.length)).toList();
    for (
      var count = 1;
      count <= math.min(maxDiscard, weakPool.length);
      count++
    ) {
      for (final plan in _combinations(weakPool, count)) {
        addPlan(plan);
      }
    }

    addPlan(hand.where((card) => !bestPlay.contains(card)));
    for (final rank in CardRank.values) {
      if ((rankCounts[rank] ?? 0) < 2) continue;
      addPlan(hand.where((card) => card.rank != rank));
    }
    for (final suit in CardSuit.values) {
      if ((suitCounts[suit] ?? 0) < 2) continue;
      addPlan(
        hand.where(
          (card) =>
              card.suit != suit && card.enhancement != CardEnhancement.wildsuit,
        ),
      );
    }
    for (final red in const <bool>[true, false]) {
      addPlan(
        hand.where(
          (card) =>
              card.isRed != red && card.enhancement != CardEnhancement.wildsuit,
        ),
      );
    }
    final straightSize = _straightRequirement;
    for (final window in _straightRankWindows(straightSize)) {
      if (hand.where((card) => window.contains(card.rank)).length < 2) {
        continue;
      }
      addPlan(hand.where((card) => !window.contains(card.rank)));
    }
    return result;
  }

  List<PlayingCard> _adaptiveDiscardCandidates(
    List<PlayingCard> hand,
    List<PlayingCard> best,
  ) {
    final protected = best.toSet();
    final rankCounts = <CardRank, int>{};
    final suitCounts = <CardSuit, int>{};
    for (final card in hand) {
      rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }
    return hand.where((card) => !protected.contains(card)).toList()
      ..sort((left, right) {
        final leftValue = _drawUtility(left, rankCounts, suitCounts);
        final rightValue = _drawUtility(right, rankCounts, suitCounts);
        return leftValue.compareTo(rightValue);
      });
  }

  List<PlayingCard> _pairDiscardCandidates(List<PlayingCard> hand) {
    final rankCounts = <CardRank, int>{};
    for (final card in hand) {
      rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
    }
    final candidates =
        hand.where((card) => (rankCounts[card.rank] ?? 0) == 1).toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    return candidates;
  }

  List<PlayingCard> _flushDiscardCandidates(List<PlayingCard> hand) {
    final suitCounts = <CardSuit, int>{
      for (final suit in CardSuit.values)
        suit: hand.where((card) => card.suit == suit).length,
    };
    final dominantSuit = CardSuit.values.reduce(
      (left, right) => suitCounts[right]! > suitCounts[left]! ? right : left,
    );
    final candidates = hand.where((card) => card.suit != dominantSuit).toList()
      ..sort((left, right) => left.value.compareTo(right.value));
    return candidates;
  }

  int _drawUtility(
    PlayingCard card,
    Map<CardRank, int> rankCounts,
    Map<CardSuit, int> suitCounts,
  ) {
    final duplicate = (rankCounts[card.rank] ?? 0) * 24;
    final suit = (suitCounts[card.suit] ?? 0) * 6;
    return duplicate + suit + card.value;
  }

  double _cardKeepUtility(
    PlayingCard card,
    WildcardScoringEngine engine,
    Map<CardRank, int> rankCounts,
    Map<CardSuit, int> suitCounts,
  ) {
    var value = engine.cardEffectiveRankForScoring(card).toDouble();
    value += math.max(0, (rankCounts[card.rank] ?? 0) - 1) * 22;
    value += math.max(0, (suitCounts[card.suit] ?? 0) - 1) * 3.5;
    value += switch (card.enhancement) {
      CardEnhancement.gild => 8,
      CardEnhancement.neon => 10,
      CardEnhancement.glass => 14,
      CardEnhancement.wildsuit => 12,
      null => 0,
    };
    if (state.isJokerActive('couple') &&
        (card.rank == CardRank.ace || card.rank == CardRank.king)) {
      value += 14;
    }
    if (state.isJokerActive('face_value') &&
        const <CardRank>{
          CardRank.jack,
          CardRank.queen,
          CardRank.king,
        }.contains(card.rank)) {
      value += 8;
    }
    if (state.isJokerActive('ace_in_the_hole') && card.rank == CardRank.ace) {
      value += 10;
    }
    if (state.isJokerActive('lucky7') && card.rank == CardRank.seven) {
      value += 15;
    }
    return value;
  }

  int get _straightRequirement {
    if (state.isJokerActive('shortcut')) return 3;
    if (state.hasModifier(HeatModifier.lowCeiling)) {
      return 4;
    }
    return 5;
  }

  double _projectedHandPotential(
    List<PlayingCard> kept,
    List<PlayingCard> unseen,
    int requestedDraws,
    WildcardScoringEngine engine,
  ) {
    final draws = math.min(requestedDraws, unseen.length);
    final population = unseen.length;
    final keptRanks = <CardRank, int>{};
    final unseenRanks = <CardRank, int>{};
    for (final card in kept) {
      keptRanks[card.rank] = (keptRanks[card.rank] ?? 0) + 1;
    }
    for (final card in unseen) {
      unseenRanks[card.rank] = (unseenRanks[card.rank] ?? 0) + 1;
    }

    double reachRank(CardRank rank, int target) {
      final needed = target - (keptRanks[rank] ?? 0);
      return _hypergeometricAtLeast(
        population: population,
        successes: unseenRanks[rank] ?? 0,
        draws: draws,
        needed: needed,
      );
    }

    var pairChance = 0.0;
    var tripsChance = 0.0;
    var quadsChance = 0.0;
    var twoPairChance = 0.0;
    var fullHouseChance = 0.0;
    for (final rank in CardRank.values) {
      pairChance = math.max(pairChance, reachRank(rank, 2));
      tripsChance = math.max(tripsChance, reachRank(rank, 3));
      quadsChance = math.max(quadsChance, reachRank(rank, 4));
    }
    for (var left = 0; left < CardRank.values.length; left++) {
      for (var right = left + 1; right < CardRank.values.length; right++) {
        final leftRank = CardRank.values[left];
        final rightRank = CardRank.values[right];
        twoPairChance = math.max(
          twoPairChance,
          reachRank(leftRank, 2) * reachRank(rightRank, 2),
        );
        fullHouseChance = math.max(
          fullHouseChance,
          math.max(
            reachRank(leftRank, 3) * reachRank(rightRank, 2),
            reachRank(rightRank, 3) * reachRank(leftRank, 2),
          ),
        );
      }
    }

    var flushChance = 0.0;
    final flushSize =
        state.hasModifier(HeatModifier.lowCeiling) ||
            state.isJokerActive('pocketflush')
        ? 4
        : 5;
    for (final suit in CardSuit.values) {
      final held = kept
          .where(
            (card) =>
                card.suit == suit ||
                card.enhancement == CardEnhancement.wildsuit,
          )
          .length;
      final available = unseen
          .where(
            (card) =>
                card.suit == suit ||
                card.enhancement == CardEnhancement.wildsuit,
          )
          .length;
      flushChance = math.max(
        flushChance,
        _hypergeometricAtLeast(
          population: population,
          successes: available,
          draws: draws,
          needed: flushSize - held,
        ),
      );
    }
    if (state.isJokerActive('suit_swap')) {
      flushChance = math.min(1.0, flushChance * 1.35 + 0.08);
    }

    var straightChance = 0.0;
    for (final window in _straightRankWindows(_straightRequirement)) {
      final missing = window
          .where((rank) => (keptRanks[rank] ?? 0) == 0)
          .toList(growable: false);
      straightChance = math.max(
        straightChance,
        _probabilityDrawAllRanks(
          population: population,
          unseenRanks: unseenRanks,
          draws: draws,
          missing: missing,
        ),
      );
    }
    if (state.isJokerActive('gap_filler')) {
      straightChance = math.min(1.0, straightChance * 1.4 + 0.06);
    }

    final expectedHigh = _expectedHighestRank(kept, unseen, draws, engine);
    var best =
        (state.handBase(HandType.highCard) + expectedHigh * rankScale) *
        _handTypeSynergyFactor(HandType.highCard);

    void consider(HandType type, double probability, int scoringCards) {
      if (probability <= 0) return;
      var base = state.handBase(type);
      if (type == HandType.twoPair && state.isJokerActive('two_faced')) {
        base = math.max(base, state.handBase(HandType.fullHouse));
      }
      final estimate =
          (base + expectedHigh * rankScale * scoringCards * 0.72) *
          _handTypeSynergyFactor(type) *
          probability.clamp(0.0, 1.0);
      best = math.max(best, estimate);
    }

    consider(HandType.pair, pairChance, 2);
    consider(HandType.twoPair, twoPairChance, 4);
    consider(HandType.threeOfAKind, tripsChance, 3);
    consider(HandType.straight, straightChance, _straightRequirement);
    consider(HandType.flush, flushChance, flushSize);
    consider(HandType.fullHouse, fullHouseChance, 5);
    consider(HandType.fourOfAKind, quadsChance, 4);
    final straightFlushChance = math.min(straightChance, flushChance) * 0.28;
    consider(
      HandType.straightFlush,
      straightFlushChance,
      math.max(flushSize, _straightRequirement),
    );
    consider(HandType.royalFlush, straightFlushChance * 0.08, 5);

    final enhancementValue = kept.fold<double>(
      0,
      (total, card) =>
          total +
          switch (card.enhancement) {
            CardEnhancement.gild => 2.5,
            CardEnhancement.neon => 4.0,
            CardEnhancement.glass => 7.0,
            CardEnhancement.wildsuit => 3.0,
            null => 0,
          },
    );
    return best + enhancementValue;
  }

  double _handTypeSynergyFactor(HandType type) {
    var result = 1.0;
    if (type != HandType.highCard && state.isJokerActive('polish')) {
      result *= 1.4;
    }
    if (type.legacyName.contains('Flush') && state.isJokerActive('flushfund')) {
      result *= 1.8;
    }
    if (type.legacyName.contains('Straight') && state.isJokerActive('wire')) {
      result *= 1.8;
    }
    if ((state.handLevels[type] ?? 0) > 0 &&
        state.isJokerActive('boostfiend')) {
      result *= 1.3;
    }
    if (state.isJokerActive('master_class')) {
      result *= math.pow(1.15, state.handLevels[type] ?? 0).toDouble();
    }
    if (type == state.previousHandType) {
      if (state.isJokerActive('doubledown')) result *= 2;
      if (state.isJokerActive('encore')) result += 0.2;
      if (state.hasModifier(HeatModifier.echoChamber)) result *= 0.5;
    }
    if (type == HandType.highCard && state.isJokerActive('sniper')) {
      result *= 1.45;
    }
    return result;
  }

  double _expectedHighestRank(
    List<PlayingCard> kept,
    List<PlayingCard> unseen,
    int draws,
    WildcardScoringEngine engine,
  ) {
    var floor = 0;
    for (final card in kept) {
      floor = math.max(floor, engine.cardEffectiveRankForScoring(card));
    }
    if (draws <= 0 || unseen.isEmpty) return floor.toDouble();
    final values = unseen
        .map(engine.cardEffectiveRankForScoring)
        .toList(growable: false);
    final levels = values.toSet().toList()..sort();
    final denominator = _combinationDouble(unseen.length, draws);
    if (denominator <= 0) return floor.toDouble();
    var previousCdf = 0.0;
    var expected = 0.0;
    for (final level in levels) {
      final atMost = values.where((value) => value <= level).length;
      final cdf = _combinationDouble(atMost, draws) / denominator;
      final probability = math.max(0.0, cdf - previousCdf);
      expected += math.max(floor, level) * probability;
      previousCdf = cdf;
    }
    return expected;
  }

  List<PlayingCard> _choosePlay(
    List<PlayingCard> hand,
    List<PlayingCard> heatDeck,
    WildcardScoringEngine engine,
  ) {
    if (config.strategy == SimulationStrategy.randomLegal) {
      final count =
          1 +
          strategyRandom.nextInt(
            math.min(state.effectiveMaxSelect, hand.length),
          );
      return _randomCards(hand, count);
    }
    if (config.strategy == SimulationStrategy.adaptive) {
      return _bestAdaptivePlay(hand, heatDeck, engine);
    }
    return _bestRankedPlay(hand, engine);
  }

  List<PlayingCard> _bestAdaptivePlay(
    List<PlayingCard> hand,
    List<PlayingCard> heatDeck,
    WildcardScoringEngine engine,
  ) {
    final plays = _scoredLegalPlays(hand, engine);
    final remaining = math.max(1, _target - state.stageScore);
    final clearing = plays
        .where((play) => play.result.total >= remaining)
        .toList();
    if (clearing.isNotEmpty) {
      clearing.sort(_compareScoredPlays);
      return List<PlayingCard>.from(clearing.first.cards);
    }
    if (state.handsLeft <= 1) {
      return List<PlayingCard>.from(plays.first.cards);
    }

    final shortlist = <_ScoredPlay>[];
    final seen = <String>{};
    void add(_ScoredPlay play) {
      final key = play.cards.map((card) => hand.indexOf(card)).toList()..sort();
      if (seen.add(key.join(','))) shortlist.add(play);
    }

    for (final play in plays.take(math.min(28, plays.length))) {
      add(play);
    }
    for (var size = 1; size <= state.effectiveMaxSelect; size++) {
      final sameSize = plays.where((play) => play.cards.length == size);
      if (sameSize.isNotEmpty) add(sameSize.first);
    }
    for (final type in HandType.values) {
      final sameType = plays.where((play) => play.result.handType == type);
      if (sameType.isNotEmpty) add(sameType.first);
    }

    final pace = remaining / state.handsLeft;
    final fragileFloor = state.isJokerActive('fragile_genius')
        ? state.jokerState['fragile']
        : null;
    final canPreserveFragile =
        fragileFloor != null &&
        plays.any((play) => play.result.total >= fragileFloor);
    _ScoredPlay selected = plays.first;
    var selectedUtility = double.negativeInfinity;
    for (final play in shortlist) {
      final retained = hand
          .where((card) => !play.cards.contains(card))
          .toList(growable: false);
      final nextPotential = _projectedHandPotential(
        retained,
        heatDeck,
        math.min(play.cards.length, heatDeck.length),
        engine,
      );
      final expected = play.expectedScore;
      final futureWeight = expected >= pace ? 0.34 : 0.16;
      final projected =
          expected + nextPotential * math.max(0, state.handsLeft - 1);
      var utility = expected + nextPotential * futureWeight;
      if (projected < remaining) {
        utility -= (remaining - projected) * 1.8;
      }
      if (expected >= pace) utility += math.min(expected, pace) * 0.08;
      if (state.isJokerActive('trainer') &&
          play.result.handType != HandType.highCard) {
        utility += 3.0;
      }
      if ((state.isJokerActive('doubledown') ||
              state.isJokerActive('encore') ||
              state.isJokerActive('metronome') ||
              state.isJokerActive('perfectionist')) &&
          play.result.handType == state.previousHandType) {
        utility += 2.5;
      }
      if (state.isJokerActive('comboist')) {
        final seenTypes = (state.jokerState['combo'] ?? 0).round();
        if ((seenTypes & (1 << play.result.handType.index)) == 0) {
          utility += 3.0;
        }
      }
      if (canPreserveFragile && play.result.total < fragileFloor) {
        utility -= 10000;
      }
      if (utility > selectedUtility + 0.001 ||
          ((utility - selectedUtility).abs() < 0.001 &&
              _compareScoredPlays(play, selected) < 0)) {
        selected = play;
        selectedUtility = utility;
      }
    }
    return List<PlayingCard>.from(selected.cards);
  }

  List<PlayingCard> _bestRankedPlay(
    List<PlayingCard> hand,
    WildcardScoringEngine engine,
  ) {
    final cached = _cachedHand;
    if (cached != null && _sameCards(cached, hand)) {
      return List<PlayingCard>.from(_cachedBestPlay!);
    }
    _scoredLegalPlays(hand, engine);
    return List<PlayingCard>.from(_cachedBestPlay!);
  }

  List<_ScoredPlay> _scoredLegalPlays(
    List<PlayingCard> hand,
    WildcardScoringEngine engine,
  ) {
    final cached = _cachedHand;
    if (cached != null &&
        _sameCards(cached, hand) &&
        _cachedScoredPlays != null) {
      return _cachedScoredPlays!;
    }
    final plays = <_ScoredPlay>[];
    final limit = math.min(state.effectiveMaxSelect, hand.length);
    for (var size = 1; size <= limit; size++) {
      for (final candidate in _combinations(hand, size)) {
        final result = engine.scoreHand(candidate, commit: false);
        plays.add(
          _ScoredPlay(
            List<PlayingCard>.unmodifiable(candidate),
            result,
            _expectedPlayScore(candidate, result, engine),
          ),
        );
      }
    }
    plays.sort(_compareScoredPlays);
    var immediateBest = plays.first;
    for (final play in plays.skip(1)) {
      if (_compareImmediatePlays(play, immediateBest) < 0) {
        immediateBest = play;
      }
    }
    _cachedHand = List<PlayingCard>.from(hand);
    _cachedScoredPlays = plays;
    _cachedBestPlay = List<PlayingCard>.from(immediateBest.cards);
    return plays;
  }

  int _compareScoredPlays(_ScoredPlay left, _ScoredPlay right) {
    final expected = right.expectedScore.compareTo(left.expectedScore);
    if (expected != 0) return expected;
    final actual = right.result.total.compareTo(left.result.total);
    if (actual != 0) return actual;
    final type = right.result.handType.index.compareTo(
      left.result.handType.index,
    );
    if (type != 0) return type;
    return left.cards.length.compareTo(right.cards.length);
  }

  int _compareImmediatePlays(_ScoredPlay left, _ScoredPlay right) {
    final actual = right.result.total.compareTo(left.result.total);
    if (actual != 0) return actual;
    final type = right.result.handType.index.compareTo(
      left.result.handType.index,
    );
    if (type != 0) return type;
    return left.cards.length.compareTo(right.cards.length);
  }

  double _expectedPlayScore(
    List<PlayingCard> cards,
    ScoreResult result,
    WildcardScoringEngine engine,
  ) {
    if (!state.isJokerActive('lucky7')) return result.total.toDouble();
    var expectedRankBonus = 0.0;
    for (var index = 0; index < cards.length; index++) {
      if (!result.scoringFlags[index] || cards[index].rank != CardRank.seven) {
        continue;
      }
      // Lucky Seven adds nine copies of the effective rank on a one-in-three
      // hit, so three copies is its exact expectation.
      expectedRankBonus += engine.cardEffectiveRankForScoring(cards[index]) * 3;
    }
    return result.total + expectedRankBonus * rankScale * result.multiplier;
  }

  bool _sameCards(List<PlayingCard> left, List<PlayingCard> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!identical(left[index], right[index])) return false;
    }
    return true;
  }

  void _clearPlayCache() {
    _cachedHand = null;
    _cachedScoredPlays = null;
    _cachedBestPlay = null;
  }

  List<PlayingCard> _randomCards(List<PlayingCard> hand, int count) {
    final pool = List<PlayingCard>.from(hand);
    final result = <PlayingCard>[];
    while (result.length < count && pool.isNotEmpty) {
      result.add(pool.removeAt(strategyRandom.nextInt(pool.length)));
    }
    return result;
  }

  void _applyClearEconomyAndShop({required bool includeShop}) {
    final grade = gradeForPlays(state.handsPlayedThisStage);
    final interest = runCoinInterest(state.runCoins);
    state.runCoins += runReward(state.stage) + interest + grade.bonus;
    WildcardScoringEngine(state).applyHeatClearJokerHooks();
    final inflation = state.hasModifier(HeatModifier.inflation);
    if (includeShop) _runShop(inflation: inflation);
  }

  void _runShop({required bool inflation}) {
    shopsVisited++;
    final offers = _rollJokerOffers();
    final buyLimit = shopBuyLimit(
      stage: state.stage,
      endless: state.endless,
      gauntlet: state.isGauntlet,
    );
    for (var purchase = 0; purchase < buyLimit; purchase++) {
      if (config.strategy == SimulationStrategy.adaptive) {
        final plan = _bestAdaptiveJokerPurchase(offers, inflation);
        if (plan == null) break;
        _completeJokerPurchase(plan);
        offers.remove(plan.joker);
        continue;
      }
      final candidates =
          offers.where((joker) => !state.jokerIds.contains(joker.id)).toList()
            ..sort(
              (left, right) =>
                  _jokerPriority(right).compareTo(_jokerPriority(left)),
            );
      if (candidates.isEmpty) break;
      final joker = candidates.first;
      final price = joker.price + (inflation ? 2 : 0);
      var replaceIndex = -1;
      var refund = 0;
      if (state.jokerIds.length >= maxJokers) {
        final rankedCurrent =
            <(int, JokerDefinition)>[
              for (var index = 0; index < state.jokerIds.length; index++)
                if (jokersById[state.jokerIds[index]] case final owned?)
                  (index, owned),
            ]..sort(
              (left, right) =>
                  _jokerPriority(left.$2).compareTo(_jokerPriority(right.$2)),
            );
        if (rankedCurrent.isEmpty ||
            _jokerPriority(joker) <= _jokerPriority(rankedCurrent.first.$2)) {
          break;
        }
        replaceIndex = rankedCurrent.first.$1;
        refund = math.max(1, rankedCurrent.first.$2.price ~/ 2);
      }
      if (state.runCoins + refund < price) break;
      _completeJokerPurchase(
        _JokerPurchasePlan(
          joker: joker,
          replaceIndex: replaceIndex,
          price: price,
          refund: refund,
          gain: 0,
          decisionValue: 0,
        ),
      );
      offers.remove(joker);
    }

    final supplyOffers = _rollSupplyOffers();
    var supplyBuys = 0;
    if (config.strategy == SimulationStrategy.adaptive) {
      while (supplyBuys < 2 && supplyOffers.isNotEmpty) {
        SupplyDefinition? selected;
        var selectedPrice = 0;
        var selectedValue = double.negativeInfinity;
        for (final supply in supplyOffers) {
          final price = supplyPrice(
            supply,
            ledger: supplyLedger,
            inflation: inflation,
          );
          if (state.runCoins < price || !_canApplySupply(supply.id)) continue;
          final value = _adaptiveSupplyValue(supply.id) - price * 1.15;
          final coinsAfter = state.runCoins - price;
          final interestLoss =
              runCoinInterest(state.runCoins) - runCoinInterest(coinsAfter);
          final decisionValue = value - interestLoss * 1.5;
          if (decisionValue > selectedValue + 0.001 ||
              ((decisionValue - selectedValue).abs() < 0.001 &&
                  price < selectedPrice)) {
            selected = supply;
            selectedPrice = price;
            selectedValue = decisionValue;
          }
        }
        if (selected == null || selectedValue < 0) break;
        state.runCoins -= selectedPrice;
        _applySupply(selected.id);
        supplyLedger.record(selected.id, state.stage);
        suppliesBought[selected.id] = (suppliesBought[selected.id] ?? 0) + 1;
        supplyOffers.remove(selected);
        supplyBuys++;
      }
    } else {
      for (final supply in supplyOffers) {
        if (supplyBuys >= 2 || !_shouldBuySupply(supply.id)) continue;
        final price = supplyPrice(
          supply,
          ledger: supplyLedger,
          inflation: inflation,
        );
        if (state.runCoins < price || !_canApplySupply(supply.id)) continue;
        state.runCoins -= price;
        _applySupply(supply.id);
        supplyLedger.record(supply.id, state.stage);
        suppliesBought[supply.id] = (suppliesBought[supply.id] ?? 0) + 1;
        supplyBuys++;
      }
    }
    _checkInvariants('Heat ${state.stage} shop');
  }

  List<JokerDefinition> _rollJokerOffers() {
    final pool = jokerCatalog
        .where(
          (joker) =>
              !state.jokerIds.contains(joker.id) &&
              (config.allJokersUnlocked || joker.starter),
        )
        .toList();
    final count = shopOfferCount(
      stage: state.stage,
      endless: state.endless,
      gauntlet: state.isGauntlet,
    );
    final wildPool = pool
        .where((joker) => joker.rarity == JokerRarity.wild)
        .toList();
    final forceWild =
        wildPool.isNotEmpty && wildMissShops >= wildPityAfterShops;
    final offers = <JokerDefinition>[];
    if (forceWild) {
      final index = (state.nextRandom(RandomStream.shop) * wildPool.length)
          .floor();
      final forced = wildPool[index];
      offers.add(forced);
      pool.remove(forced);
    }
    while (offers.length < count && pool.isNotEmpty) {
      final total = pool.fold<double>(
        0,
        (sum, joker) => sum + shopRarityWeights[joker.rarity]!,
      );
      var roll = state.nextRandom(RandomStream.shop) * total;
      var index = 0;
      for (var candidate = 0; candidate < pool.length; candidate++) {
        roll -= shopRarityWeights[pool[candidate].rarity]!;
        if (roll <= 0) {
          index = candidate;
          break;
        }
      }
      offers.add(pool.removeAt(index));
    }
    if (offers.any((joker) => joker.rarity == JokerRarity.wild)) {
      wildMissShops = 0;
    } else if (wildPool.isNotEmpty) {
      wildMissShops = math.min(wildPityAfterShops, wildMissShops + 1);
    }
    return offers;
  }

  List<SupplyDefinition> _rollSupplyOffers() {
    final pool = List<SupplyDefinition>.from(supplyCatalog);
    final offers = <SupplyDefinition>[];
    while (offers.length < 2 && pool.isNotEmpty) {
      final index = (state.nextRandom(RandomStream.shop) * pool.length).floor();
      offers.add(pool.removeAt(index));
    }
    return offers;
  }

  _JokerPurchasePlan? _bestAdaptiveJokerPurchase(
    List<JokerDefinition> offers,
    bool inflation,
  ) {
    final currentValue = _jokerBuildValue(state.jokerIds);
    _JokerPurchasePlan? selected;
    for (final joker in offers) {
      if (state.jokerIds.contains(joker.id)) continue;
      final price = joker.price + (inflation ? 2 : 0);
      final replacements = state.jokerIds.length < maxJokers
          ? const <int>[-1]
          : List<int>.generate(state.jokerIds.length, (index) => index);
      for (final replaceIndex in replacements) {
        var refund = 0;
        final candidateIds = List<String>.from(state.jokerIds);
        if (replaceIndex >= 0) {
          final removed = jokersById[candidateIds[replaceIndex]];
          if (removed == null) continue;
          refund = math.max(1, removed.price ~/ 2);
          candidateIds[replaceIndex] = joker.id;
        } else {
          candidateIds.add(joker.id);
        }
        if (state.runCoins + refund < price) continue;

        final gain = _jokerBuildValue(candidateIds) - currentValue;
        final minimumGain = replaceIndex < 0 ? 4.0 : 5.5;
        if (gain < minimumGain) continue;
        final coinsAfter = state.runCoins + refund - price;
        final interestLoss =
            runCoinInterest(state.runCoins) - runCoinInterest(coinsAfter);
        final netPrice = math.max(1, price - refund);
        var decisionValue =
            gain + gain / netPrice * 2.5 - math.max(0, interestLoss) * 1.8;
        if (state.stage >= 8 || state.isGauntlet) {
          decisionValue += gain * 0.16;
        } else if (coinsAfter < interestPerRunCoins && gain < 18) {
          decisionValue -= 3.0;
        }
        final plan = _JokerPurchasePlan(
          joker: joker,
          replaceIndex: replaceIndex,
          price: price,
          refund: refund,
          gain: gain,
          decisionValue: decisionValue,
        );
        if (selected == null ||
            plan.decisionValue > selected.decisionValue + 0.001 ||
            ((plan.decisionValue - selected.decisionValue).abs() < 0.001 &&
                (plan.price - plan.refund) <
                    (selected.price - selected.refund))) {
          selected = plan;
        }
      }
    }
    return selected;
  }

  void _completeJokerPurchase(_JokerPurchasePlan plan) {
    state.runCoins += plan.refund - plan.price;
    if (plan.replaceIndex >= 0) {
      final removed = jokersById[state.jokerIds[plan.replaceIndex]];
      if (removed?.stateKey case final key?) state.jokerState.remove(key);
      state.jokerIds[plan.replaceIndex] = plan.joker.id;
    } else {
      state.jokerIds.add(plan.joker.id);
    }
    jokersBought++;
  }

  double _jokerBuildValue(Iterable<String> ids) {
    final definitions = <JokerDefinition>[
      for (final id in ids) ?jokersById[id],
    ];
    var result = definitions.fold<double>(
      0,
      (total, joker) => total + _jokerStandaloneValue(joker),
    );
    for (var left = 0; left < definitions.length; left++) {
      final leftTags = _jokerSynergyTags(definitions[left].id);
      for (var right = left + 1; right < definitions.length; right++) {
        final shared = leftTags.intersection(
          _jokerSynergyTags(definitions[right].id),
        );
        result += math.min(9, shared.length * 4.5);
      }
    }
    final rareOrWild = definitions
        .where(
          (joker) =>
              joker.rarity == JokerRarity.rare ||
              joker.rarity == JokerRarity.wild,
        )
        .length;
    if (definitions.any((joker) => joker.id == 'rarity_hunter')) {
      result += rareOrWild * 6;
    }
    if (definitions.any((joker) => joker.id == 'ensemble')) {
      result += definitions.length * 2.5;
    }
    return result;
  }

  double _jokerStandaloneValue(JokerDefinition joker) {
    final rarity = switch (joker.rarity) {
      JokerRarity.common => 6.0,
      JokerRarity.uncommon => 8.0,
      JokerRarity.rare => 10.0,
      JokerRarity.wild => 12.0,
    };
    final hands = math.max(
      1,
      handTypeCounts.values.fold<int>(0, (sum, count) => sum + count),
    );
    final madeHandRate =
        handTypeCounts.entries
            .where((entry) => entry.key != HandType.highCard)
            .fold<int>(0, (sum, entry) => sum + entry.value) /
        hands;
    final flushRate =
        handTypeCounts.entries
            .where((entry) => entry.key.legacyName.contains('Flush'))
            .fold<int>(0, (sum, entry) => sum + entry.value) /
        hands;
    final straightRate =
        handTypeCounts.entries
            .where((entry) => entry.key.legacyName.contains('Straight'))
            .fold<int>(0, (sum, entry) => sum + entry.value) /
        hands;
    final remainingHeats = math.max(
      0,
      (config.mode == RunMode.gauntlet ? gauntletHeats : config.maxHeat) -
          state.stage,
    );
    final boostedTypes = state.handLevels.values
        .where((level) => level > 0)
        .length;
    final maxRankCount = <CardRank, int>{
      for (final rank in CardRank.values)
        rank: state.cards.where((card) => card.rank == rank).length,
    }.values.fold<int>(0, math.max);
    final enhanced = state.cards
        .where((card) => card.enhancement != null)
        .length;

    final effect = switch (joker.id) {
      'devx20' => 500.0,
      'glass_joystick' => 52.0,
      'fragile_genius' => 43.0,
      'overclock' => 34.0,
      'danger_music' => 33.0,
      'allin' => 30.0,
      'survivor' => 30.0,
      'redline' => 29.0,
      'roulette' => 25.0,
      'lastcall' || 'high_wire' => 24.0,
      'roller' || 'doubledown' || 'perfectionist' => 22.0,
      'modded' || 'storm_harness' || 'rule_breaker' => 21.0,
      'wire' => 12.0 + straightRate * 30,
      'flushfund' => 12.0 + flushRate * 34,
      'polish' => 12.0 + madeHandRate * 22,
      'trainer' => 9.0 + madeHandRate * 16 + remainingHeats * 0.8,
      'shortcut' || 'gap_filler' => 20.0 + straightRate * 14,
      'pocketflush' || 'suit_swap' => 20.0 + flushRate * 14,
      'cheat' => 24.0,
      'master_class' =>
        10.0 + state.handLevels.values.fold<int>(0, math.max) * 5,
      'boostfiend' => 8.0 + boostedTypes * 3,
      'practice_mode' => 5.0 + boostedTypes * 3,
      'dividend' => remainingHeats * 1.6,
      'surge' || 'safe_cracker' => 6.0 + state.stagesCleared * 2.0,
      'butcher' => 5.0 + state.destroyedCount * 7,
      'collector' => 5.0 + state.copiedCount * 2,
      'printer' => 7.0 + state.copiedCount * 4,
      'tailor' ||
      'frequency_meter' => maxRankCount >= 5 ? 20.0 : 6.0 + maxRankCount * 2,
      'cleaner' => state.cards.length < 45 ? 18.0 : 7.0,
      'guillotine' => state.cards.length < 42 ? 26.0 : 9.0,
      'miser' => math.max(7.0, state.cards.length * 0.35),
      'hoarder' => math.max(5.0, (state.cards.length - 40) * 1.3),
      'piggy' => 5.0 + (state.runCoins ~/ 5) * 2.0,
      'purist' => enhanced == 0 ? 22.0 : math.max(2.0, 18 - enhanced * 2),
      'goldsmith' ||
      'neon_dealer' ||
      'glazier' ||
      'wild_whisperer' => 10.0 + enhanced * 2.5,
      'two_faced' || 'understudy' || 'alchemist' => 22.0,
      'rainbow' || 'monochrome' => 20.0,
      'blood_money' => state.runCoins > 4 ? 23.0 : 13.0,
      'copper' || 'opening_act' || 'warm_up' => 14.0,
      'rehearsal_tape' || 'clutch_gear' || 'frontrunner' || 'underdog' => 17.0,
      'momentum' ||
      'marathoner' ||
      'encore' ||
      'metronome' ||
      'comboist' => 15.0,
      'sniper' || 'twin_flame' || 'trident' || 'quartet' || 'fulltable' => 16.0,
      'couple' || 'face_value' || 'ace_in_the_hole' => 17.0,
      'royalscam' || 'lucky7' => 20.0,
      'dumpster' || 'panic_button' => 14.0,
      'chaos_theory' => 18.0,
      'rarity_hunter' || 'ensemble' => 12.0,
      _ => 9.0,
    };
    return rarity + effect;
  }

  Set<String> _jokerSynergyTags(String id) {
    final result = <String>{};
    if (const <String>{
      'polish',
      'trainer',
      'couple',
      'tailor',
      'frequency_meter',
      'twin_study',
      'two_faced',
      'understudy',
      'alchemist',
    }.contains(id)) {
      result.add('rank-shape');
    }
    if (const <String>{
      'flushfund',
      'uniform',
      'pocketflush',
      'color_wash',
      'prism_lens',
      'rainbow',
      'monochrome',
      'suit_swap',
    }.contains(id)) {
      result.add('suit');
    }
    if (const <String>{'wire', 'shortcut', 'gap_filler'}.contains(id)) {
      result.add('straight');
    }
    if (const <String>{
      'boostfiend',
      'practice_mode',
      'master_class',
    }.contains(id)) {
      result.add('boost');
    }
    if (const <String>{
      'collector',
      'printer',
      'tailor',
      'frequency_meter',
      'twin_study',
    }.contains(id)) {
      result.add('copy');
    }
    if (const <String>{'butcher', 'cleaner', 'guillotine'}.contains(id)) {
      result.add('thin-deck');
    }
    if (const <String>{
      'modded',
      'survivor',
      'storm_harness',
      'cold_adapter',
      'chaos_theory',
      'rule_breaker',
      'safe_cracker',
    }.contains(id)) {
      result.add('modifier');
    }
    if (const <String>{
      'lastcall',
      'allin',
      'clutch_gear',
      'danger_music',
      'redline',
      'high_wire',
      'frontrunner',
    }.contains(id)) {
      result.add('late-play');
    }
    if (const <String>{
      'doubledown',
      'encore',
      'metronome',
      'perfectionist',
    }.contains(id)) {
      result.add('repeat');
    }
    if (const <String>{
      'goldsmith',
      'neon_dealer',
      'glazier',
      'wild_whisperer',
    }.contains(id)) {
      result.add('enhancement');
    }
    return result;
  }

  int _jokerPriority(JokerDefinition joker) {
    final rarity = switch (joker.rarity) {
      JokerRarity.common => 1,
      JokerRarity.uncommon => 2,
      JokerRarity.rare => 3,
      JokerRarity.wild => 4,
    };
    final effectBonus = switch (joker.effect) {
      JokerEffect.highRoller ||
      JokerEffect.pairPolisher ||
      JokerEffect.lastCall ||
      JokerEffect.allIn ||
      JokerEffect.glassJoystick ||
      JokerEffect.dangerMusic => 4,
      JokerEffect.copperChip ||
      JokerEffect.openingAct ||
      JokerEffect.pairTrainer ||
      JokerEffect.heatSurge => 2,
      _ => 0,
    };
    final strategyBonus = switch (config.strategy) {
      SimulationStrategy.pairBuilder =>
        const <String>{
              'polish',
              'trainer',
              'copper',
              'presser',
              'retainer',
              'even',
              'acemag',
              'lowball',
              'inktrade',
              'triple3',
              'number_station',
              'frequency_meter',
            }.contains(joker.id)
            ? 22
            : 0,
      SimulationStrategy.flushBuilder =>
        const <String>{
              'flushfund',
              'uniform',
              'pocketflush',
              'color_wash',
              'prism_lens',
              'presser',
              'inktrade',
              'tailor',
            }.contains(joker.id)
            ? 22
            : 0,
      SimulationStrategy.adaptive || SimulationStrategy.handRanking =>
        const <String>{
              'polish',
              'opening_act',
              'roller',
              'trainer',
              'survivor',
              'modded',
              'storm_harness',
              'master_class',
              'cheat',
            }.contains(joker.id)
            ? 8
            : 0,
      SimulationStrategy.randomLegal => 0,
    };
    return rarity * 10 + effectBonus + strategyBonus;
  }

  double _adaptiveSupplyValue(SupplyId id) => switch (id) {
    SupplyId.boost =>
      14 +
          (_boostStrategicWeight(_bestBoostType()) /
                  math.max(1, handLevelBump[_bestBoostType()]!))
              .clamp(0, 12),
    SupplyId.scalpel =>
      4 +
          (state.cards.length > 45 ? 4 : 0) +
          (state.jokerIds.any(
                const <String>{'butcher', 'cleaner', 'guillotine'}.contains,
              )
              ? 10
              : 0) -
          (state.jokerIds.any(
                const <String>{'miser', 'hoarder', 'collector'}.contains,
              )
              ? 5
              : 0),
    SupplyId.copier =>
      5 +
          (state.jokerIds.any(
                const <String>{
                  'collector',
                  'printer',
                  'tailor',
                  'frequency_meter',
                  'twin_study',
                }.contains,
              )
              ? 14
              : 0) +
          (state.cards.length < 40 ? 2 : 0),
    SupplyId.dye =>
      4 +
          (state.jokerIds.any(
                const <String>{
                  'flushfund',
                  'uniform',
                  'pocketflush',
                  'color_wash',
                  'prism_lens',
                  'monochrome',
                  'suit_swap',
                }.contains,
              )
              ? 15
              : 0),
    SupplyId.enhance =>
      state.isJokerActive('purist')
          ? -100
          : 11 +
                (state.jokerIds.any(
                      const <String>{
                        'goldsmith',
                        'neon_dealer',
                        'glazier',
                        'wild_whisperer',
                      }.contains,
                    )
                    ? 14
                    : 0),
  };

  bool _shouldBuySupply(SupplyId id) => switch (id) {
    SupplyId.boost => true,
    SupplyId.scalpel =>
      state.cards.length > 42 ||
          config.strategy == SimulationStrategy.pairBuilder,
    SupplyId.copier =>
      config.strategy == SimulationStrategy.pairBuilder ||
          state.jokerIds.any(
            const <String>{'printer', 'collector', 'tailor'}.contains,
          ),
    SupplyId.dye =>
      config.strategy == SimulationStrategy.flushBuilder ||
          state.jokerIds.any(
            const <String>{
              'flushfund',
              'uniform',
              'pocketflush',
              'color_wash',
              'prism_lens',
            }.contains,
          ),
    SupplyId.enhance =>
      config.strategy != SimulationStrategy.randomLegal &&
          strategyRandom.nextDouble() < 0.48,
  };

  bool _canApplySupply(SupplyId id) => switch (id) {
    SupplyId.scalpel => state.cards.length > minimumDeckSize,
    SupplyId.copier => state.cards.any(
      (card) => canCopyCard(state.cards, card),
    ),
    SupplyId.dye => _dyeCandidate() != null,
    SupplyId.enhance => state.cards.any(canEnhanceCard),
    SupplyId.boost =>
      state.handLevels.values.any((level) => level < maxHandLevel) ||
          state.handLevels.length < HandType.values.length,
  };

  void _applySupply(SupplyId id) {
    switch (id) {
      case SupplyId.scalpel:
        if (config.strategy == SimulationStrategy.adaptive) {
          state.cards.removeAt(_bestScalpelIndex());
        } else {
          state.cards.sort((left, right) => left.value.compareTo(right.value));
          state.cards.removeAt(0);
        }
        state.destroyedCount++;
      case SupplyId.copier:
        final candidates =
            state.cards.where((card) => canCopyCard(state.cards, card)).toList()
              ..sort((left, right) {
                if (config.strategy != SimulationStrategy.adaptive) {
                  return right.value.compareTo(left.value);
                }
                return _copyCardValue(right).compareTo(_copyCardValue(left));
              });
        state.cards.add(
          candidates.first.copyWith(
            copied: true,
            clearEnhancement: true,
            selected: false,
            isNew: false,
          ),
        );
        state.copiedCount++;
      case SupplyId.dye:
        final candidate = _dyeCandidate()!;
        final card = state.cards[candidate.$1];
        final createsCopy =
            exactCardCount(
              state.cards,
              card.rank,
              candidate.$2,
              ignoreIndex: candidate.$1,
            ) >
            0;
        state.cards[candidate.$1] = card.copyWith(
          suit: candidate.$2,
          copied: createsCopy ? true : card.copied,
          clearEnhancement: createsCopy,
        );
        state.copiedCount = state.cards.where((card) => card.copied).length;
      case SupplyId.enhance:
        final candidates =
            <int>[
              for (var index = 0; index < state.cards.length; index++)
                if (canEnhanceCard(state.cards[index])) index,
            ]..sort((left, right) {
              final leftNew = state.cards[left].enhancement == null ? 1 : 0;
              final rightNew = state.cards[right].enhancement == null ? 1 : 0;
              if (leftNew != rightNew) return rightNew.compareTo(leftNew);
              return state.cards[right].value.compareTo(
                state.cards[left].value,
              );
            });
        final enhancement = config.strategy == SimulationStrategy.adaptive
            ? _preferredEnhancement()
            : config.strategy == SimulationStrategy.flushBuilder
            ? CardEnhancement.wildsuit
            : CardEnhancement.gild;
        final index = config.strategy == SimulationStrategy.adaptive
            ? _bestEnhanceIndex(candidates, enhancement)
            : candidates.first;
        state.cards[index] = state.cards[index].copyWith(
          enhancement: enhancement,
        );
      case SupplyId.boost:
        final type = config.strategy == SimulationStrategy.adaptive
            ? _bestBoostType()
            : HandType.values.reduce((left, right) {
                final leftCount = handTypeCounts[left] ?? 0;
                final rightCount = handTypeCounts[right] ?? 0;
                return rightCount > leftCount ? right : left;
              });
        state.handLevels[type] = math.min(
          maxHandLevel,
          (state.handLevels[type] ?? 0) + 1,
        );
    }
  }

  int _bestScalpelIndex() {
    final rankCounts = <CardRank, int>{
      for (final rank in CardRank.values)
        rank: state.cards.where((card) => card.rank == rank).length,
    };
    final suitCounts = <CardSuit, int>{
      for (final suit in CardSuit.values)
        suit: state.cards.where((card) => card.suit == suit).length,
    };
    final candidates = List<int>.generate(state.cards.length, (index) => index)
      ..sort((left, right) {
        final leftCard = state.cards[left];
        final rightCard = state.cards[right];
        double value(PlayingCard card) =>
            card.value +
            (rankCounts[card.rank] ?? 0) * 4 +
            (suitCounts[card.suit] ?? 0) * 0.4 +
            (card.enhancement == null ? 0 : 20);
        final compared = value(leftCard).compareTo(value(rightCard));
        return compared != 0 ? compared : left.compareTo(right);
      });
    return candidates.first;
  }

  double _copyCardValue(PlayingCard card) {
    final rankCount = state.cards
        .where((candidate) => candidate.rank == card.rank)
        .length;
    var value = card.value + rankCount * 7.0;
    if (state.jokerIds.any(
      const <String>{
        'tailor',
        'frequency_meter',
        'twin_study',
        'understudy',
        'alchemist',
      }.contains,
    )) {
      value += rankCount * 5;
    }
    if (state.isJokerActive('couple') &&
        (card.rank == CardRank.ace || card.rank == CardRank.king)) {
      value += 10;
    }
    return value;
  }

  CardEnhancement _preferredEnhancement() {
    if (state.isJokerActive('wild_whisperer') ||
        state.jokerIds.any(
          const <String>{
            'flushfund',
            'pocketflush',
            'color_wash',
            'prism_lens',
            'monochrome',
          }.contains,
        )) {
      return CardEnhancement.wildsuit;
    }
    if (state.isJokerActive('glazier') &&
        state.cards.length > minimumDeckSize + 6) {
      return CardEnhancement.glass;
    }
    if (state.isJokerActive('goldsmith')) return CardEnhancement.gild;
    return CardEnhancement.neon;
  }

  int _bestEnhanceIndex(List<int> candidates, CardEnhancement enhancement) {
    final rankCounts = <CardRank, int>{
      for (final rank in CardRank.values)
        rank: state.cards.where((card) => card.rank == rank).length,
    };
    final targetSuit = _dominantSuit();
    candidates.sort((left, right) {
      double value(int index) {
        final card = state.cards[index];
        var result = card.value + (rankCounts[card.rank] ?? 0) * 4.0;
        if (enhancement == CardEnhancement.wildsuit &&
            card.suit != targetSuit) {
          result += 12;
        }
        return result;
      }

      final compared = value(right).compareTo(value(left));
      return compared != 0 ? compared : left.compareTo(right);
    });
    return candidates.first;
  }

  HandType _bestBoostType() {
    final candidates = HandType.values.where(
      (type) => (state.handLevels[type] ?? 0) < maxHandLevel,
    );
    return candidates.reduce(
      (left, right) =>
          _boostStrategicWeight(right) > _boostStrategicWeight(left)
          ? right
          : left,
    );
  }

  double _boostStrategicWeight(HandType type) {
    final prior = switch (type) {
      HandType.highCard => 0.25,
      HandType.pair => 1.0,
      HandType.twoPair => 0.78,
      HandType.threeOfAKind => 0.56,
      HandType.straight => 0.44,
      HandType.flush => 0.42,
      HandType.fullHouse => 0.24,
      HandType.fourOfAKind => 0.10,
      HandType.straightFlush => 0.04,
      HandType.royalFlush => 0.01,
    };
    final observed = handTypeCounts[type] ?? 0;
    var synergy = 1.0;
    if (type != HandType.highCard && state.isJokerActive('polish')) {
      synergy *= 1.25;
    }
    if (type.legacyName.contains('Flush') && state.isJokerActive('flushfund')) {
      synergy *= 1.5;
    }
    if (type.legacyName.contains('Straight') && state.isJokerActive('wire')) {
      synergy *= 1.5;
    }
    if (state.isJokerActive('boostfiend')) synergy *= 1.2;
    if (state.isJokerActive('master_class')) synergy *= 1.3;
    if (type == HandType.twoPair && state.isJokerActive('two_faced')) {
      synergy *= 1.6;
    }
    final level = state.handLevels[type] ?? 0;
    return (prior + observed * 0.45) *
        handLevelBump[type]! *
        synergy /
        (1 + level * 0.12);
  }

  (int, CardSuit)? _dyeCandidate() {
    final target = _dominantSuit();
    final candidates = <int>[];
    for (var index = 0; index < state.cards.length; index++) {
      if (canDyeCard(state.cards, index, target)) candidates.add(index);
    }
    if (candidates.isEmpty) return null;
    if (config.strategy == SimulationStrategy.adaptive) {
      final rankCounts = <CardRank, int>{
        for (final rank in CardRank.values)
          rank: state.cards.where((card) => card.rank == rank).length,
      };
      candidates.sort((left, right) {
        double value(int index) {
          final card = state.cards[index];
          return card.value + (rankCounts[card.rank] ?? 0) * 3.0;
        }

        final compared = value(right).compareTo(value(left));
        return compared != 0 ? compared : left.compareTo(right);
      });
    }
    return (candidates.first, target);
  }

  CardSuit _dominantSuit() {
    final suitCounts = <CardSuit, int>{
      for (final suit in CardSuit.values)
        suit: state.cards.where((card) => card.suit == suit).length,
    };
    return CardSuit.values.reduce(
      (left, right) => suitCounts[right]! > suitCounts[left]! ? right : left,
    );
  }

  void _checkInvariants(String point) {
    if (state.cards.length < minimumDeckSize) {
      failures.add('$point: deck below $minimumDeckSize');
    }
    final exact = <String, int>{};
    for (final card in state.cards) {
      final key = '${card.rank.label}|${card.suit.symbol}';
      exact[key] = (exact[key] ?? 0) + 1;
      if (card.copied && card.enhancement != null) {
        failures.add('$point: copied card retained enhancement');
      }
    }
    if (exact.values.any((count) => count > maximumExactCardCopies)) {
      failures.add('$point: exact-copy cap exceeded');
    }
    if (state.jokerIds.length > maxJokers) {
      failures.add('$point: Joker cap exceeded');
    }
    if (state.handsLeft < 0 || state.handsLeft > state.effectiveHandsPerHeat) {
      failures.add('$point: invalid handsLeft ${state.handsLeft}');
    }
    if (state.discardsLeft < 0 ||
        state.discardsLeft > state.effectiveDiscards) {
      failures.add('$point: invalid discardsLeft ${state.discardsLeft}');
    }
    if (state.runCoins < 0 || state.stageScore < 0 || totalScore < 0) {
      failures.add('$point: negative economy/score state');
    }
  }
}

List<Set<CardRank>> _straightRankWindows(int required) {
  final width = required.clamp(3, 5);
  final byValue = <int, CardRank>{
    for (final rank in CardRank.values) rank.value: rank,
  };
  final windows = <Set<CardRank>>[];
  final seen = <String>{};

  void add(Iterable<int> values) {
    final ranks = values.map((value) => byValue[value]).whereType<CardRank>();
    final window = ranks.toSet();
    if (window.length != width) return;
    final key = window.map((rank) => rank.value).toList()..sort();
    if (seen.add(key.join(','))) windows.add(window);
  }

  add(<int>[15, for (var value = 2; value < 2 + width - 1; value++) value]);
  for (var start = 2; start + width - 1 <= 13; start++) {
    add(<int>[for (var value = start; value < start + width; value++) value]);
  }
  add(<int>[for (var value = 15 - width; value <= 13; value++) value, 15]);
  return windows;
}

double _probabilityDrawAllRanks({
  required int population,
  required Map<CardRank, int> unseenRanks,
  required int draws,
  required List<CardRank> missing,
}) {
  if (missing.isEmpty) return 1;
  if (draws < missing.length || population <= 0) return 0;
  if (missing.any((rank) => (unseenRanks[rank] ?? 0) == 0)) return 0;
  final denominator = _combinationDouble(population, draws);
  if (denominator <= 0) return 0;
  var probability = 0.0;
  final subsetCount = 1 << missing.length;
  for (var mask = 0; mask < subsetCount; mask++) {
    var excluded = 0;
    var bits = 0;
    for (var index = 0; index < missing.length; index++) {
      if ((mask & (1 << index)) == 0) continue;
      excluded += unseenRanks[missing[index]] ?? 0;
      bits++;
    }
    final term = _combinationDouble(population - excluded, draws) / denominator;
    probability += bits.isEven ? term : -term;
  }
  return probability.clamp(0.0, 1.0).toDouble();
}

double _hypergeometricAtLeast({
  required int population,
  required int successes,
  required int draws,
  required int needed,
}) {
  if (needed <= 0) return 1;
  if (population <= 0 || draws <= 0 || successes < needed) return 0;
  final safeDraws = math.min(draws, population);
  final maximum = math.min(successes, safeDraws);
  if (needed > maximum) return 0;
  final denominator = _combinationDouble(population, safeDraws);
  if (denominator <= 0) return 0;
  var result = 0.0;
  for (var hits = needed; hits <= maximum; hits++) {
    final misses = safeDraws - hits;
    if (misses < 0 || misses > population - successes) continue;
    result +=
        _combinationDouble(successes, hits) *
        _combinationDouble(population - successes, misses) /
        denominator;
  }
  return result.clamp(0.0, 1.0).toDouble();
}

double _combinationDouble(int count, int choose) {
  if (choose < 0 || count < 0 || choose > count) return 0;
  final width = math.min(choose, count - choose);
  var result = 1.0;
  for (var index = 1; index <= width; index++) {
    result *= (count - width + index) / index;
  }
  return result;
}

Iterable<List<PlayingCard>> _combinations(
  List<PlayingCard> source,
  int count,
) sync* {
  if (count < 1 || count > source.length) return;
  final indices = List<int>.generate(count, (index) => index);
  while (true) {
    yield <PlayingCard>[for (final index in indices) source[index]];
    var pivot = count - 1;
    while (pivot >= 0 && indices[pivot] == source.length - count + pivot) {
      pivot--;
    }
    if (pivot < 0) return;
    indices[pivot]++;
    for (var index = pivot + 1; index < count; index++) {
      indices[index] = indices[index - 1] + 1;
    }
  }
}

class _ScoredPlay {
  const _ScoredPlay(this.cards, this.result, this.expectedScore);

  final List<PlayingCard> cards;
  final ScoreResult result;
  final double expectedScore;
}

class _JokerPurchasePlan {
  const _JokerPurchasePlan({
    required this.joker,
    required this.replaceIndex,
    required this.price,
    required this.refund,
    required this.gain,
    required this.decisionValue,
  });

  final JokerDefinition joker;
  final int replaceIndex;
  final int price;
  final int refund;
  final double gain;
  final double decisionValue;
}

class _StrategyRandom {
  _StrategyRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  double nextDouble() {
    var value = _state;
    value ^= (value << 13) & 0xFFFFFFFF;
    value ^= value >>> 17;
    value ^= (value << 5) & 0xFFFFFFFF;
    _state = value & 0xFFFFFFFF;
    return _state / 4294967296;
  }

  int nextInt(int upperBound) {
    if (upperBound <= 0) throw ArgumentError.value(upperBound, 'upperBound');
    return (nextDouble() * upperBound).floor();
  }
}

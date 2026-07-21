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
      var discardGuard = 0;
      while (state.discardsLeft > 0 && discardGuard++ < discardsPerHeat) {
        final discard = _chooseDiscard(hand, engine);
        if (discard.isEmpty) break;
        for (final card in discard) {
          hand.remove(card);
        }
        state.discardsLeft--;
        totalDiscards++;
        _refillHand(hand, heatDeck);
        _clearPlayCache();
      }

      final selected = _choosePlay(hand, engine);
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
    WildcardScoringEngine engine,
  ) {
    if (config.strategy == SimulationStrategy.randomLegal) {
      if (strategyRandom.nextDouble() >= 0.28) return const <PlayingCard>[];
      final count = 1 + strategyRandom.nextInt(math.min(3, hand.length));
      return _randomCards(hand, count);
    }
    final best = _bestRankedPlay(hand, engine);
    final type = engine.evaluateHand(best);
    if (state.discardsLeft <= 0) {
      return const <PlayingCard>[];
    }

    if (config.strategy == SimulationStrategy.handRanking &&
        type != HandType.highCard) {
      return const <PlayingCard>[];
    }

    final immediate = engine.scoreHand(best).total;
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

  List<PlayingCard> _choosePlay(
    List<PlayingCard> hand,
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
    return _bestRankedPlay(hand, engine);
  }

  List<PlayingCard> _bestRankedPlay(
    List<PlayingCard> hand,
    WildcardScoringEngine engine,
  ) {
    final cached = _cachedHand;
    if (cached != null && _sameCards(cached, hand)) {
      return List<PlayingCard>.from(_cachedBestPlay!);
    }
    List<PlayingCard>? best;
    var bestScore = -1;
    final limit = math.min(state.effectiveMaxSelect, hand.length);
    for (var size = 1; size <= limit; size++) {
      for (final candidate in _combinations(hand, size)) {
        final score = engine.scoreHand(candidate).total;
        if (score > bestScore ||
            (score == bestScore && candidate.length < (best?.length ?? 99))) {
          best = candidate;
          bestScore = score;
        }
      }
    }
    final selected = best ?? <PlayingCard>[hand.first];
    _cachedHand = List<PlayingCard>.from(hand);
    _cachedBestPlay = List<PlayingCard>.from(selected);
    return selected;
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
      state.runCoins += refund - price;
      if (replaceIndex >= 0) {
        final removed = jokersById[state.jokerIds[replaceIndex]];
        if (removed?.stateKey case final key?) state.jokerState.remove(key);
        state.jokerIds[replaceIndex] = joker.id;
      } else {
        state.jokerIds.add(joker.id);
      }
      jokersBought++;
      offers.remove(joker);
    }

    final supplyOffers = _rollSupplyOffers();
    var supplyBuys = 0;
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
        state.cards.sort((left, right) => left.value.compareTo(right.value));
        state.cards.removeAt(0);
        state.destroyedCount++;
      case SupplyId.copier:
        final candidates =
            state.cards.where((card) => canCopyCard(state.cards, card)).toList()
              ..sort((left, right) => right.value.compareTo(left.value));
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
        final index = candidates.first;
        final enhancement = config.strategy == SimulationStrategy.flushBuilder
            ? CardEnhancement.wildsuit
            : CardEnhancement.gild;
        state.cards[index] = state.cards[index].copyWith(
          enhancement: enhancement,
        );
      case SupplyId.boost:
        final type = HandType.values.reduce((left, right) {
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

  (int, CardSuit)? _dyeCandidate() {
    final suitCounts = <CardSuit, int>{
      for (final suit in CardSuit.values)
        suit: state.cards.where((card) => card.suit == suit).length,
    };
    final target = CardSuit.values.reduce(
      (left, right) => suitCounts[right]! > suitCounts[left]! ? right : left,
    );
    for (var index = 0; index < state.cards.length; index++) {
      if (canDyeCard(state.cards, index, target)) return (index, target);
    }
    return null;
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

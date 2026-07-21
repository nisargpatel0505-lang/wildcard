import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/account_state.dart';
import '../domain/cards.dart';
import '../domain/deck_integrity.dart';
import '../domain/economy.dart';
import '../domain/game_rules.dart';
import '../domain/joker_catalog.dart';
import '../domain/legacy_save_schema.dart';
import '../domain/random_streams.dart';
import '../domain/scoring_engine.dart';
import 'game_models.dart';

/// Owns one complete native WILDCARD run.
///
/// Scoring rules stay in the pure domain layer. This controller owns the
/// state-machine around those rules: dealing, deterministic RNG, checkpoints,
/// presentation pacing, shops, supplies and terminal settlement.
class GameController extends ChangeNotifier {
  GameController._({
    required this.state,
    required this.runId,
    required this.callbacks,
    required Set<String> unlockedJokerIds,
    required this.pace,
    required this.dailyDate,
    required this.startBoostJoker,
    required this.startBoostCost,
    required this.stake,
    required this.guidedFirstRun,
    required Map<String, Object?> legacyBase,
    required this._wait,
  }) : unlockedJokerIds = Set<String>.from(unlockedJokerIds),
       _legacyBase = Map<String, Object?>.from(legacyBase);

  static Future<GameController> startNew({
    required GameRunConfig config,
    required GamePersistenceCallbacks callbacks,
    ScoringWait? wait,
  }) async {
    var deck = _withStableIds(config.initialDeck ?? baseCardSet(), 'c');
    final integrity = normalizeDeckIntegrity(deck);
    deck = _withStableIds(deck, 'c');
    final initialJokers = config.initialJokerIds
        .where(jokersById.containsKey)
        .toSet()
        .take(maxJokers)
        .toList();
    if (config.startBoostJokerId case final id?) {
      if (jokersById.containsKey(id) &&
          !initialJokers.contains(id) &&
          initialJokers.length < maxJokers) {
        initialJokers.add(id);
      }
    }
    final effectiveSeed = config.mode == RunMode.daily
        ? dailySeed(config.dailyDate)
        : config.rngSeed;
    final state = ScoringState(
      rngSeed: effectiveSeed,
      mode: config.mode,
      difficulty: config.mode == RunMode.normal
          ? config.difficulty
          : RunDifficulty.medium,
      jokerIds: initialJokers,
      cards: deck,
      destroyedCount: integrity.destroyedCount,
      copiedCount: integrity.copiedCount,
    );
    final runId = config.runId ?? _newRunId(effectiveSeed);
    final controller = GameController._(
      state: state,
      runId: runId,
      callbacks: callbacks,
      unlockedJokerIds: config.mode == RunMode.daily
          ? jokersById.keys.toSet()
          : config.unlockedJokerIds,
      pace: config.scoringPace,
      dailyDate: config.dailyDate,
      startBoostJoker: config.startBoostJokerId,
      startBoostCost: math.max(0, config.startBoostCost),
      stake: math.max(0, config.stake),
      guidedFirstRun: config.guidedFirstRun,
      legacyBase: const <String, Object?>{},
      wait: wait ?? Future<void>.delayed,
    );

    final entryCharge = controller.startBoostCost + controller.stake;
    // Entry is a durable event even when it costs zero. Daily attempts and
    // first-run guidance both depend on this mutation; skipping it made every
    // free Daily replayable and caused every free Normal run to look like the
    // player's first run.
    final applied = await callbacks.mutateAccount(
      AccountMutation(
        claimId: '$runId:entry',
        kind: AccountMutationKind.runEntry,
        coinDelta: -entryCharge,
        runMode: state.mode,
      ),
    );
    if (!applied) {
      throw StateError('The run entry could not be saved');
    }

    await controller._beginHeat(checkpoint: RunCheckpoint.runStarted);
    return controller;
  }

  static Future<GameController> resume({
    required String encoded,
    required GamePersistenceCallbacks callbacks,
    Set<String> unlockedJokerIds = const <String>{},
    ScoringPace pace = ScoringPace.normal,
    ScoringWait? wait,
  }) async {
    final save = LegacyRunSave.decode(encoded);
    final state = save.toScoringState();
    final raw = save.raw;
    final controller = GameController._(
      state: state,
      runId: _string(raw['runId'], fallback: _newRunId(state.rngSeed)),
      callbacks: callbacks,
      unlockedJokerIds: state.mode == RunMode.daily
          ? jokersById.keys.toSet()
          : unlockedJokerIds,
      pace: pace,
      dailyDate: _string(raw['dailyDate']),
      startBoostJoker: _nullableString(raw['startBoostJoker']),
      startBoostCost: _integer(raw['startBoostCost']),
      stake: _integer(raw['stake']),
      guidedFirstRun: raw['guidedFirstRun'] == true,
      legacyBase: raw,
      wait: wait ?? Future<void>.delayed,
    );
    controller._restore(raw, save.phase);
    return controller;
  }

  final ScoringState state;
  final String runId;
  final GamePersistenceCallbacks callbacks;
  final Set<String> unlockedJokerIds;
  final String dailyDate;
  final String? startBoostJoker;
  final int startBoostCost;
  final int stake;
  final bool guidedFirstRun;
  final Map<String, Object?> _legacyBase;
  final ScoringWait _wait;

  ScoringPace pace;
  RunPhase phase = RunPhase.game;
  RunEndReason? endReason;
  RunResultSummary? resultSummary;
  ScoringPresentation scoringPresentation = const ScoringPresentation();
  HeatRewardSummary? lastHeatReward;

  final List<PlayingCard> drawPile = <PlayingCard>[];
  final List<PlayingCard> hand = <PlayingCard>[];
  final List<PlayingCard> heatDeck = <PlayingCard>[];
  final Set<String> selectedCardIds = <String>{};
  final List<JokerDefinition> jokerOffers = <JokerDefinition>[];
  final List<SupplyDefinition> supplyOffers = <SupplyDefinition>[];
  final Set<SupplyId> suppliesBoughtThisShop = <SupplyId>{};
  SupplyPurchaseLedger supplyLedger = SupplyPurchaseLedger();

  int totalScore = 0;
  int accountEarned = 0;
  int shopBuysUsed = 0;
  int wildMissShops = 0;
  int boostsBought = 0;
  int bestPlay = 0;
  HandType? bestPlayType;
  int stakePayoutAmount = 0;
  int stakeNet = 0;
  bool stakePaid = false;
  bool reviveUsed = false;
  bool leaderboardEligible = true;
  bool inflationForShop = false;
  bool lastWildPityForced = false;
  bool glassDouble = false;
  bool isBusy = false;
  bool terminalPending = false;
  String failureReason = '';
  String? pendingSwapOfferId;
  Map<String, Object?>? pendingTransition;
  HandSortMode sortMode = HandSortMode.rank;

  final Map<HandType, int> handTypeCounts = <HandType, int>{};
  final List<String> modifiersSurvived = <String>[];
  final Map<String, int> jokerScore = <String, int>{};
  final List<String> accountRewardIds = <String>[];

  WildcardScoringEngine get scoringEngine => WildcardScoringEngine(state);
  ScoringPacing get pacing =>
      pace == ScoringPace.fast ? ScoringPacing.fast : ScoringPacing.normal;
  int get target => state.target;
  bool get canPlay =>
      phase == RunPhase.game &&
      !isBusy &&
      state.handsLeft > 0 &&
      selectedCards.isNotEmpty;
  bool get canDiscard =>
      phase == RunPhase.game &&
      !isBusy &&
      state.discardsLeft > 0 &&
      selectedCards.isNotEmpty;
  bool get canReroll =>
      phase == RunPhase.shop &&
      !isBusy &&
      !jokerBuyLimitReached &&
      pendingSwapOfferId == null &&
      state.runCoins >= shopRerollCost &&
      _availableJokerPool().isNotEmpty;
  bool get jokerBuyLimitReached => shopBuysUsed >= currentJokerBuyLimit;
  int get currentJokerBuyLimit => shopBuyLimit(
    stage: state.stage,
    endless: state.endless,
    gauntlet: state.isGauntlet,
  );
  List<PlayingCard> get selectedCards => hand
      .where((card) => selectedCardIds.contains(_cardId(card)))
      .toList(growable: false);
  ShopSnapshot get shop => ShopSnapshot(
    jokerOffers: List<JokerDefinition>.unmodifiable(jokerOffers),
    supplyOffers: List<SupplyDefinition>.unmodifiable(supplyOffers),
    boughtSupplyIds: Set<SupplyId>.unmodifiable(suppliesBoughtThisShop),
    jokerBuysUsed: shopBuysUsed,
    jokerBuyLimit: currentJokerBuyLimit,
    inflation: inflationForShop,
  );

  ScoreResult? previewSelected() {
    final cards = selectedCards;
    if (cards.isEmpty || cards.length > state.effectiveMaxSelect) return null;
    return scoringEngine.scoreHand(cards);
  }

  Future<GameActionResult> sortHand(HandSortMode mode) async {
    if (phase != RunPhase.game || isBusy) {
      return const GameActionResult.failure('The hand is locked right now.');
    }
    sortMode = mode;
    int compare(PlayingCard left, PlayingCard right) {
      if (mode == HandSortMode.suit) {
        final suit = left.suit.sortOrder.compareTo(right.suit.sortOrder);
        if (suit != 0) return suit;
      }
      final rank = right.value.compareTo(left.value);
      if (rank != 0) return rank;
      return left.suit.sortOrder.compareTo(right.suit.sortOrder);
    }

    hand.sort(compare);
    await _save(RunCheckpoint.selectionChanged);
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> toggleCard(String cardId) async {
    if (phase != RunPhase.game || isBusy) {
      return const GameActionResult.failure('Cards are locked right now.');
    }
    if (!hand.any((card) => _cardId(card) == cardId)) {
      return const GameActionResult.failure('That card is no longer in hand.');
    }
    if (selectedCardIds.remove(cardId)) {
      notifyListeners();
      return const GameActionResult.success();
    }
    if (selectedCardIds.length >= state.effectiveMaxSelect) {
      return GameActionResult.failure(
        'Select up to ${state.effectiveMaxSelect} cards.',
      );
    }
    selectedCardIds.add(cardId);
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> clearSelection() async {
    if (isBusy) return const GameActionResult.failure('Scoring is active.');
    selectedCardIds.clear();
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> discardSelected() async {
    if (!canDiscard) {
      return const GameActionResult.failure(
        'Select cards and make sure a discard is available.',
      );
    }
    isBusy = true;
    notifyListeners();
    final selected = selectedCards.toSet();
    hand.removeWhere(selected.contains);
    selectedCardIds.clear();
    state.discardsLeft--;
    _refillHand();
    state.deckCardsLeft = drawPile.length;
    await _save(RunCheckpoint.discardCommitted);
    if (hand.isEmpty) {
      await _offerOrFinishFailure('cards');
    }
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  /// Scores the exact selected card objects. The durable pre-roll marker is
  /// written before any luck stream is consumed.
  Future<GameActionResult> playSelected() async {
    if (!canPlay) {
      return const GameActionResult.failure('Select cards before playing.');
    }
    final played = selectedCards;
    if (played.length > state.effectiveMaxSelect) {
      return GameActionResult.failure(
        'This Heat allows ${state.effectiveMaxSelect} cards.',
      );
    }
    isBusy = true;
    scoringPresentation = const ScoringPresentation();
    final preRollCounters = state.rngCounters.copy();
    pendingTransition = <String, Object?>{
      'kind': 'play',
      'cardUids': played.map(_cardId).toList(growable: false),
      'rngCounters': preRollCounters.toJson(),
    };
    notifyListeners();
    await _save(RunCheckpoint.scoringPrepared);

    final result = scoringEngine.scoreHand(played, commit: true);
    scoringPresentation = ScoringPresentation(result: result);
    notifyListeners();
    await _wait(pacing.leadIn);
    await _presentScoreEvents(played, result);

    state.stageScore += result.total;
    totalScore += result.total;
    state.handsLeft--;
    state.handsPlayedThisStage++;
    handTypeCounts[result.handType] =
        (handTypeCounts[result.handType] ?? 0) + 1;
    if (result.total > bestPlay) {
      bestPlay = result.total;
      bestPlayType = result.handType;
    }
    scoringEngine.applyOnScored(result);
    _attributeJokerScore(result);
    final glassResult = scoringEngine.resolveGlassCardShatters(
      played,
      result.scoringFlags,
    );
    glassDouble = glassDouble || glassResult.twoOrMoreScored;
    final playedIdentity = played.toSet();
    hand.removeWhere(playedIdentity.contains);
    selectedCardIds.clear();
    _refillHand();
    state.deckCardsLeft = drawPile.length;
    scoringPresentation = ScoringPresentation(
      result: result,
      visibleRank: result.rankSum,
      visibleMultiplier: result.multiplier,
      visibleTotal: result.total,
      label: '+${result.total}',
      complete: true,
    );

    if (state.stageScore >= state.target) {
      pendingTransition = <String, Object?>{
        'kind': 'clear',
        'stage': state.stage,
      };
    } else if (state.handsLeft <= 0 || hand.isEmpty) {
      pendingTransition = <String, Object?>{
        'kind': 'fail',
        'stage': state.stage,
        'reason': hand.isEmpty ? 'cards' : 'plays',
      };
    } else {
      pendingTransition = null;
    }
    await _save(RunCheckpoint.scoringCommitted);
    notifyListeners();
    await _wait(pacing.resultHold);

    if (pendingTransition?['kind'] == 'clear') {
      await _clearHeat();
    } else if (pendingTransition?['kind'] == 'fail') {
      await _offerOrFinishFailure(_string(pendingTransition?['reason']));
    } else {
      scoringPresentation = const ScoringPresentation();
      isBusy = false;
      notifyListeners();
    }
    return const GameActionResult.success();
  }

  /// Replays a force-killed scoring action with the same selected cards and RNG
  /// counters. The result therefore cannot be rerolled by killing the process.
  Future<GameActionResult> resolveInterruptedScoring() async {
    final pending = pendingTransition;
    if (pending?['kind'] != 'play' || isBusy || phase != RunPhase.game) {
      return const GameActionResult.failure('No interrupted score to restore.');
    }
    state.rngCounters = RandomCounters.fromJson(pending?['rngCounters']);
    final wanted = _stringList(pending?['cardUids']).toSet();
    if (wanted.isEmpty) wanted.addAll(selectedCardIds);
    selectedCardIds
      ..clear()
      ..addAll(
        hand.map(_cardId).where(wanted.contains).take(state.effectiveMaxSelect),
      );
    if (selectedCardIds.isEmpty) {
      pendingTransition = null;
      await _save(RunCheckpoint.scoringCommitted);
      return const GameActionResult.failure(
        'The interrupted hand could not be reconstructed.',
      );
    }
    notifyListeners();
    return playSelected();
  }

  /// Completes any transition whose durable marker survived a process kill.
  /// Attach the UI listener first, then call this once after [resume].
  Future<GameActionResult> recoverPendingTransition() async {
    final kind = pendingTransition?['kind'];
    if (kind == 'play') return resolveInterruptedScoring();
    if (kind == 'clear') {
      if (phase != RunPhase.game || isBusy) {
        return const GameActionResult.failure('The Heat cannot clear yet.');
      }
      isBusy = true;
      await _clearHeat();
      return const GameActionResult.success();
    }
    if (kind == 'fail') {
      if (phase != RunPhase.game || isBusy) {
        return const GameActionResult.failure(
          'The failed Heat cannot close yet.',
        );
      }
      isBusy = true;
      await _offerOrFinishFailure(_string(pendingTransition?['reason']));
      return const GameActionResult.success();
    }
    return const GameActionResult.failure('No interrupted transition exists.');
  }

  Future<GameActionResult> rerollShop() async {
    if (!canReroll) {
      return const GameActionResult.failure('The shop cannot be rerolled.');
    }
    isBusy = true;
    state.runCoins -= shopRerollCost;
    _rollJokerOffers(countForPity: false);
    await _save(RunCheckpoint.shopChanged);
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> buyJoker(String jokerId, {int? swapIndex}) async {
    if (phase != RunPhase.shop || isBusy || jokerBuyLimitReached) {
      return const GameActionResult.failure('Joker buying is closed.');
    }
    final offerIndex = jokerOffers.indexWhere((offer) => offer.id == jokerId);
    if (offerIndex < 0) {
      return const GameActionResult.failure('That Joker is not on offer.');
    }
    final joker = jokerOffers[offerIndex];
    final price = joker.price + (inflationForShop ? 2 : 0);
    var refund = 0;
    JokerDefinition? replaced;
    if (state.jokerIds.length >= maxJokers) {
      if (swapIndex == null ||
          swapIndex < 0 ||
          swapIndex >= state.jokerIds.length) {
        pendingSwapOfferId = joker.id;
        notifyListeners();
        return const GameActionResult.failure('Choose a Joker to replace.');
      }
      replaced = jokersById[state.jokerIds[swapIndex]];
      refund = replaced == null ? 0 : sellValue(replaced);
    }
    if (state.runCoins + refund < price) {
      return const GameActionResult.failure('Not enough run coins.');
    }
    isBusy = true;
    state.runCoins += refund - price;
    if (replaced != null) {
      if (replaced.stateKey case final key?) state.jokerState.remove(key);
      state.jokerIds[swapIndex!] = joker.id;
    } else {
      state.jokerIds.add(joker.id);
    }
    jokerOffers.removeAt(offerIndex);
    shopBuysUsed++;
    pendingSwapOfferId = null;
    await _save(RunCheckpoint.shopChanged);
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  void cancelJokerSwap() {
    pendingSwapOfferId = null;
    notifyListeners();
  }

  Future<GameActionResult> sellJoker(int index) async {
    if (phase != RunPhase.shop || isBusy || pendingSwapOfferId != null) {
      return const GameActionResult.failure(
        'Jokers can only be sold in a shop.',
      );
    }
    if (index < 0 || index >= state.jokerIds.length) {
      return const GameActionResult.failure('That Joker slot is empty.');
    }
    isBusy = true;
    final id = state.jokerIds.removeAt(index);
    final joker = jokersById[id];
    if (joker != null) {
      state.runCoins += sellValue(joker);
      if (joker.stateKey case final key?) state.jokerState.remove(key);
    }
    await _save(RunCheckpoint.shopChanged);
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  int sellValue(JokerDefinition joker) => math.max(1, joker.price ~/ 2);

  int priceForSupply(SupplyDefinition supply) =>
      supplyPrice(supply, ledger: supplyLedger, inflation: inflationForShop);

  Future<GameActionResult> buySupply(
    SupplyId id,
    SupplySelection selection,
  ) async {
    if (phase != RunPhase.shop || isBusy || pendingSwapOfferId != null) {
      return const GameActionResult.failure(
        'Supplies are unavailable right now.',
      );
    }
    if (suppliesBoughtThisShop.contains(id)) {
      return const GameActionResult.failure(
        'Each supply can be bought once in this shop.',
      );
    }
    final supply = supplyOffers.cast<SupplyDefinition?>().firstWhere(
      (candidate) => candidate?.id == id,
      orElse: () => null,
    );
    if (supply == null) {
      return const GameActionResult.failure('That supply is not on offer.');
    }
    final price = priceForSupply(supply);
    if (state.runCoins < price) {
      return const GameActionResult.failure('Not enough run coins.');
    }
    final validation = _validateSupply(id, selection);
    if (!validation.ok) return validation;
    isBusy = true;
    suppliesBoughtThisShop.add(id);
    _applySupply(id, selection);
    state.runCoins -= price;
    supplyLedger.record(id, state.stage);
    await _save(RunCheckpoint.shopChanged);
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> leaveShop() async {
    if (phase != RunPhase.shop || isBusy || pendingSwapOfferId != null) {
      return const GameActionResult.failure('Finish the current shop action.');
    }
    isBusy = true;
    state.stage++;
    state.stageScore = 0;
    state.handsPlayedThisStage = 0;
    state.previousHandType = null;
    inflationForShop = false;
    jokerOffers.clear();
    supplyOffers.clear();
    suppliesBoughtThisShop.clear();
    shopBuysUsed = 0;
    await _beginHeat(checkpoint: RunCheckpoint.heatStarted);
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> continueEndless() async {
    if (phase != RunPhase.victory ||
        state.isGauntlet ||
        state.isDaily ||
        state.stage != 12) {
      return const GameActionResult.failure('Endless is not available here.');
    }
    state.endless = true;
    state.stage++;
    state.stageScore = 0;
    state.handsPlayedThisStage = 0;
    state.previousHandType = null;
    phase = RunPhase.game;
    isBusy = true;
    await _beginHeat(checkpoint: RunCheckpoint.heatStarted);
    isBusy = false;
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> bankVictory() async {
    if (phase != RunPhase.victory) {
      return const GameActionResult.failure('There is no victory to bank.');
    }
    final reason = state.isDaily
        ? RunEndReason.dailyComplete
        : state.isGauntlet
        ? RunEndReason.gauntletWon
        : RunEndReason.banked;
    final saved = await _finish(reason, won: true);
    return saved
        ? const GameActionResult.success()
        : const GameActionResult.failure('The result could not be saved yet.');
  }

  Future<GameActionResult> acceptRevive() async {
    if (phase != RunPhase.revive || !terminalPending || reviveUsed) {
      return const GameActionResult.failure('A revive is not available.');
    }
    reviveUsed = true;
    leaderboardEligible = false;
    terminalPending = false;
    failureReason = '';
    pendingTransition = null;
    state.handsLeft = 1;
    phase = RunPhase.game;
    isBusy = false;
    await _save(RunCheckpoint.reviveAccepted);
    notifyListeners();
    return const GameActionResult.success();
  }

  Future<GameActionResult> declineRevive() async {
    if (phase != RunPhase.revive) {
      return const GameActionResult.failure('No revive choice is active.');
    }
    final saved = await _finish(RunEndReason.defeated, won: false);
    return saved
        ? const GameActionResult.success()
        : const GameActionResult.failure('The result could not be saved yet.');
  }

  Future<GameActionResult> abandon() async {
    if (phase == RunPhase.ended) {
      return const GameActionResult.failure('The run has already ended.');
    }
    if (isBusy) {
      return const GameActionResult.failure(
        'Wait for the current score to finish before folding.',
      );
    }
    final saved = await _finish(
      RunEndReason.abandoned,
      won: false,
      abandoned: true,
    );
    return saved
        ? const GameActionResult.success()
        : const GameActionResult.failure('The fold could not be saved yet.');
  }

  Future<void> _beginHeat({required RunCheckpoint checkpoint}) async {
    phase = RunPhase.game;
    terminalPending = false;
    failureReason = '';
    pendingTransition = null;
    scoringPresentation = const ScoringPresentation();
    selectedCardIds.clear();
    state.endless = state.endless || state.stage > 12;
    ModifierSelector(state).assignForCurrentHeat();
    scoringEngine.ensureBossBlocks();
    state.stageScore = 0;
    state.handsPlayedThisStage = 0;
    state.handsLeft = state.effectiveHandsPerHeat;
    state.discardsLeft = state.effectiveDiscards;
    normalizeDeckIntegrity(state.cards, shatteredCount: state.shatteredCount);
    _stabilizeSculptedDeck();
    drawPile
      ..clear()
      ..addAll(state.cards.map((card) => card.copyWith(selected: false)));
    _shuffle(drawPile);
    heatDeck
      ..clear()
      ..addAll(drawPile);
    hand.clear();
    _refillHand();
    state.deckCardsLeft = drawPile.length;
    await _save(checkpoint);
    notifyListeners();
  }

  void _shuffle(List<PlayingCard> cards) {
    for (var index = cards.length - 1; index > 0; index--) {
      final other = (state.nextRandom(RandomStream.deck) * (index + 1)).floor();
      final temporary = cards[index];
      cards[index] = cards[other];
      cards[other] = temporary;
    }
  }

  void _refillHand() {
    while (hand.length < state.effectiveHandSize && drawPile.isNotEmpty) {
      hand.add(drawPile.removeLast());
    }
  }

  Future<void> _presentScoreEvents(
    List<PlayingCard> played,
    ScoreResult result,
  ) async {
    var visibleRank = 0;
    var visibleMultiplier = baseMultiplier;
    for (final event in result.events) {
      if (event.type == ScoreEventType.card ||
          event.type == ScoreEventType.rankJoker ||
          event.type == ScoreEventType.retrigger ||
          event.type == ScoreEventType.seven) {
        visibleRank += event.amount.round();
      }
      if (event.multiplier != null) visibleMultiplier = event.multiplier!;
      final cardIndex = event.cardIndex;
      scoringPresentation = ScoringPresentation(
        result: result,
        activeEvent: event,
        activeCardId:
            cardIndex != null && cardIndex >= 0 && cardIndex < played.length
            ? _cardId(played[cardIndex])
            : null,
        activeJokerIndex: event.jokerIndex != null && event.jokerIndex! >= 0
            ? event.jokerIndex
            : null,
        label:
            event.label ??
            (event.hit == true
                ? 'LUCKY HIT'
                : event.hit == false
                ? 'MISS'
                : ''),
        visibleRank: visibleRank,
        visibleMultiplier: visibleMultiplier,
      );
      notifyListeners();
      final isJoker = event.jokerIndex != null && event.jokerIndex! >= 0;
      await _wait(isJoker ? pacing.jokerBeat : pacing.cardBeat);
    }
  }

  Future<void> _clearHeat() async {
    pendingTransition = null;
    state.stagesCleared++;
    final heat = state.stage;
    final grade = gradeForPlays(state.handsPlayedThisStage);
    final interest = runCoinInterest(state.runCoins);
    final runCoins = runReward(heat);
    final accountCoins = state.isDaily ? 0 : accountReward(heat);
    state.runCoins += runCoins + interest + grade.bonus;
    scoringEngine.applyHeatClearJokerHooks();
    for (final modifier in state.modifiers) {
      modifiersSurvived.add(modifier.displayName);
    }
    inflationForShop = state.hasModifier(HeatModifier.inflation);
    lastHeatReward = HeatRewardSummary(
      heat: heat,
      grade: grade,
      runCoins: runCoins,
      accountCoins: accountCoins,
      interest: interest,
    );
    if (accountCoins > 0) {
      await _creditAccountOnce(
        suffix: 'heat:$heat',
        amount: accountCoins,
        kind: AccountMutationKind.heatReward,
        bestHeat: heat,
        bestClearedHeat: heat,
      );
    }
    await _save(RunCheckpoint.heatCleared);
    await _wait(pacing.transitionHold);

    final completed = state.isGauntlet
        ? state.stagesCleared >= gauntletHeats
        : !state.endless && state.stage >= 12;
    if (completed) {
      if (!state.isDaily) {
        await _creditAccountOnce(
          suffix: state.isGauntlet
              ? 'completion:gauntlet'
              : 'completion:standard',
          amount: standardCompletionBonus,
          kind: AccountMutationKind.completionReward,
          bestHeat: state.stage,
          bestClearedHeat: state.stage,
          bestScore: totalScore,
        );
      }
      await _settleStake();
      phase = RunPhase.victory;
      isBusy = false;
      await _save(RunCheckpoint.victoryReached);
      notifyListeners();
      return;
    }

    _openShop();
    isBusy = false;
    await _save(RunCheckpoint.shopChanged);
    notifyListeners();
  }

  void _openShop() {
    phase = RunPhase.shop;
    selectedCardIds.clear();
    scoringPresentation = const ScoringPresentation();
    shopBuysUsed = 0;
    suppliesBoughtThisShop.clear();
    pendingSwapOfferId = null;
    _rollJokerOffers(countForPity: true);
    _rollSupplyOffers();
  }

  void _rollJokerOffers({required bool countForPity}) {
    final pool = _availableJokerPool();
    final count = shopOfferCount(
      stage: state.stage,
      endless: state.endless,
      gauntlet: state.isGauntlet,
    );
    final wildPool = pool
        .where((joker) => joker.rarity == JokerRarity.wild)
        .toList();
    final forceWild =
        countForPity &&
        wildPool.isNotEmpty &&
        wildMissShops >= wildPityAfterShops;
    final result = <JokerDefinition>[];
    if (forceWild) {
      final index = (state.nextRandom(RandomStream.shop) * wildPool.length)
          .floor();
      final chosen = wildPool[index];
      result.add(chosen);
      pool.remove(chosen);
    }
    while (result.length < count && pool.isNotEmpty) {
      final totalWeight = pool.fold<double>(
        0,
        (total, joker) => total + shopRarityWeights[joker.rarity]!,
      );
      var roll = state.nextRandom(RandomStream.shop) * totalWeight;
      var chosenIndex = pool.length - 1;
      for (var index = 0; index < pool.length; index++) {
        roll -= shopRarityWeights[pool[index].rarity]!;
        if (roll <= 0) {
          chosenIndex = index;
          break;
        }
      }
      result.add(pool.removeAt(chosenIndex));
    }
    jokerOffers
      ..clear()
      ..addAll(result);
    lastWildPityForced = forceWild;
    if (countForPity) {
      if (result.any((joker) => joker.rarity == JokerRarity.wild)) {
        wildMissShops = 0;
      } else if (wildPool.isNotEmpty) {
        wildMissShops = math.min(wildPityAfterShops, wildMissShops + 1);
      }
    }
  }

  List<JokerDefinition> _availableJokerPool() {
    final equipped = state.jokerIds.toSet();
    return jokerCatalog
        .where(
          (joker) =>
              !equipped.contains(joker.id) &&
              (state.isDaily || unlockedJokerIds.contains(joker.id)),
        )
        .toList(growable: true);
  }

  void _rollSupplyOffers() {
    final pool = List<SupplyDefinition>.from(supplyCatalog);
    supplyOffers.clear();
    while (supplyOffers.length < 2 && pool.isNotEmpty) {
      final index = (state.nextRandom(RandomStream.shop) * pool.length).floor();
      supplyOffers.add(pool.removeAt(index));
    }
  }

  GameActionResult _validateSupply(SupplyId id, SupplySelection selection) {
    final cardIndex = selection.cardId == null
        ? -1
        : state.cards.indexWhere((card) => _cardId(card) == selection.cardId);
    switch (id) {
      case SupplyId.scalpel:
        if (state.cards.length <= minimumDeckSize) {
          return const GameActionResult.failure(
            'The deck cannot go below 24 cards.',
          );
        }
        if (cardIndex < 0) {
          return const GameActionResult.failure('Choose a card to destroy.');
        }
      case SupplyId.copier:
        if (cardIndex < 0 ||
            !canCopyCard(state.cards, state.cards[cardIndex])) {
          return const GameActionResult.failure(
            'Choose an unmodified original card with room for one copy.',
          );
        }
      case SupplyId.dye:
        final suit = selection.targetSuit;
        if (cardIndex < 0 ||
            suit == null ||
            !canDyeCard(state.cards, cardIndex, suit)) {
          return const GameActionResult.failure(
            'That card cannot be changed to the selected suit.',
          );
        }
      case SupplyId.enhance:
        final enhancement = selection.enhancement;
        if (cardIndex < 0 ||
            enhancement == null ||
            !canEnhanceCard(state.cards[cardIndex])) {
          return const GameActionResult.failure(
            'Choose an original card and an enhancement.',
          );
        }
      case SupplyId.boost:
        final type = selection.handType;
        if (type == null || (state.handLevels[type] ?? 0) >= maxHandLevel) {
          return const GameActionResult.failure(
            'Choose a hand type below level 5.',
          );
        }
    }
    return const GameActionResult.success();
  }

  void _applySupply(SupplyId id, SupplySelection selection) {
    switch (id) {
      case SupplyId.scalpel:
        final index = state.cards.indexWhere(
          (card) => _cardId(card) == selection.cardId,
        );
        final removed = state.cards.removeAt(index);
        state.destroyedCount++;
        _removeFromFutureHeatPiles(_cardId(removed));
      case SupplyId.copier:
        final card = state.cards.firstWhere(
          (candidate) => _cardId(candidate) == selection.cardId,
        );
        state.cards.add(
          card.copyWith(
            copied: true,
            clearEnhancement: true,
            uid: _nextCardId(),
            selected: false,
            isNew: false,
          ),
        );
        state.copiedCount++;
      case SupplyId.dye:
        final index = state.cards.indexWhere(
          (card) => _cardId(card) == selection.cardId,
        );
        final card = state.cards[index];
        final suit = selection.targetSuit!;
        final createsCopy =
            exactCardCount(state.cards, card.rank, suit, ignoreIndex: index) >
            0;
        state.cards[index] = card.copyWith(
          suit: suit,
          copied: createsCopy || card.copied,
          clearEnhancement: createsCopy,
        );
        state.copiedCount = state.cards.where((card) => card.copied).length;
      case SupplyId.enhance:
        final index = state.cards.indexWhere(
          (card) => _cardId(card) == selection.cardId,
        );
        state.cards[index] = state.cards[index].copyWith(
          enhancement: selection.enhancement,
        );
      case SupplyId.boost:
        final type = selection.handType!;
        state.handLevels[type] = (state.handLevels[type] ?? 0) + 1;
        boostsBought++;
    }
    final integrity = normalizeDeckIntegrity(
      state.cards,
      shatteredCount: state.shatteredCount,
    );
    _stabilizeSculptedDeck();
    state.destroyedCount = integrity.destroyedCount;
    state.copiedCount = integrity.copiedCount;
  }

  void _removeFromFutureHeatPiles(String cardId) {
    // Supplies are bought between Heats, but keeping this defensive makes the
    // controller safe if a future UI exposes them in another phase.
    drawPile.removeWhere((card) => _cardId(card) == cardId);
    hand.removeWhere((card) => _cardId(card) == cardId);
    heatDeck.removeWhere((card) => _cardId(card) == cardId);
    selectedCardIds.remove(cardId);
  }

  Future<void> _offerOrFinishFailure(String reason) async {
    pendingTransition = null;
    failureReason = reason;
    final reviveAvailable =
        reason == 'plays' && !state.isDaily && !reviveUsed && hand.isNotEmpty;
    if (reviveAvailable) {
      terminalPending = true;
      phase = RunPhase.revive;
      isBusy = false;
      await _save(RunCheckpoint.reviveOffered);
      notifyListeners();
      return;
    }
    await _finish(RunEndReason.defeated, won: false);
  }

  Future<bool> _settleStake() async {
    if (stake <= 0 || stakePaid) return true;
    var payout = 0;
    var accountDelta = 0;
    if (state.isGauntlet) {
      final base = gauntletStakePayout(stake, state.stagesCleared);
      accountDelta = 2 * base - stake;
      payout = math.max(0, accountDelta);
      stakeNet = 2 * (base - stake);
    } else {
      payout = stakePayout(
        stake,
        state.stagesCleared,
        difficulty: state.balanceDifficulty,
      );
      accountDelta = payout;
      stakeNet = payout - stake;
    }
    final accepted = await callbacks.mutateAccount(
      AccountMutation(
        claimId: '$runId:stake-settlement',
        kind: AccountMutationKind.stakeSettlement,
        coinDelta: accountDelta,
        runMode: state.mode,
      ),
    );
    if (accepted) {
      stakePaid = true;
      stakePayoutAmount = payout;
    }
    return accepted;
  }

  Future<bool> _finish(
    RunEndReason reason, {
    required bool won,
    bool abandoned = false,
  }) async {
    isBusy = true;
    if (!await _settleStake()) {
      isBusy = false;
      notifyListeners();
      return false;
    }
    final resultSaved = await callbacks.mutateAccount(
      AccountMutation(
        claimId: '$runId:finished',
        kind: AccountMutationKind.runFinished,
        bestHeat: state.isDaily || state.isGauntlet ? null : state.stage,
        bestClearedHeat: state.isDaily || state.isGauntlet
            ? null
            : state.stagesCleared,
        bestScore: state.isDaily ? null : totalScore,
        runMode: state.mode,
        dailyDate: state.isDaily ? dailyDate : null,
        dailyScore: state.isDaily ? totalScore : null,
        won: won,
        abandoned: abandoned,
        handsPlayed: handTypeCounts.values.fold<int>(0, (sum, n) => sum + n),
        handTypeCounts: Map<HandType, int>.unmodifiable(handTypeCounts),
        bestPlay: bestPlay,
        bestPlayType: bestPlayType,
        stagesCleared: state.stagesCleared,
        jokerIds: List<String>.unmodifiable(state.jokerIds),
        modifiersSurvived: List<String>.unmodifiable(modifiersSurvived),
        destroyedCount: state.destroyedCount,
        copiedCount: state.copiedCount,
        boostsBought: boostsBought,
        leaderboardEligible: leaderboardEligible,
        enhancedCount: state.cards
            .where((card) => card.enhancement != null)
            .length,
        glassDouble: glassDouble,
      ),
    );
    if (!resultSaved) {
      isBusy = false;
      notifyListeners();
      return false;
    }
    phase = RunPhase.ended;
    endReason = reason;
    terminalPending = false;
    pendingTransition = null;
    resultSummary = RunResultSummary(
      reason: reason,
      heatsCleared: state.stagesCleared,
      totalScore: totalScore,
      accountCoinsEarned: accountEarned,
      stake: stake,
      stakePayout: stakePayoutAmount,
      jokerIds: List<String>.unmodifiable(state.jokerIds),
    );
    await callbacks.clearRun();
    isBusy = false;
    notifyListeners();
    return true;
  }

  Future<bool> _creditAccountOnce({
    required String suffix,
    required int amount,
    required AccountMutationKind kind,
    int? bestHeat,
    int? bestClearedHeat,
    int? bestScore,
  }) async {
    if (amount <= 0 || state.isDaily) return false;
    final id = '$runId:$suffix';
    if (accountRewardIds.contains(id)) return true;
    final applied = await callbacks.mutateAccount(
      AccountMutation(
        claimId: id,
        kind: kind,
        coinDelta: amount,
        bestHeat: bestHeat,
        bestClearedHeat: bestClearedHeat,
        bestScore: bestScore,
        runMode: state.mode,
      ),
    );
    if (!applied) return false;
    accountRewardIds.add(id);
    accountEarned += amount;
    return true;
  }

  void _attributeJokerScore(ScoreResult result) {
    for (final event in result.events) {
      final index = event.jokerIndex;
      if (index == null || index < 0 || index >= state.jokerIds.length) {
        continue;
      }
      final id = state.jokerIds[index];
      final credit = event.type == ScoreEventType.xMult
          ? math.max(
              1,
              (result.total *
                      (event.amount.toDouble() - 1) /
                      math.max(1, result.multiplier))
                  .round(),
            )
          : event.amount.abs().round();
      jokerScore[id] = (jokerScore[id] ?? 0) + credit;
    }
  }

  Future<void> _save(RunCheckpoint checkpoint) async {
    await callbacks.writeRun(jsonEncode(toLegacyJson()), checkpoint);
  }

  Map<String, Object?> toLegacyJson() {
    final phaseName = switch (phase) {
      RunPhase.game => 'game',
      RunPhase.shop => 'shop',
      RunPhase.revive => 'revive',
      RunPhase.victory => 'wincomplete',
      RunPhase.ended => 'game',
    };
    return <String, Object?>{
      ..._legacyBase,
      'v': 1,
      '_savedAt': DateTime.now().millisecondsSinceEpoch,
      'phase': phaseName,
      'modId': state.modifier?.id,
      'modIds': state.modifiers.map((modifier) => modifier.id).toList(),
      'jokerIds': List<String>.from(state.jokerIds),
      'shopOfferIds': phase == RunPhase.shop
          ? jokerOffers.map((offer) => offer.id).toList()
          : null,
      'supplyOfferIds': phase == RunPhase.shop
          ? supplyOffers.map((offer) => offer.id.name).toList()
          : null,
      'runId': runId,
      'telemetryMode': state.mode.name,
      'dailyDate': dailyDate,
      'difficulty': state.difficulty.legacyId,
      'rngSeed': state.rngSeed,
      'rngCounters': state.rngCounters.toJson(),
      'pendingTransition': pendingTransition,
      'bossBlockedJokerIds': state.blockedJokerIds.toList(),
      'stage': state.stage,
      'endless': state.endless,
      'gauntlet': state.isGauntlet,
      'prevGauntletMod': state.previousGauntletModifierName,
      'stageScore': state.stageScore,
      'handsLeft': state.handsLeft,
      'discardsLeft': state.discardsLeft,
      'handsPlayedThisStage': state.handsPlayedThisStage,
      'runCoins': state.runCoins,
      'jokerState': Map<String, double>.from(state.jokerState),
      'cards': state.cards.map((card) => card.toJson()).toList(),
      'deck': drawPile.map((card) => card.toJson()).toList(),
      'hand': hand
          .map(
            (card) => card
                .copyWith(selected: selectedCardIds.contains(_cardId(card)))
                .toJson(),
          )
          .toList(),
      'heatDeck': heatDeck.map((card) => card.toJson()).toList(),
      'handLevels': <String, int>{
        for (final entry in state.handLevels.entries)
          entry.key.legacyName: entry.value,
      },
      'destroyedCount': state.destroyedCount,
      'copiedCount': state.copiedCount,
      'enhancedCount': state.cards
          .where((card) => card.enhancement != null)
          .length,
      'shatteredCount': state.shatteredCount,
      'handTypeCounts': <String, int>{
        for (final entry in handTypeCounts.entries)
          entry.key.legacyName: entry.value,
      },
      'bestPlayType': bestPlayType?.legacyName,
      'boostsBought': boostsBought,
      'modifiersSurvived': List<String>.from(modifiersSurvived),
      'jokerScore': Map<String, int>.from(jokerScore),
      'prevHandType': state.previousHandType?.legacyName,
      'bestPlay': bestPlay,
      'totalScore': totalScore,
      'stagesCleared': state.stagesCleared,
      'accountEarned': accountEarned,
      'accountRewardIds': List<String>.from(accountRewardIds),
      'reviveUsed': reviveUsed,
      'terminalPending': terminalPending,
      'failureReason': failureReason,
      'leaderboardEligible': leaderboardEligible,
      'wildMissShops': wildMissShops,
      'lastWildPityForced': lastWildPityForced,
      'startBoostJoker': startBoostJoker,
      'startBoostCost': startBoostCost,
      'stake': stake,
      'stakePaid': stakePaid,
      'stakePayout': stakePayoutAmount,
      'stakeNet': stakeNet,
      'glassDouble': glassDouble,
      'inflation': inflationForShop,
      'sortMode': sortMode.name,
      'lastRunReward': lastHeatReward?.runCoins ?? 0,
      'lastAcctReward': lastHeatReward?.accountCoins ?? 0,
      'lastInterest': lastHeatReward?.interest ?? 0,
      'supplyPurchaseCounts': <String, int>{
        for (final id in SupplyId.values) id.name: supplyLedger.count(id),
      },
      'supplyPurchaseLedger': supplyLedger.toJson(),
      'suppliesBoughtThisShop': suppliesBoughtThisShop
          .map((id) => id.name)
          .toList(),
      'boughtThisShop': jokerBuyLimitReached,
      'shopBuysUsed': shopBuysUsed,
      'guidedFirstRun': guidedFirstRun,
      'guideStep': _integer(_legacyBase['guideStep']),
      'shopGuideShown': _legacyBase['shopGuideShown'] == true,
      'heat12SequenceStarted': _legacyBase['heat12SequenceStarted'] == true,
      'heat12InterstitialAttempted':
          _legacyBase['heat12InterstitialAttempted'] == true,
      'doubleBaseCoins': _integer(_legacyBase['doubleBaseCoins']),
      'coinDoubleClaimed': _legacyBase['coinDoubleClaimed'] == true,
      'winPlacement': _integer(_legacyBase['winPlacement']),
      'provisionalWinScore': _integer(_legacyBase['provisionalWinScore']),
      'provisionalWinStamp': _integer(_legacyBase['provisionalWinStamp']),
    };
  }

  String encodeLegacySave() => jsonEncode(toLegacyJson());

  void _restore(Map<String, Object?> raw, LegacyRunPhase savedPhase) {
    phase = switch (savedPhase) {
      LegacyRunPhase.game => RunPhase.game,
      LegacyRunPhase.shop => RunPhase.shop,
      LegacyRunPhase.revive => RunPhase.revive,
      LegacyRunPhase.wincomplete => RunPhase.victory,
    };
    _stabilizeSculptedDeck();
    drawPile
      ..clear()
      ..addAll(_decodeCards(raw['deck'], 'd'));
    hand
      ..clear()
      ..addAll(_decodeCards(raw['hand'], 'h'));
    heatDeck
      ..clear()
      ..addAll(_decodeCards(raw['heatDeck'], 't'));
    selectedCardIds
      ..clear()
      ..addAll(hand.where((card) => card.selected).map(_cardId));
    state.deckCardsLeft = drawPile.length;
    pendingTransition = _objectMapOrNull(raw['pendingTransition']);
    totalScore = _integer(raw['totalScore']);
    accountEarned = _integer(raw['accountEarned']);
    shopBuysUsed = _integer(raw['shopBuysUsed']);
    wildMissShops = _integer(raw['wildMissShops']);
    boostsBought = _integer(raw['boostsBought']);
    bestPlay = _integer(raw['bestPlay']);
    bestPlayType = _parseHandType(raw['bestPlayType']);
    stakePayoutAmount = _integer(raw['stakePayout']);
    stakeNet = _integer(raw['stakeNet']);
    stakePaid = raw['stakePaid'] == true;
    reviveUsed = raw['reviveUsed'] == true;
    leaderboardEligible = raw['leaderboardEligible'] != false;
    inflationForShop = raw['inflation'] == true;
    lastWildPityForced = raw['lastWildPityForced'] == true;
    glassDouble = raw['glassDouble'] == true;
    terminalPending = raw['terminalPending'] == true;
    failureReason = _string(raw['failureReason']);
    sortMode = raw['sortMode'] == HandSortMode.suit.name
        ? HandSortMode.suit
        : HandSortMode.rank;
    supplyLedger = SupplyPurchaseLedger.fromLegacy(
      ledgerJson: raw['supplyPurchaseLedger'],
      purchaseCountsJson: raw['supplyPurchaseCounts'],
    );
    suppliesBoughtThisShop.addAll(
      _stringList(
        raw['suppliesBoughtThisShop'],
      ).map(_parseSupplyId).whereType(),
    );
    accountRewardIds.addAll(_stringList(raw['accountRewardIds']));
    modifiersSurvived.addAll(_stringList(raw['modifiersSurvived']));
    _restoreIntMap(raw['handTypeCounts'], (key, value) {
      final type = _parseHandType(key);
      if (type != null) handTypeCounts[type] = value;
    });
    _restoreIntMap(raw['jokerScore'], (key, value) {
      if (jokersById.containsKey(key)) jokerScore[key] = value;
    });
    if (phase == RunPhase.shop) {
      jokerOffers.addAll(
        _stringList(
          raw['shopOfferIds'],
        ).map((id) => jokersById[id]).whereType(),
      );
      supplyOffers.addAll(
        _stringList(raw['supplyOfferIds'])
            .map(_parseSupplyId)
            .whereType<SupplyId>()
            .map((id) => supplyCatalog.firstWhere((supply) => supply.id == id)),
      );
      // Old saves can be missing shop shelves. Deterministically replenish only
      // when there truly is no serialized offer.
      if (raw['shopOfferIds'] == null && jokerOffers.isEmpty) {
        _rollJokerOffers(countForPity: false);
      }
      if (raw['supplyOfferIds'] == null && supplyOffers.isEmpty) {
        _rollSupplyOffers();
      }
    }
    if (hand.isEmpty && phase == RunPhase.game && drawPile.isNotEmpty) {
      _refillHand();
    }
    if (terminalPending) phase = RunPhase.revive;
  }

  String _nextCardId() {
    final used = <String>{
      ...state.cards.map(_cardId),
      ...drawPile.map(_cardId),
      ...hand.map(_cardId),
    };
    var index = state.cards.length;
    while (used.contains('c$index')) {
      index++;
    }
    return 'c$index';
  }

  void _stabilizeSculptedDeck() {
    final stable = _withStableIds(state.cards, 'c');
    state.cards
      ..clear()
      ..addAll(stable);
  }
}

String _newRunId(int seed) =>
    '${DateTime.now().millisecondsSinceEpoch}-${seed.toUnsigned(32).toRadixString(16)}';

String _cardId(PlayingCard card) =>
    card.uid ?? '${card.rank.label}${card.suit.name}-${identityHashCode(card)}';

List<PlayingCard> _withStableIds(
  Iterable<PlayingCard> source,
  String prefix, {
  bool resetTransient = true,
}) {
  final result = <PlayingCard>[];
  final used = <String>{};
  var index = 0;
  for (final card in source) {
    var id = card.uid;
    if (id == null || id.isEmpty || used.contains(id)) {
      do {
        id = '$prefix${index++}';
      } while (used.contains(id));
    }
    used.add(id);
    result.add(
      card.copyWith(
        uid: id,
        selected: resetTransient ? false : card.selected,
        isNew: resetTransient ? false : card.isNew,
      ),
    );
  }
  return result;
}

List<PlayingCard> _decodeCards(Object? value, String prefix) {
  if (value is! List) return <PlayingCard>[];
  final decoded = <PlayingCard>[];
  for (final item in value) {
    if (item is! Map) continue;
    try {
      decoded.add(
        PlayingCard.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } on FormatException {
      // Invalid legacy cards are ignored, as in the recovered v7.1 client.
    }
  }
  return _withStableIds(decoded, prefix, resetTransient: false);
}

int _integer(Object? value, {int fallback = 0}) {
  final result = switch (value) {
    int number => number,
    num number => number.floor(),
    _ => int.tryParse('${value ?? ''}'),
  };
  return result ?? fallback;
}

String _string(Object? value, {String fallback = ''}) {
  final result = value?.toString() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _nullableString(Object? value) {
  final result = value?.toString() ?? '';
  return result.isEmpty ? null : result;
}

List<String> _stringList(Object? value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : <String>[];

Map<String, Object?>? _objectMapOrNull(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : null;

HandType? _parseHandType(Object? value) {
  final name = value?.toString() ?? '';
  if (name.isEmpty) return null;
  try {
    return HandType.fromLegacy(name);
  } on FormatException {
    return null;
  }
}

SupplyId? _parseSupplyId(String value) {
  for (final id in SupplyId.values) {
    if (id.name == value) return id;
  }
  return null;
}

void _restoreIntMap(
  Object? value,
  void Function(String key, int value) accept,
) {
  if (value is! Map) return;
  for (final entry in value.entries) {
    accept(entry.key.toString(), math.max(0, _integer(entry.value)));
  }
}

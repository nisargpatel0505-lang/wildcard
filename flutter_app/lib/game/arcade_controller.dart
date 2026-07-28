import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/arcade_rules.dart';
import '../domain/cards.dart';
import '../domain/economy.dart';
import '../domain/game_rules.dart';
import '../domain/joker_catalog.dart';
import '../domain/scoring_engine.dart';

enum ArcadePhase { choosing, resolving, shop, won, lost }

class ArcadeRunConfig {
  const ArcadeRunConfig({
    required this.length,
    required this.rngSeed,
    required this.discoveredJokerIds,
    this.initialJokerIds = const <String>[],
    this.initialDeck,
    this.turbo = false,
  });

  final ArcadeRunLength length;
  final int rngSeed;
  final Set<String> discoveredJokerIds;
  final List<String> initialJokerIds;
  final List<PlayingCard>? initialDeck;
  final bool turbo;
}

typedef ArcadeWait = Future<void> Function(Duration duration);

/// A deliberately isolated quick-run state machine.
///
/// Normal, Daily and Gauntlet continue to use [GameController]. Arcade only
/// shares [WildcardScoringEngine], so its three-card recognition, one-play
/// rounds and short choreography cannot change normal-mode saves or maths.
class ArcadeController extends ChangeNotifier {
  ArcadeController._({
    required this.config,
    required this.scoringState,
    required this._random,
    required this._wait,
  }) {
    turbo = config.turbo;
    _resetDrawPile(initial: true);
    _deal();
  }

  factory ArcadeController.start(ArcadeRunConfig config, {ArcadeWait? wait}) {
    final initialJokers = config.initialJokerIds
        .where(jokersById.containsKey)
        .toSet()
        .take(maxJokers)
        .toList();
    return ArcadeController._(
      config: config,
      scoringState: ScoringState(
        rngSeed: config.rngSeed,
        jokerIds: initialJokers,
        cards: config.initialDeck ?? baseCardSet(),
        handsLeft: 1,
        discardsLeft: 0,
      ),
      random: math.Random(config.rngSeed),
      wait: wait ?? Future<void>.delayed,
    );
  }

  final ArcadeRunConfig config;
  final ScoringState scoringState;
  final math.Random _random;
  final ArcadeWait _wait;
  final List<PlayingCard> _drawPile = <PlayingCard>[];
  final List<PlayingCard> hand = <PlayingCard>[];
  final Set<String> selectedCardIds = <String>{};
  final List<JokerDefinition> shopOffers = <JokerDefinition>[];

  ArcadePhase phase = ArcadePhase.choosing;
  int round = 1;
  int clearedRounds = 0;
  int totalScore = 0;
  int runCoins = 0;
  int? lastMilestone;
  ScoreResult? lastResult;
  ArcadeHandEvaluation? lastEvaluation;
  bool turbo = false;
  bool jokerBoughtThisShop = false;
  List<String> lastTriggerLabels = const <String>[];

  int get target => ArcadeRules.targetForRound(round);
  bool get isBusy => phase == ArcadePhase.resolving;
  bool get canScore =>
      phase == ArcadePhase.choosing &&
      ArcadeRules.canScoreSelection(selectedCardIds.length);
  List<PlayingCard> get selectedCards => hand
      .where((card) => selectedCardIds.contains(_cardId(card)))
      .toList(growable: false);
  List<JokerDefinition> get heldJokers => scoringState.jokerIds
      .map((id) => jokersById[id])
      .whereType<JokerDefinition>()
      .toList(growable: false);
  Duration get resolutionDuration => turbo
      ? const Duration(milliseconds: 650)
      : const Duration(milliseconds: 1850);

  void setTurbo(bool value) {
    if (turbo == value || isBusy) return;
    turbo = value;
    notifyListeners();
  }

  void toggleCard(String cardId) {
    if (phase != ArcadePhase.choosing) return;
    if (selectedCardIds.remove(cardId)) {
      notifyListeners();
      return;
    }
    if (selectedCardIds.length >= ArcadeRules.selectedCards ||
        !hand.any((card) => _cardId(card) == cardId)) {
      return;
    }
    selectedCardIds.add(cardId);
    notifyListeners();
  }

  Future<bool> scoreSelected() async {
    if (!canScore) return false;
    final played = selectedCards;
    lastMilestone = null;
    phase = ArcadePhase.resolving;
    scoringState
      ..stage = round
      ..stageScore = 0
      ..handsLeft = 1
      ..handsPlayedThisStage = 0
      ..runCoins = runCoins
      ..stagesCleared = clearedRounds
      ..deckCardsLeft = _drawPile.length;
    final evaluation = ArcadeRules.evaluate(
      played,
      activeJokerIds: scoringState.jokerIds.toSet(),
    );
    final scoringEngine = WildcardScoringEngine(scoringState);
    final result = scoringEngine.scoreHand(
      played,
      commit: true,
      resolvedHand: evaluation.authoritative,
    );
    scoringEngine.applyOnScored(result);
    runCoins = scoringState.runCoins;
    lastEvaluation = evaluation;
    lastResult = result;
    totalScore += result.total;
    lastTriggerLabels = <String>[
      for (final event in result.events)
        if (event.jokerIndex != null && event.jokerIndex! >= 0)
          '${heldJokers[event.jokerIndex!.clamp(0, heldJokers.length - 1)].name}: ${event.label ?? 'triggered'}',
    ];
    notifyListeners();
    await _wait(resolutionDuration);

    if (result.total < target) {
      phase = ArcadePhase.lost;
      notifyListeners();
      return true;
    }

    clearedRounds++;
    scoringState.stagesCleared = clearedRounds;
    scoringEngine.applyHeatClearJokerHooks();
    runCoins = scoringState.runCoins;
    final unused = hand
        .where((card) => !selectedCardIds.contains(_cardId(card)))
        .fold<int>(0, (sum, card) => sum + card.rank.value);
    // The two unplayed cards become a small shop resource rather than dead
    // information. It never touches the durable account economy.
    runCoins += 2 + unused ~/ 20;
    scoringState.runCoins = runCoins;
    lastMilestone = config.length.isEndless
        ? ArcadeRules.milestoneAfter(clearedRounds)
        : null;
    selectedCardIds.clear();

    if (ArcadeRules.completesAfter(config.length, clearedRounds)) {
      phase = ArcadePhase.won;
    } else if (ArcadeRules.opensShopAfter(clearedRounds)) {
      _openShop();
    } else {
      _advanceRound();
    }
    notifyListeners();
    return true;
  }

  bool buyJoker(String jokerId) {
    if (phase != ArcadePhase.shop ||
        jokerBoughtThisShop ||
        scoringState.jokerIds.length >= maxJokers) {
      return false;
    }
    final offer = shopOffers.where((joker) => joker.id == jokerId).firstOrNull;
    if (offer == null || runCoins < offer.price) return false;
    runCoins -= offer.price;
    scoringState
      ..runCoins = runCoins
      ..jokerIds.add(offer.id);
    jokerBoughtThisShop = true;
    shopOffers.removeWhere((joker) => joker.id == jokerId);
    notifyListeners();
    return true;
  }

  void leaveShop() {
    if (phase != ArcadePhase.shop) return;
    _advanceRound();
    notifyListeners();
  }

  void _advanceRound() {
    round++;
    lastResult = null;
    lastEvaluation = null;
    lastTriggerLabels = const <String>[];
    phase = ArcadePhase.choosing;
    _deal();
  }

  void _openShop() {
    phase = ArcadePhase.shop;
    jokerBoughtThisShop = false;
    final held = scoringState.jokerIds.toSet();
    final pool = jokerCatalog.where(
      (joker) =>
          config.discoveredJokerIds.contains(joker.id) &&
          !held.contains(joker.id) &&
          jokerShopEligibleAtStage(joker, stage: round, wildMinimumStage: 12),
    );
    shopOffers
      ..clear()
      ..addAll(
        rollWeightedJokerOffers(pool, count: 3, nextDouble: _random.nextDouble),
      );
  }

  void _deal() {
    if (_drawPile.length < ArcadeRules.dealtCards) _resetDrawPile();
    hand
      ..clear()
      ..addAll(_drawPile.take(ArcadeRules.dealtCards));
    _drawPile.removeRange(0, ArcadeRules.dealtCards);
    selectedCardIds.clear();
  }

  void _resetDrawPile({bool initial = false}) {
    final source = initial && config.initialDeck != null
        ? config.initialDeck!
        : baseCardSet();
    _drawPile
      ..clear()
      ..addAll(
        source.indexed.map(
          (entry) => entry.$2.copyWith(
            uid: 'arcade-$round-${entry.$1}-${_random.nextInt(1 << 20)}',
            selected: false,
            isNew: true,
          ),
        ),
      );
    if (!(initial && config.initialDeck != null)) _drawPile.shuffle(_random);
  }
}

String _cardId(PlayingCard card) => card.uid ?? card.toString();

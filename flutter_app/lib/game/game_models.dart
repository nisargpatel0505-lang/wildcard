import 'package:flutter/foundation.dart';

import '../domain/account_state.dart';
import '../domain/cards.dart';
import '../domain/economy.dart';
import '../domain/game_rules.dart';
import '../domain/joker_catalog.dart';
import '../domain/scoring_engine.dart';

enum RunPhase { game, shop, revive, victory, ended }

enum RunEndReason { defeated, abandoned, banked, dailyComplete, gauntletWon }

enum HandSortMode { rank, suit }

enum RunCheckpoint {
  runStarted,
  heatStarted,
  selectionChanged,
  discardCommitted,
  scoringPrepared,
  scoringCommitted,
  heatCleared,
  shopChanged,
  victoryReached,
  reviveOffered,
  reviveAccepted,
}

enum AccountMutationKind {
  runEntry,
  heatReward,
  completionReward,
  stakeSettlement,
  rewardedDouble,
  runFinished,
}

/// An idempotent request to mutate the durable account save.
///
/// The app layer must treat [claimId] as the idempotency key. Returning `true`
/// means the mutation is durably present (including when it had already been
/// applied after a process restart).
class AccountMutation {
  const AccountMutation({
    required this.claimId,
    required this.kind,
    this.coinDelta = 0,
    this.bestHeat,
    this.bestClearedHeat,
    this.bestScore,
    this.runMode,
    this.dailyDate,
    this.dailyScore,
    this.won,
    this.abandoned = false,
    this.handsPlayed = 0,
    this.handTypeCounts = const <HandType, int>{},
    this.bestPlay = 0,
    this.bestPlayType,
    this.stagesCleared = 0,
    this.jokerIds = const <String>[],
    this.modifiersSurvived = const <String>[],
    this.destroyedCount = 0,
    this.copiedCount = 0,
    this.boostsBought = 0,
    this.leaderboardEligible = true,
    this.enhancedCount = 0,
    this.glassDouble = false,
  });

  final String claimId;
  final AccountMutationKind kind;
  final int coinDelta;
  final int? bestHeat;
  final int? bestClearedHeat;
  final int? bestScore;
  final RunMode? runMode;
  final String? dailyDate;
  final int? dailyScore;
  final bool? won;
  final bool abandoned;
  final int handsPlayed;
  final Map<HandType, int> handTypeCounts;
  final int bestPlay;
  final HandType? bestPlayType;
  final int stagesCleared;
  final List<String> jokerIds;
  final List<String> modifiersSurvived;
  final int destroyedCount;
  final int copiedCount;
  final int boostsBought;
  final bool leaderboardEligible;
  final int enhancedCount;
  final bool glassDouble;
}

typedef RunSaveWriter =
    Future<void> Function(String encoded, RunCheckpoint checkpoint);
typedef RunSaveClearer = Future<void> Function();
typedef AccountMutationWriter = Future<bool> Function(AccountMutation mutation);
typedef ScoringWait = Future<void> Function(Duration duration);

class GamePersistenceCallbacks {
  const GamePersistenceCallbacks({
    required this.writeRun,
    required this.clearRun,
    required this.mutateAccount,
  });

  factory GamePersistenceCallbacks.memoryOnly() => GamePersistenceCallbacks(
    writeRun: (_, _) async {},
    clearRun: () async {},
    mutateAccount: (_) async => true,
  );

  final RunSaveWriter writeRun;
  final RunSaveClearer clearRun;
  final AccountMutationWriter mutateAccount;
}

class GameRunConfig {
  const GameRunConfig({
    required this.rngSeed,
    this.runId,
    this.mode = RunMode.normal,
    this.difficulty = RunDifficulty.medium,
    this.dailyDate = '',
    this.unlockedJokerIds = const <String>{},
    this.initialJokerIds = const <String>[],
    this.initialDeck,
    this.startBoostJokerId,
    this.startBoostCost = 0,
    this.stake = 0,
    this.guidedFirstRun = false,
    this.scoringPace = ScoringPace.normal,
  });

  final int rngSeed;
  final String? runId;
  final RunMode mode;
  final RunDifficulty difficulty;
  final String dailyDate;
  final Set<String> unlockedJokerIds;
  final List<String> initialJokerIds;
  final List<PlayingCard>? initialDeck;
  final String? startBoostJokerId;
  final int startBoostCost;
  final int stake;
  final bool guidedFirstRun;
  final ScoringPace scoringPace;
}

class ScoringPacing {
  const ScoringPacing({
    required this.leadIn,
    required this.cardBeat,
    required this.jokerBeat,
    required this.resultHold,
    required this.transitionHold,
  });

  /// These are onset gaps, not effect lifetimes. Card/Joker visuals deliberately
  /// outlive the gap so neighbouring beats overlap like the WebView timeline.
  /// This keeps labels readable without turning a multi-Joker hand into a chain
  /// of fully serial animations.
  static const normal = ScoringPacing(
    // WebView effective Normal: beat(180/220/360) × 1.85.
    leadIn: Duration(milliseconds: 333),
    cardBeat: Duration(milliseconds: 407),
    jokerBeat: Duration(milliseconds: 666),
    resultHold: Duration(milliseconds: 1400),
    transitionHold: Duration(milliseconds: 600),
  );

  /// Fast preserves order and a readable chip hold while shortening onset gaps.
  static const fast = ScoringPacing(
    leadIn: Duration(milliseconds: 187),
    cardBeat: Duration(milliseconds: 229),
    jokerBeat: Duration(milliseconds: 270),
    resultHold: Duration(milliseconds: 620),
    transitionHold: Duration(milliseconds: 320),
  );

  final Duration leadIn;
  final Duration cardBeat;
  final Duration jokerBeat;
  final Duration resultHold;
  final Duration transitionHold;
}

enum ScorePresentationPhase { idle, leadIn, beat, finale, complete }

enum ScoreChipStyle {
  card,
  joker,
  multiplier,
  modifier,
  suspense,
  miss,
  jackpot,
}

/// One short-lived score label attached to a played card.
///
/// A scoring beat can begin before the previous label has finished its
/// 700 ms rise. Keeping these labels in presentation state lets neighbouring
/// cards overlap exactly as they do in the WebView without rebuilding or
/// delaying the authoritative scoring sequence.
@immutable
class ScoreVisualChip {
  const ScoreVisualChip({
    required this.sequence,
    required this.cardId,
    required this.label,
    required this.style,
    required this.start,
    required this.duration,
  });

  final int sequence;
  final String cardId;
  final String label;
  final ScoreChipStyle style;
  final Duration start;
  final Duration duration;

  Duration get end => start + duration;
}

class ScoringPresentation {
  const ScoringPresentation({
    this.result,
    this.handSnapshot = const <PlayingCard>[],
    this.activeEvent,
    this.activeCardId,
    this.activeJokerIndex,
    this.label = '',
    this.visibleRawRank = 0,
    this.visibleValuePoints = 0,
    this.visibleMultiplier = baseMultiplier,
    this.visibleTotal = 0,
    this.scoringCardIds = const <String>{},
    this.settledCardIds = const <String>{},
    this.activeChips = const <ScoreVisualChip>[],
    this.sequence = 0,
    this.chipStyle = ScoreChipStyle.card,
    this.phase = ScorePresentationPhase.idle,
    this.finalScoreVisible = false,
    this.complete = false,
  });

  final ScoreResult? result;
  final List<PlayingCard> handSnapshot;
  final ScoreEvent? activeEvent;
  final String? activeCardId;
  final int? activeJokerIndex;
  final String label;
  final int visibleRawRank;
  final int visibleValuePoints;
  final double visibleMultiplier;
  final int visibleTotal;
  final Set<String> scoringCardIds;
  final Set<String> settledCardIds;
  final List<ScoreVisualChip> activeChips;
  final int sequence;
  final ScoreChipStyle chipStyle;
  final ScorePresentationPhase phase;
  final bool finalScoreVisible;
  final bool complete;

  bool get isActive => phase != ScorePresentationPhase.idle;
}

class HeatRewardSummary {
  const HeatRewardSummary({
    required this.heat,
    required this.grade,
    required this.runCoins,
    required this.accountCoins,
    required this.interest,
  });

  final int heat;
  final HeatGrade grade;
  final int runCoins;
  final int accountCoins;
  final int interest;
}

class RunResultSummary {
  const RunResultSummary({
    required this.reason,
    required this.heatsCleared,
    required this.totalScore,
    required this.accountCoinsEarned,
    required this.stake,
    required this.stakePayout,
    required this.jokerIds,
  });

  final RunEndReason reason;
  final int heatsCleared;
  final int totalScore;
  final int accountCoinsEarned;
  final int stake;
  final int stakePayout;
  final List<String> jokerIds;
}

class SupplySelection {
  const SupplySelection({
    this.cardId,
    this.targetSuit,
    this.enhancement,
    this.handType,
  });

  final String? cardId;
  final CardSuit? targetSuit;
  final CardEnhancement? enhancement;
  final HandType? handType;
}

class ShopSnapshot {
  const ShopSnapshot({
    required this.jokerOffers,
    required this.supplyOffers,
    required this.boughtSupplyIds,
    required this.jokerBuysUsed,
    required this.jokerBuyLimit,
    required this.inflation,
  });

  final List<JokerDefinition> jokerOffers;
  final List<SupplyDefinition> supplyOffers;
  final Set<SupplyId> boughtSupplyIds;
  final int jokerBuysUsed;
  final int jokerBuyLimit;
  final bool inflation;
}

class GameActionResult {
  const GameActionResult._(this.ok, this.message);

  const GameActionResult.success([String message = '']) : this._(true, message);
  const GameActionResult.failure(String message) : this._(false, message);

  final bool ok;
  final String message;
}

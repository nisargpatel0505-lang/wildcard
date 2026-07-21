import 'dart:convert';

import 'cards.dart';
import 'deck_integrity.dart';
import 'economy.dart';
import 'game_rules.dart';
import 'random_streams.dart';

const String legacyAccountSaveKey = 'wildcard_save_v1';
const String legacyRunSaveKey = 'wildcard_run_v1';
const String legacyPrivacyAcceptanceKey = 'wildcard_privacy_accept_v1';
const String legacyCloudOwnerKey = 'wildcard_cloud_owner_v2';

/// Fields written by `saveAccount()` in the v7.1.0 phone client.
///
/// Keep this list explicit: the Flutter upgrade must migrate from Capacitor's
/// `CapacitorStorage.xml`, and cloud `accountJson` remains an opaque JSON string.
const Set<String> legacyAccountSaveFields = <String>{
  '_savedAt',
  'coins',
  'unlocked',
  'tutorialDone',
  'starterGiftClaimed',
  'firstRunStarted',
  'firstLossCoached',
  'tutorialChestClaimed',
  'bestHeat',
  'bestScore',
  'muted',
  'topRuns',
  'speed',
  'pacingVersion',
  'noAds',
  'lastDaily',
  'dailyStreak',
  'achievements',
  'achievementClaimed',
  'adDate',
  'adViews',
  'cosmeticsOwned',
  'equipped',
  'title',
  'missionWeek',
  'missionStats',
  'missionClaimed',
  'missionSet',
  'missionRotation',
  'missionRefreshDate',
  'dailyRunDate',
  'dailyBest',
  'bestClearedHeat',
  'musicOn',
  'playerName',
  'stats',
  'runLog',
  'rewardClaims',
  'purchaseClaims',
};

/// `RUN_FIELDS` plus the envelope fields written by `saveRunState()`.
const Set<String> legacyRunSaveFields = <String>{
  'v',
  '_savedAt',
  'phase',
  'modId',
  'modIds',
  'jokerIds',
  'shopOfferIds',
  'supplyOfferIds',
  'runId',
  'telemetryMode',
  'dailyDate',
  'difficulty',
  'rngSeed',
  'rngCounters',
  'pendingTransition',
  'bossBlockedJokerIds',
  'stage',
  'endless',
  'gauntlet',
  'prevGauntletMod',
  'stageScore',
  'handsLeft',
  'discardsLeft',
  'handsPlayedThisStage',
  'runCoins',
  'jokerState',
  'cards',
  'deck',
  'hand',
  'heatDeck',
  'handLevels',
  'destroyedCount',
  'copiedCount',
  'handTypeCounts',
  'bestPlayType',
  'boostsBought',
  'modifiersSurvived',
  'jokerScore',
  'prevHandType',
  'bestPlay',
  'totalScore',
  'stagesCleared',
  'accountEarned',
  'accountRewardIds',
  'reviveUsed',
  'terminalPending',
  'failureReason',
  'leaderboardEligible',
  'heat12SequenceStarted',
  'heat12InterstitialAttempted',
  'doubleBaseCoins',
  'coinDoubleClaimed',
  'wildMissShops',
  'lastWildPityForced',
  'startBoostJoker',
  'startBoostCost',
  'stake',
  'stakePaid',
  'stakePayout',
  'stakeNet',
  'enhancedCount',
  'shatteredCount',
  'glassDouble',
  'inflation',
  'sortMode',
  'lastRunReward',
  'lastAcctReward',
  'lastInterest',
  'supplyPurchaseCounts',
  'supplyPurchaseLedger',
  'suppliesBoughtThisShop',
  'boughtThisShop',
  'shopBuysUsed',
  'guidedFirstRun',
  'guideStep',
  'shopGuideShown',
  'winPlacement',
  'provisionalWinScore',
  'provisionalWinStamp',
};

enum LegacyRunPhase { game, shop, revive, wincomplete }

/// Feature-detecting adapter for v6.9.14 and v7.1.0 active-run JSON.
///
/// It deliberately preserves unknown fields on export. That makes a Flutter
/// rollback less destructive and avoids losing server-added metadata.
class LegacyRunSave {
  LegacyRunSave._(this.raw);

  factory LegacyRunSave.decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map) throw const FormatException('Run save is not an object');
    final raw = value.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    if (_int(raw['v'], fallback: 0) != 1) {
      throw const FormatException('Unsupported run save schema');
    }
    if (raw['hand'] is! List) {
      throw const FormatException('Run save has no resumable hand');
    }
    return LegacyRunSave._(raw);
  }

  final Map<String, Object?> raw;

  LegacyRunPhase get phase => LegacyRunPhase.values.firstWhere(
    (candidate) => candidate.name == raw['phase'],
    orElse: () => LegacyRunPhase.game,
  );

  RunMode get mode {
    if (raw['telemetryMode'] == 'daily') return RunMode.daily;
    if (raw['gauntlet'] == true || raw['telemetryMode'] == 'gauntlet') {
      return RunMode.gauntlet;
    }
    return RunMode.normal;
  }

  RunDifficulty get difficulty => mode == RunMode.normal
      ? RunDifficulty.fromLegacy(raw['difficulty'])
      : RunDifficulty.medium;

  List<HeatModifier> get modifiers {
    final source = raw['modIds'] is List && (raw['modIds'] as List).isNotEmpty
        ? raw['modIds'] as List
        : <Object?>[raw['modId']];
    final result = <HeatModifier>[];
    for (final value in source) {
      final modifier = HeatModifier.fromLegacy(value);
      if (modifier != null && !result.contains(modifier)) result.add(modifier);
    }
    return result;
  }

  SupplyPurchaseLedger get supplyLedger => SupplyPurchaseLedger.fromLegacy(
    ledgerJson: raw['supplyPurchaseLedger'],
    purchaseCountsJson: raw['supplyPurchaseCounts'],
  );

  List<PlayingCard> get sculptedDeck {
    final cards = _cards(raw['cards']);
    normalizeDeckIntegrity(cards, shatteredCount: _int(raw['shatteredCount']));
    return cards;
  }

  ScoringState toScoringState() {
    final levels = <HandType, int>{};
    final rawLevels = raw['handLevels'];
    if (rawLevels is Map) {
      for (final type in HandType.values) {
        final level = _int(rawLevels[type.legacyName]);
        if (level > 0) levels[type] = level.clamp(0, maxHandLevel);
      }
    }
    final rawJokerState = raw['jokerState'];
    final jokerState = <String, double>{};
    if (rawJokerState is Map) {
      for (final entry in rawJokerState.entries) {
        final value = num.tryParse('${entry.value}');
        if (value != null) jokerState[entry.key.toString()] = value.toDouble();
      }
    }
    return ScoringState(
      rngSeed: _int(raw['rngSeed']),
      rngCounters: RandomCounters.fromJson(raw['rngCounters']),
      mode: mode,
      difficulty: difficulty,
      stage: _int(raw['stage'], fallback: 1).clamp(1, 999999),
      stageScore: _int(raw['stageScore']),
      handsLeft: _int(raw['handsLeft'], fallback: handsPerHeat),
      discardsLeft: _int(raw['discardsLeft'], fallback: discardsPerHeat),
      handsPlayedThisStage: _int(raw['handsPlayedThisStage']),
      runCoins: _int(raw['runCoins']),
      jokerIds: _strings(raw['jokerIds']),
      blockedJokerIds: _strings(raw['bossBlockedJokerIds']).toSet(),
      jokerState: jokerState,
      cards: sculptedDeck,
      deckCardsLeft: raw['deck'] is List ? (raw['deck'] as List).length : 0,
      handLevels: levels,
      destroyedCount: _int(raw['destroyedCount']),
      copiedCount: _int(raw['copiedCount']),
      shatteredCount: _int(raw['shatteredCount']),
      stagesCleared: _int(raw['stagesCleared']),
      modifierStack: modifiers,
      previousHandType: _handType(raw['prevHandType']),
      previousGauntletModifierName: raw['prevGauntletMod']?.toString(),
      endless: raw['endless'] == true,
    );
  }

  String encodePreservingUnknowns({Map<String, Object?> overrides = const {}}) {
    return jsonEncode(<String, Object?>{...raw, ...overrides});
  }
}

List<PlayingCard> _cards(Object? value) {
  if (value is! List) return baseCardSet();
  final result = <PlayingCard>[];
  for (final item in value) {
    if (item is! Map) continue;
    try {
      result.add(
        PlayingCard.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } on FormatException {
      // v7.1 drops malformed cards, then repairs the deck to its 24-card floor.
    }
  }
  return result;
}

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];

HandType? _handType(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return HandType.fromLegacy(value);
  } on FormatException {
    return null;
  }
}

int _int(Object? value, {int fallback = 0}) {
  final parsed = switch (value) {
    int number => number,
    num number => number.floor(),
    _ => int.tryParse('${value ?? ''}'),
  };
  return parsed ?? fallback;
}

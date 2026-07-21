import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../core/daily_utc_date.dart';
import '../domain/account_state.dart';
import '../domain/economy.dart';
import '../domain/game_rules.dart';
import '../domain/joker_catalog.dart';
import '../domain/legacy_save_schema.dart';
import '../domain/progression_catalog.dart';
import '../game/game_models.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/billing_service.dart';
import '../services/daily_score_outbox.dart';
import '../services/firebase_service.dart';
import '../services/local_save_repository.dart';
import '../services/pi_service.dart';
import '../services/play_games_service.dart';
import 'developer_access.dart';

enum AppBootState { starting, privacyRequired, ready, failed }

enum CloudLinkState { guest, connecting, ready, offline, accountConflict }

class CloudAccountConflict implements Exception {
  const CloudAccountConflict();

  @override
  String toString() =>
      'This phone save belongs to another Google account. Sign out or reset '
      'phone progress before linking this account.';
}

/// Coordinates durable progress and every consent-gated platform service.
///
/// Gameplay remains local-first. Cloud writes are optimistic and versioned;
/// the server copy wins a genuine concurrent-edit conflict and the displaced
/// local copy is retained for diagnostics instead of being unioned into a
/// second economy.
class AppController extends ChangeNotifier {
  AppController._(
    this._local, {
    required this.account,
    required this.activeRunJson,
    required this.migrationResult,
  }) : firebase = FirebaseService(),
       ads = AdService(),
       audio = AudioService(),
       playGames = PlayGamesService(),
       pi = PiService() {
    billing = BillingService(firebase);
    _dailyScoreOutbox = DailyScoreOutbox(_local);
    billing.persistVerifiedGrant = _persistVerifiedPlayGrant;
    ads.setNoAds(account.noAds);
    audio.setEffectsEnabled(!account.muted);
  }

  static const _cloudPrefix = 'flutter_cloud_v1:';
  static const _guestBackupKey = '${_cloudPrefix}guest_backup';

  final LocalSaveRepository _local;
  final MigrationResult migrationResult;
  final FirebaseService firebase;
  final AdService ads;
  final AudioService audio;
  final PlayGamesService playGames;
  final PiService pi;
  late final BillingService billing;
  late final DailyScoreOutbox _dailyScoreOutbox;

  AppBootState bootState = AppBootState.starting;
  CloudLinkState cloudState = CloudLinkState.guest;
  AccountState account;
  String? activeRunJson;
  Object? bootError;
  Object? cloudError;
  String cloudStatus = 'Guest — phone save only';
  bool onlineServicesStarted = false;
  bool cloudBusy = false;
  int cloudSaveVersion = 0;
  int cloudProgressVersion = 0;
  int billingAdjustmentApplied = 0;
  int billingAdjustmentTotal = 0;

  Timer? _cloudTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<bool>? _cloudWriteInFlight;
  Future<void>? _dailyRetryInFlight;
  bool _cloudWritePending = false;
  bool _disposed = false;

  bool get privacyAccepted => _local.privacyAccepted;
  bool get hasResumableRun => activeRunJson != null;
  bool get signedIn => firebase.signedIn;
  bool get cloudReady => cloudState == CloudLinkState.ready;

  LegacyRunSave? get activeRun {
    final raw = activeRunJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return LegacyRunSave.decode(raw);
    } on FormatException {
      return null;
    }
  }

  static Future<AppController> bootstrap() async {
    final local = await LocalSaveRepository.open();
    final migration = await local.migrateLegacySaveIfNeeded();
    AccountState account;
    Object? loadError;
    final raw = local.accountJson;
    if (raw == null || raw.isEmpty) {
      account = AccountState();
    } else {
      try {
        account = AccountState.decode(raw);
      } catch (error) {
        loadError = error;
        await local.writeString(
          'flutter_corrupt_account_${DateTime.now().millisecondsSinceEpoch}',
          raw,
        );
        account = AccountState();
      }
    }

    final releaseSafeAccount = releaseSafeDeveloperAccount(account);
    final clearedDeveloperState = !identical(releaseSafeAccount, account);
    if (clearedDeveloperState) {
      account = releaseSafeAccount;
      await local.writeAccountJson(account.encode());
      // A run created with granted Jokers or coins must not cross into the
      // public build after the account itself has been restored.
      await local.clearRun();
    }

    String? runJson = clearedDeveloperState ? null : local.runJson;
    if (runJson != null) {
      try {
        LegacyRunSave.decode(runJson);
      } catch (_) {
        await local.writeString(
          'flutter_corrupt_run_${DateTime.now().millisecondsSinceEpoch}',
          runJson,
        );
        runJson = null;
      }
    }

    final controller = AppController._(
      local,
      account: account,
      activeRunJson: runJson,
      migrationResult: migration,
    );
    controller.bootError = loadError ?? migration.error;
    await controller._normalizeProgression();
    controller.bootState = controller.privacyAccepted
        ? AppBootState.ready
        : AppBootState.privacyRequired;
    if (controller.privacyAccepted) {
      unawaited(controller.startConsentGatedServices());
      unawaited(controller.audio.sync(enabled: controller.account.musicOn));
    }
    return controller;
  }

  Future<void> acceptPrivacyPolicy() async {
    await _local.acceptPrivacy();
    bootState = AppBootState.ready;
    notifyListeners();
    if (privacyAccepted) {
      unawaited(audio.sync(enabled: account.musicOn));
    }
    await startConsentGatedServices();
  }

  Future<void> startConsentGatedServices() async {
    if (onlineServicesStarted || !privacyAccepted) return;
    onlineServicesStarted = true;
    notifyListeners();

    // Analytics is deliberately consent-gated too. The first-launch screen
    // promises that nothing is sent before acceptance, including the anonymous
    // app-open counter.
    unawaited(() async {
      try {
        await pi.initialize();
        pi.queueAppOpen();
      } catch (_) {
        // Product counters are optional and must never affect local play.
      }
    }());

    final firebaseReady = await firebase.initializeAfterPrivacyAcceptance();
    await Future.wait<void>([
      ads.initializeAfterPrivacyAcceptance().then((_) {}),
      playGames.initializeAfterPrivacyAcceptance().then((_) {}),
      billing.initializeAfterPrivacyAcceptance().then((_) {}),
    ]);
    ads.setNoAds(account.noAds);
    unawaited(audio.sync(enabled: account.musicOn));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen(
        (results) {
          if (results.any((result) => result != ConnectivityResult.none)) {
            unawaited(_retryPendingDailyScores());
          }
        },
        onError: (_) {
          // Launch and sign-in also retry, so a platform stream failure
          // cannot lose a score or affect local play.
        },
      );
    }
    if (firebaseReady && firebase.signedIn) {
      if (developerToolsUnlocked(account)) {
        cloudState = CloudLinkState.offline;
        cloudStatus = 'Developer tools active — cloud backup paused';
      } else {
        unawaited(_retryPendingDailyScores());
        await reconcileCloudAccount(announce: false);
        await restorePlayEntitlements();
        await billing.recoverUnfinishedPurchases();
        await _retryPendingDailyScores();
      }
    }
    notifyListeners();
  }

  Future<void> mutateAccount(
    void Function(AccountState account) mutation, {
    bool syncCloud = true,
  }) async {
    mutation(account);
    await persistAccount(syncCloud: syncCloud);
  }

  ProgressionGates get progressionGates => ProgressionGates(
    tutorialDone: account.tutorialDone,
    bestClearedHeat: account.bestClearedHeat,
    unlockedJokers: publicUnlockedJokerCount(account.unlockedJokerIds),
  );

  ProgressionSnapshot get progressionSnapshot => ProgressionSnapshot(
    bestHeat: account.bestHeat,
    bestClearedHeat: account.bestClearedHeat,
    bestScore: account.bestScore,
    coins: account.coins,
    unlockedJokers: publicUnlockedJokerCount(account.unlockedJokerIds),
    cosmeticsOwned: account.cosmeticsOwned.length + defaultCosmeticIds.length,
    titleEquipped: account.title.isNotEmpty,
    gauntletWins: account.stats.gauntletWins,
    runsPlayed: account.stats.runs,
    handsPlayed: account.stats.hands,
    achievementsEarned: account.achievements.length,
    handTypeCounts: <String, int>{
      for (final entry in account.unknownFields.entries)
        if (entry.key.startsWith('hand:') && entry.value is num)
          entry.key.substring(5): (entry.value! as num).toInt(),
    },
  );

  DailyLoginOffer get dailyLoginOffer {
    DateTime? lastClaim;
    if (account.lastDaily.isNotEmpty) {
      lastClaim = DateTime.tryParse(account.lastDaily);
    }
    return nextDailyLoginOffer(
      now: DateTime.now(),
      lastClaim: lastClaim,
      currentStreak: account.dailyStreak,
    );
  }

  bool get weeklyMissionsNeedAttention {
    for (final id in account.missionSet) {
      final mission = weeklyContractCatalog
          .where((candidate) => candidate.id == id)
          .firstOrNull;
      if (mission != null &&
          (account.missionStats[mission.stat] ?? 0) >= mission.target &&
          account.missionClaimed[id] != true) {
        return true;
      }
    }
    return false;
  }

  Future<void> completeTutorial() async {
    account.tutorialDone = true;
    account.unlockedJokerIds.addAll(tutorialStarterJokerIds);
    if (!account.starterGiftClaimed) {
      account.starterGiftClaimed = true;
      account.coins += starterGiftCoins;
    }
    await persistAccount();
  }

  Future<int> claimDailyLoginReward() async {
    final offer = dailyLoginOffer;
    if (!offer.available) return 0;
    account.dailyStreak = offer.streak;
    account.lastDaily = _todayString();
    account.coins += offer.reward;
    await persistAccount();
    return offer.reward;
  }

  Future<bool> buyCosmetic(String id) async {
    final cosmetic = cosmeticById(id);
    if (cosmetic == null ||
        cosmetic.isDefault ||
        account.cosmeticsOwned.contains(id) ||
        account.coins < cosmetic.price) {
      return false;
    }
    account.coins -= cosmetic.price;
    account.cosmeticsOwned.add(id);
    account.equipped = _equippedWith(cosmetic.kind, id);
    await persistAccount();
    return true;
  }

  Future<bool> equipCosmetic(String id) async {
    final cosmetic = cosmeticById(id);
    if (cosmetic == null || !_ownsCosmetic(id)) return false;
    account.equipped = _equippedWith(cosmetic.kind, id);
    await persistAccount();
    return true;
  }

  /// Permanently unlocks one chosen Joker at the v7.1 collection price.
  ///
  /// Ownership and the coin debit are changed together before persistence, so
  /// a repeated tap cannot charge twice while the first disk/cloud write is in
  /// flight.
  Future<bool> unlockJoker(String id) async {
    final joker = jokerCatalog
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (joker == null || account.unlockedJokerIds.contains(id)) return false;
    final cost = joker.collectionUnlockCost;
    if (account.coins < cost) return false;
    account.coins -= cost;
    account.unlockedJokerIds.add(id);
    await persistAccount();
    return true;
  }

  Future<JokerDefinition?> openJokerVault(JokerChestTier tier) async {
    final chest = jokerChests[tier]!;
    final locked = jokerCatalog
        .where((joker) => !account.unlockedJokerIds.contains(joker.id))
        .toList(growable: false);
    final price = chest.price(
      publicUnlockedJokerCount(account.unlockedJokerIds),
    );
    if (account.coins < price || chest.effectiveOdds(locked).isEmpty) {
      return null;
    }
    final random = math.Random.secure();
    final reward = chest.roll(
      locked,
      rarityRoll: random.nextDouble(),
      itemRoll: random.nextDouble(),
    );
    if (reward == null) return null;
    account.coins -= price;
    account.unlockedJokerIds.add(reward.id);
    // Persist before any Vault animation so process death cannot lose a reward.
    await persistAccount();
    return reward;
  }

  Future<CosmeticDefinition?> openCosmeticVault() async {
    final locked = cosmeticCatalog
        .where(
          (cosmetic) =>
              !cosmetic.isDefault &&
              !account.cosmeticsOwned.contains(cosmetic.id),
        )
        .toList(growable: false);
    if (account.coins < cosmeticVaultPrice || locked.isEmpty) return null;
    final random = math.Random.secure();
    final reward = rollCosmeticVault(
      locked,
      themeRoll: random.nextDouble(),
      itemRoll: random.nextDouble(),
    );
    if (reward == null) return null;
    account.coins -= cosmeticVaultPrice;
    account.cosmeticsOwned.add(reward.id);
    await persistAccount();
    return reward;
  }

  Future<int> claimWeeklyMission(String id) async {
    if (!account.missionSet.contains(id) ||
        account.missionClaimed[id] == true) {
      return 0;
    }
    final mission = weeklyContractCatalog
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (mission == null ||
        (account.missionStats[mission.stat] ?? 0) < mission.target) {
      return 0;
    }
    account.missionClaimed[id] = true;
    account.coins += mission.reward;
    await persistAccount();
    return mission.reward;
  }

  Future<bool> refreshWeeklyMissionsWithRewardedAd() async {
    final today = _todayString();
    if (account.missionRefreshDate == today ||
        weeklyMissionsNeedAttention ||
        rewardedViewsLeftToday <= 0) {
      return false;
    }
    if (!await _completeRewardedPlacement()) return false;
    final previousMissionIds = List<String>.from(account.missionSet);
    account.missionRotation += 1;
    account.missionRefreshDate = today;
    account.missionSet
      ..clear()
      ..addAll(
        chooseWeeklyContracts(
          weekKey: account.missionWeek,
          rotation: account.missionRotation,
          currentIds: previousMissionIds,
          claimedIds: account.missionClaimed.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key),
        ),
      );
    await persistAccount();
    return true;
  }

  Future<int> claimAchievement(String id, ProgressionSnapshot snapshot) async {
    final definition = achievementCatalog
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (definition == null ||
        !(achievementIsDone(id, snapshot) ||
            account.achievements[id] != null) ||
        account.achievementClaimed[id] == true) {
      return 0;
    }
    account.achievements[id] = 1;
    account.achievementClaimed[id] = true;
    account.coins += definition.reward;
    await persistAccount();
    return definition.reward;
  }

  Future<void> equipTitle(String id, ProgressionSnapshot snapshot) async {
    if (!titleIsUnlocked(id, snapshot)) return;
    account.title = id;
    await persistAccount();
  }

  String get equippedTitleName {
    if (account.title.isEmpty) return '';
    final byId = titleCatalog
        .where((candidate) => candidate.id == account.title)
        .firstOrNull;
    if (byId != null) return byId.name;
    // v6.9 briefly stored display names; retain those saves while normalising
    // all future selections to stable IDs.
    return titleCatalog
            .where((candidate) => candidate.name == account.title)
            .firstOrNull
            ?.name ??
        '';
  }

  Future<void> persistAccount({bool syncCloud = true}) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    account.savedAt = stamp;
    final shouldSync =
        syncCloud &&
        !developerToolsUnlocked(account) &&
        cloudReady &&
        _ownsCurrentCloudAccount;
    // Mark the account dirty before replacing the durable payload. If Android
    // kills the process between the two writes, the next reconciliation may
    // upload an older phone snapshot, but it can never silently replace a new
    // phone save with stale cloud data.
    if (shouldSync) await _markCloudDirty(stamp);
    await _local.writeAccountJson(account.encode(savedAtOverride: stamp));
    ads.setNoAds(account.noAds);
    audio.setEffectsEnabled(!account.muted);
    if (privacyAccepted) {
      unawaited(audio.sync(enabled: account.musicOn));
    }
    if (shouldSync) _scheduleCloudWrite();
    notifyListeners();
  }

  Future<void> persistRunJson(String? runJson, {bool syncCloud = true}) async {
    if (runJson != null && runJson.isNotEmpty) LegacyRunSave.decode(runJson);
    final shouldSync =
        syncCloud &&
        !developerToolsUnlocked(account) &&
        cloudReady &&
        _ownsCurrentCloudAccount;
    if (shouldSync) {
      final plannedStamp = math.max(_latestLocalStamp(), _savedStamp(runJson));
      await _markCloudDirty(plannedStamp);
    }
    if (runJson == null || runJson.isEmpty) {
      activeRunJson = null;
      await _local.clearRun();
    } else {
      activeRunJson = runJson;
      await _local.writeRunJson(runJson);
    }
    if (shouldSync) _scheduleCloudWrite();
    notifyListeners();
  }

  /// Creates the durable boundary used by a native Flutter run.
  ///
  /// Every account request is keyed by the controller's run/claim ID. This is
  /// what makes force-kill recovery safe: replaying a checkpoint can never pay
  /// a Heat, stake, purchase or terminal result twice.
  GamePersistenceCallbacks gamePersistenceCallbacks({String dailyDate = ''}) =>
      GamePersistenceCallbacks(
        writeRun: (encoded, _) => persistRunJson(encoded),
        clearRun: () => persistRunJson(null),
        mutateAccount: (mutation) =>
            _applyGameMutation(mutation, launchDailyDate: dailyDate),
      );

  Future<bool> _applyGameMutation(
    AccountMutation mutation, {
    required String launchDailyDate,
  }) async {
    final claim = mutation.claimId.trim();
    if (claim.isEmpty || claim.length > 96) return false;
    if (account.rewardClaims.contains(claim)) {
      await _queueDailyScoreIfEligible(mutation);
      unawaited(_retryPendingDailyScores());
      return true;
    }

    final nextCoins = account.coins + mutation.coinDelta;
    if (nextCoins < 0 || nextCoins > 9999999) return false;

    // A Daily attempt is consumed together with its run-entry mutation. The
    // controller immediately writes a resumable checkpoint, so an app/process
    // restart resumes the same deterministic deal instead of burning the day.
    if (mutation.kind == AccountMutationKind.runEntry &&
        mutation.runMode == RunMode.daily) {
      final date = launchDailyDate.isEmpty
          ? dailyUtcDateKey()
          : launchDailyDate;
      if (!isCalendarDateKey(date)) return false;
      if (account.dailyRunDate == date) return false;
      account.dailyRunDate = date;
      account.unknownFields[dailyRunDateUtcMarkerKey] = true;
    }

    account.coins = nextCoins;
    account.rewardClaims.add(claim);
    if (account.rewardClaims.length > 256) {
      account.rewardClaims.removeRange(0, account.rewardClaims.length - 256);
    }

    if (mutation.kind == AccountMutationKind.runEntry) {
      account.firstRunStarted = true;
    }

    // Daily and Gauntlet results are isolated from standard Best Heat/score.
    if (mutation.runMode == RunMode.normal) {
      if (mutation.bestHeat case final value?) {
        account.bestHeat = math.max(account.bestHeat, value);
      }
      if (mutation.bestClearedHeat case final value?) {
        account.bestClearedHeat = math.max(account.bestClearedHeat, value);
      }
      if (mutation.bestScore case final value?) {
        account.bestScore = math.max(account.bestScore, value);
      }
    }

    if (mutation.kind == AccountMutationKind.heatReward &&
        mutation.runMode != RunMode.daily) {
      _bumpMission('heats', 1);
    }

    if (mutation.kind == AccountMutationKind.runFinished) {
      _recordFinishedRun(mutation);
    }

    _unlockReachedAchievements(mutation);
    await _queueDailyScoreIfEligible(mutation);
    await persistAccount();

    if (mutation.kind == AccountMutationKind.runFinished) {
      _sendFinishedRunServices(mutation);
    }
    return true;
  }

  void _recordFinishedRun(AccountMutation mutation) {
    final mode = mutation.runMode ?? RunMode.normal;
    final won = mutation.won == true;
    if (mode == RunMode.daily) {
      final date = mutation.dailyDate?.isNotEmpty == true
          ? mutation.dailyDate!
          : dailyUtcDateKey();
      final score = math.max(0, mutation.dailyScore ?? 0);
      if (account.dailyBest.date != date || score > account.dailyBest.score) {
        account.dailyBest = DailyBestRecord(date: date, score: score);
      }
      return;
    }

    // Clearing Heat 12 is a Standard win even when the player continues into
    // Endless and eventually loses or folds. The v7.1 client banked this win at
    // the victory checkpoint; terminal-only accounting must preserve it.
    final recordedWin =
        won || (mode == RunMode.normal && mutation.stagesCleared >= 12);

    account.stats = PlayerStatistics(
      runs: account.stats.runs + 1,
      wins: account.stats.wins + (recordedWin ? 1 : 0),
      gauntletWins:
          account.stats.gauntletWins +
          (won && mode == RunMode.gauntlet ? 1 : 0),
      hands: account.stats.hands + math.max(0, mutation.handsPlayed),
    );

    for (final entry in mutation.handTypeCounts.entries) {
      final key = 'hand:${entry.key.legacyName}';
      account.unknownFields[key] =
          _asInt(account.unknownFields[key]) + math.max(0, entry.value);
    }

    _bumpMission('hands', mutation.handsPlayed);
    final flushes = mutation.handTypeCounts.entries
        .where((entry) => entry.key.legacyName.contains('Flush'))
        .fold<int>(0, (sum, entry) => sum + entry.value);
    _bumpMission('flush', flushes);
    final bigHands = mutation.handTypeCounts.entries
        .where((entry) => entry.key.index >= HandType.fullHouse.index)
        .fold<int>(0, (sum, entry) => sum + entry.value);
    _bumpMission('bighand', bigHands);
    if (recordedWin) {
      _bumpMission('wins', 1);
      _bumpMission('bosskill', 1);
    }

    final modeCode = mode == RunMode.gauntlet ? 'G' : 'S';
    account.runLog.insert(
      0,
      RunLogRecord(
        date: _todayString(),
        heat: math.max(1, mutation.bestHeat ?? mutation.stagesCleared + 1),
        cleared: mutation.stagesCleared,
        score: mutation.bestScore ?? 0,
        modeCode: modeCode,
        won: recordedWin,
        abandoned: mutation.abandoned,
      ),
    );
    if (account.runLog.length > 10) {
      account.runLog.removeRange(10, account.runLog.length);
    }

    if (mode == RunMode.normal && (mutation.bestScore ?? 0) > 0) {
      account.topRuns.add(
        TopRunRecord(
          score: mutation.bestScore!,
          heat: math.max(1, mutation.bestHeat ?? mutation.stagesCleared + 1),
        ),
      );
      account.topRuns.sort((left, right) => right.score.compareTo(left.score));
      if (account.topRuns.length > 5) {
        account.topRuns.removeRange(5, account.topRuns.length);
      }
    }
  }

  void _bumpMission(String stat, int amount) {
    if (amount <= 0) return;
    account.missionStats[stat] = (account.missionStats[stat] ?? 0) + amount;
  }

  void _unlockReachedAchievements(AccountMutation mutation) {
    // Daily is a level playing field and must not advance the normal
    // collection, engine or hand achievements. Its one explicit participation
    // achievement is the only exception.
    if (!progressionEnabledForRun(
      isDailyRun: mutation.runMode == RunMode.daily,
    )) {
      if (mutation.kind == AccountMutationKind.runFinished) {
        account.achievements.putIfAbsent('daily_debut', () => 1);
      }
      return;
    }
    final handCounts = <String, int>{
      for (final entry in account.unknownFields.entries)
        if (entry.key.startsWith('hand:') && entry.value is num)
          entry.key.substring(5): (entry.value! as num).toInt(),
    };
    for (final entry in mutation.handTypeCounts.entries) {
      handCounts[entry.key.legacyName] = math.max(
        handCounts[entry.key.legacyName] ?? 0,
        entry.value,
      );
    }
    final snapshot = ProgressionSnapshot(
      bestHeat: account.bestHeat,
      bestClearedHeat: account.bestClearedHeat,
      bestScore: account.bestScore,
      coins: account.coins,
      stage: mutation.bestHeat ?? 0,
      stagesCleared: mutation.stagesCleared,
      jokersHeld: mutation.jokerIds.length,
      wildJokersHeld: mutation.jokerIds
          .map((id) => jokersById[id])
          .where((joker) => joker?.rarity == JokerRarity.wild)
          .length,
      unlockedJokers: publicUnlockedJokerCount(account.unlockedJokerIds),
      destroyedCards: mutation.destroyedCount,
      copiedCards: mutation.copiedCount,
      boostsBought: mutation.boostsBought,
      bestPlay: mutation.bestPlay,
      totalScore: mutation.bestScore ?? mutation.dailyScore ?? 0,
      modifiedHeatsCleared: mutation.modifiersSurvived.length,
      enhancedCards: mutation.enhancedCount,
      glassDouble: mutation.glassDouble,
      dailyRunPlayed: mutation.runMode == RunMode.daily,
      claimedMissions: account.missionClaimed.values
          .where((value) => value)
          .length,
      titleEquipped: account.title.isNotEmpty,
      cosmeticsOwned: account.cosmeticsOwned.length + defaultCosmeticIds.length,
      stakePaid: mutation.kind == AccountMutationKind.stakeSettlement,
      stakeNet: mutation.kind == AccountMutationKind.stakeSettlement
          ? mutation.coinDelta
          : 0,
      gauntletWins: account.stats.gauntletWins,
      runsPlayed: account.stats.runs,
      handsPlayed: account.stats.hands,
      achievementsEarned: account.achievements.length,
      handTypeCounts: handCounts,
    );
    for (final achievement in achievementCatalog) {
      if (account.achievements.containsKey(achievement.id)) continue;
      if (achievementIsDone(achievement.id, snapshot)) {
        account.achievements[achievement.id] = 1;
      }
    }
  }

  void _sendFinishedRunServices(AccountMutation mutation) {
    final mode = mutation.runMode ?? RunMode.normal;
    final outcome = mutation.abandoned
        ? 'terminated'
        : mutation.won == true
        ? 'won'
        : 'lost';
    pi.queueRunEnd(
      mode: mode.name,
      outcome: outcome,
      heat: math.max(1, mutation.bestHeat ?? mutation.stagesCleared + 1),
    );

    final score = mutation.bestScore ?? mutation.dailyScore ?? 0;
    if (!developerToolsUnlocked(account) &&
        mode == RunMode.normal &&
        score > 0 &&
        mutation.leaderboardEligible &&
        playGames.signedIn) {
      unawaited(playGames.submitScore(score).catchError((_) => false));
    }
    if (mode == RunMode.daily) {
      unawaited(_retryPendingDailyScores());
    }
  }

  Future<void> _queueDailyScoreIfEligible(AccountMutation mutation) async {
    if (mutation.kind != AccountMutationKind.runFinished ||
        mutation.runMode != RunMode.daily ||
        developerToolsUnlocked(account)) {
      return;
    }
    final user = firebase.user;
    final score = mutation.dailyScore ?? 0;
    final claim = mutation.claimId.trim();
    final name = account.playerName
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase();
    final date = mutation.dailyDate?.isNotEmpty == true
        ? mutation.dailyDate!
        : dailyUtcDateKey();
    if (user == null ||
        score <= 0 ||
        score > 10000000 ||
        name.isEmpty ||
        name.length > 8 ||
        claim.isEmpty ||
        claim.length > 96 ||
        !isCalendarDateKey(date)) {
      return;
    }
    await _dailyScoreOutbox.enqueue(
      PendingDailyScore(
        ownerUid: user.uid,
        date: date,
        name: name,
        score: score,
        claimId: claim,
        queuedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _retryPendingDailyScores() async {
    final active = _dailyRetryInFlight;
    if (active != null) return active;
    if (!privacyAccepted ||
        !firebase.initialized ||
        !firebase.signedIn ||
        developerToolsUnlocked(account)) {
      return;
    }
    final retry = _drainPendingDailyScores();
    _dailyRetryInFlight = retry;
    try {
      await retry;
    } finally {
      if (identical(_dailyRetryInFlight, retry)) {
        _dailyRetryInFlight = null;
      }
    }
  }

  Future<void> _drainPendingDailyScores() async {
    final user = firebase.user;
    if (user == null) return;
    await _dailyScoreOutbox.retry(
      ownerUid: user.uid,
      utcDate: dailyUtcDateKey(),
      submit: (submission) async {
        await firebase.submitDailyScore(
          name: submission.name,
          score: submission.score,
          idempotencyKey: submission.claimId,
        );
      },
    );
  }

  Future<void> signInWithGoogle() async {
    if (!privacyAccepted) throw StateError('Accept the privacy policy first.');
    if (!firebase.initialized &&
        !await firebase.initializeAfterPrivacyAcceptance()) {
      throw StateError('Firebase is unavailable.');
    }
    cloudState = CloudLinkState.connecting;
    cloudStatus = 'Opening Google sign-in…';
    cloudError = null;
    notifyListeners();
    try {
      await firebase.signInWithGoogle();
      if (developerToolsUnlocked(account)) {
        cloudState = CloudLinkState.offline;
        cloudStatus = 'Developer tools active — cloud backup paused';
        notifyListeners();
        return;
      }
      unawaited(_retryPendingDailyScores());
      await reconcileCloudAccount(announce: true);
      await restorePlayEntitlements();
      await billing.recoverUnfinishedPurchases();
      await _retryPendingDailyScores();
    } catch (error) {
      cloudError = error;
      if (error is CloudAccountConflict) {
        cloudState = CloudLinkState.accountConflict;
        cloudStatus = 'Different Google account — progress was not combined';
      } else {
        cloudState = CloudLinkState.offline;
        cloudStatus = 'Phone save safe — cloud unavailable';
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (cloudReady) await cloudSaveNow();
    final uid = firebase.user?.uid;
    if (uid != null) await _stashOwnedPhoneSave(uid);
    await firebase.signOut();
    cloudState = CloudLinkState.guest;
    cloudStatus = 'Guest — phone save only';
    cloudSaveVersion = 0;
    cloudProgressVersion = 0;
    billingAdjustmentApplied = 0;
    billingAdjustmentTotal = 0;
    notifyListeners();
  }

  Future<void> reconcileCloudAccount({required bool announce}) async {
    final user = firebase.user;
    if (user == null) throw StateError('Sign in with Google first.');
    cloudBusy = true;
    cloudState = CloudLinkState.connecting;
    cloudStatus = 'Checking cloud backup…';
    cloudError = null;
    notifyListeners();

    try {
      // A read must succeed before any upload. This prevents a bad connection
      // from replacing a known-good remote save with an unverified local copy.
      final remote = await firebase.readSecureCloudSave();
      if (remote['fromCache'] == true) {
        cloudState = CloudLinkState.offline;
        cloudStatus = 'Offline — phone save safe';
        return;
      }

      final uid = user.uid;
      final owner = _local.cloudOwner;
      final remoteExists = remote['exists'] == true;
      final localAccount = _local.accountJson ?? account.encode();
      final localRun = activeRunJson ?? '';
      var accountRaw = localAccount;
      var runRaw = localRun;
      var shouldUpload = !remoteExists;

      _captureRemoteCursors(remote);
      final remoteServerAt = _asInt(remote['serverUpdatedAt']);
      if (remoteExists && !_validAccountJson(remote['accountJson'])) {
        throw const FormatException('Cloud save is invalid');
      }

      if (owner != null && owner.isNotEmpty && owner != uid) {
        await _stashOwnedPhoneSave(owner);
        final slotAccount = _local.readString(_accountSlot(uid));
        if (remoteExists) {
          accountRaw = remote['accountJson'] as String;
          runRaw = remote['runJson']?.toString() ?? '';
          shouldUpload = false;
        } else if (slotAccount != null && slotAccount.isNotEmpty) {
          accountRaw = slotAccount;
          runRaw = _local.readString(_runSlot(uid)) ?? '';
          shouldUpload = true;
        } else {
          await firebase.signOut();
          throw const CloudAccountConflict();
        }
      } else if ((owner == null || owner.isEmpty) && remoteExists) {
        await _local.writeString(
          _guestBackupKey,
          jsonEncode(<String, Object>{
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'accountJson': localAccount,
            'runJson': localRun,
          }),
        );
        accountRaw = remote['accountJson'] as String;
        runRaw = remote['runJson']?.toString() ?? '';
        shouldUpload = false;
      } else if (owner == uid && remoteExists) {
        final dirtyStamp = _dirtyStamp(uid);
        final lastServerAt = _local.readInt(_serverSlot(uid));
        if (dirtyStamp > 0 && _asInt(remote['clientSavedAt']) >= dirtyStamp) {
          accountRaw = remote['accountJson'] as String;
          runRaw = remote['runJson']?.toString() ?? '';
          await _clearCloudDirty(uid);
        } else if (dirtyStamp > 0 &&
            lastServerAt > 0 &&
            remoteServerAt == lastServerAt) {
          shouldUpload = true;
        } else if (dirtyStamp > 0) {
          await _local.writeString(
            _conflictSlot(uid),
            jsonEncode(<String, Object>{
              'savedAt': DateTime.now().millisecondsSinceEpoch,
              'accountJson': localAccount,
              'runJson': localRun,
            }),
          );
          accountRaw = remote['accountJson'] as String;
          runRaw = remote['runJson']?.toString() ?? '';
          await _clearCloudDirty(uid);
          shouldUpload = false;
          cloudStatus = 'Cloud conflict resolved with server copy';
        } else {
          accountRaw = remote['accountJson'] as String;
          runRaw = remote['runJson']?.toString() ?? '';
          shouldUpload = false;
        }
      }

      final retainPaidState = owner == uid || owner == null || owner.isEmpty;
      await _installReconciledSave(
        accountRaw,
        runRaw,
        retainLocalPaidState: retainPaidState,
      );
      await _local.writeCloudOwner(uid);
      await _stashOwnedPhoneSave(uid);
      if (remoteServerAt > 0) {
        await _local.writeInt(_serverSlot(uid), remoteServerAt);
      }
      cloudState = CloudLinkState.ready;
      if (!cloudStatus.startsWith('Cloud conflict')) {
        cloudStatus = announce
            ? 'Google account linked — private cloud backup ready'
            : 'Cloud backup up to date';
      }
      if (shouldUpload) {
        await _markCloudDirty(_latestLocalStamp());
        await cloudSaveNow();
      }
    } catch (error) {
      cloudError = error;
      if (error is CloudAccountConflict) rethrow;
      cloudState = CloudLinkState.offline;
      cloudStatus = 'Phone save safe — cloud unavailable';
      rethrow;
    } finally {
      cloudBusy = false;
      notifyListeners();
    }
  }

  Future<bool> cloudSaveNow() async {
    if (developerToolsUnlocked(account)) return false;
    if (!cloudReady || !_ownsCurrentCloudAccount || !firebase.signedIn) {
      return false;
    }
    final existing = _cloudWriteInFlight;
    if (existing != null) {
      _cloudWritePending = true;
      return existing;
    }
    final operation = _performCloudWrite();
    _cloudWriteInFlight = operation;
    final result = await operation;
    _cloudWriteInFlight = null;
    if (_cloudWritePending) {
      _cloudWritePending = false;
      _scheduleCloudWrite(delay: const Duration(milliseconds: 80));
    }
    return result;
  }

  Future<bool> _performCloudWrite() async {
    final uid = firebase.user?.uid;
    if (uid == null) return false;
    final accountRaw = _local.accountJson ?? account.encode();
    final runRaw = activeRunJson ?? '';
    final sentStamp = _latestLocalStamp();
    await _markCloudDirty(sentStamp);
    try {
      final response = await firebase.writeSecureCloudSave(
        accountJson: accountRaw,
        runJson: runRaw,
        clientSavedAt: sentStamp,
        expectedProgressVersion: cloudProgressVersion,
        billingAdjustmentApplied: billingAdjustmentApplied,
      );
      if (response['exists'] != true ||
          !_validAccountJson(response['accountJson'])) {
        throw const FormatException('Cloud server returned an invalid save');
      }
      _captureRemoteCursors(response);
      final serverAt = _asInt(response['serverUpdatedAt']);
      if (serverAt > 0) await _local.writeInt(_serverSlot(uid), serverAt);

      // Do not let the response to an older write erase a newer local move.
      if (_latestLocalStamp() <= sentStamp) {
        await _installReconciledSave(
          response['accountJson'] as String,
          response['runJson']?.toString() ?? '',
          retainLocalPaidState: true,
        );
        await _clearCloudDirty(uid);
      } else {
        _cloudWritePending = true;
      }
      await _stashOwnedPhoneSave(uid);
      cloudStatus = 'Cloud backup verified';
      cloudState = CloudLinkState.ready;
      cloudError = null;
      notifyListeners();
      return true;
    } catch (error) {
      cloudError = error;
      cloudStatus = 'Phone save safe — cloud waiting for connection';
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePlayEntitlements() async {
    if (!firebase.signedIn) return;
    try {
      final result = await billing.restoreServerEntitlements();
      if (result['authoritative'] != true) return;
      var changed = false;
      if (result['noAds'] == true && !account.noAds) {
        account.noAds = true;
        changed = true;
      }
      final purchases = result['purchases'];
      if (purchases is List) {
        for (final value in purchases.whereType<Map>()) {
          final purchase = Map<String, dynamic>.from(value);
          final productId = purchase['productId']?.toString() ?? '';
          final tokenHash = purchase['tokenHash']?.toString() ?? '';
          if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(tokenHash) ||
              !AppConstants.playProductIds.contains(productId)) {
            continue;
          }
          if (productId == 'remove_ads') {
            account.purchaseClaims.putIfAbsent(
              tokenHash,
              () => PurchaseClaim(
                productId: productId,
                claimedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
            continue;
          }
          // Delivered consumables were already included in the private cloud
          // balance. Only a verified-but-undelivered receipt is recoverable.
          if (purchase['delivered'] != true &&
              !account.purchaseClaims.containsKey(tokenHash)) {
            account.coins += AppConstants.playCoinGrants[productId] ?? 0;
            account.purchaseClaims[tokenHash] = PurchaseClaim(
              productId: productId,
              claimedAt: DateTime.now().millisecondsSinceEpoch,
            );
            changed = true;
          }
        }
      }
      final billingInfo = result['billing'];
      if (billingInfo is Map) {
        billingAdjustmentApplied = _asInt(
          billingInfo['billingAdjustmentApplied'],
        );
        billingAdjustmentTotal = _asInt(billingInfo['coinAdjustmentTotal']);
        cloudProgressVersion = _asInt(billingInfo['progressVersion']);
      }
      if (changed) await persistAccount();
      ads.setNoAds(account.noAds);
      notifyListeners();
    } catch (error) {
      cloudError = error;
      notifyListeners();
    }
  }

  int get rewardedViewsLeftToday {
    final today = _todayString();
    if (account.adDate != today) return 5;
    return (5 - account.adViews).clamp(0, 5);
  }

  Future<bool> claimRewardedCoins() async {
    if (rewardedViewsLeftToday <= 0) return false;
    if (!await _completeRewardedPlacement()) return false;
    account.coins += 25;
    await persistAccount();
    return true;
  }

  Future<bool> claimRunCoinDouble({
    required String runId,
    required int baseCoins,
    required RunMode mode,
  }) async {
    final claimId = '$runId:double';
    if (account.rewardClaims.contains(claimId)) return true;
    if (mode == RunMode.daily ||
        baseCoins <= 0 ||
        baseCoins > 9999999 ||
        claimId.length > 96 ||
        rewardedViewsLeftToday <= 0) {
      return false;
    }
    if (!await _completeRewardedPlacement()) return false;
    return _applyGameMutation(
      AccountMutation(
        claimId: claimId,
        kind: AccountMutationKind.rewardedDouble,
        coinDelta: baseCoins,
        runMode: mode,
      ),
      launchDailyDate: '',
    );
  }

  Future<bool> _completeRewardedPlacement() async {
    if (rewardedViewsLeftToday <= 0) return false;
    if (!account.noAds && await ads.showRewarded() == null) return false;
    final today = _todayString();
    if (account.adDate != today) {
      account.adDate = today;
      account.adViews = 0;
    }
    account.adViews += 1;
    return true;
  }

  Future<void> deleteFirebaseAccountAndData() async {
    if (!firebase.signedIn) throw StateError('Sign in first.');
    await firebase.deleteMyAccount();
    _cloudTimer?.cancel();
    await _local.clearPlayerData(retainPrivacyAcceptance: true);
    account = AccountState();
    activeRunJson = null;
    cloudState = CloudLinkState.guest;
    cloudStatus = 'Account deleted';
    try {
      await firebase.signOut();
    } catch (_) {
      // The callable deletes Firebase Authentication, so a local sign-out can
      // legitimately see an already-invalid credential.
    }
    notifyListeners();
  }

  Future<void> resetLocalProgress() async {
    if (firebase.signedIn) await signOut();
    await _local.clearPlayerData(retainPrivacyAcceptance: true);
    account = AccountState();
    activeRunJson = null;
    await _normalizeProgression();
    notifyListeners();
  }

  Future<bool> _persistVerifiedPlayGrant(VerifiedPlayPurchase purchase) async {
    final alreadyClaimed = account.purchaseClaims.containsKey(
      purchase.tokenHash,
    );
    if (!alreadyClaimed) {
      if (purchase.removesAds) {
        account.noAds = true;
      } else {
        account.coins += purchase.coinAmount;
      }
      account.purchaseClaims[purchase.tokenHash] = PurchaseClaim(
        productId: purchase.productId,
        claimedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await persistAccount(syncCloud: false);
    }
    if (!cloudReady || !_ownsCurrentCloudAccount) return false;
    await _markCloudDirty(_latestLocalStamp());
    final saved = await cloudSaveNow();
    if (saved) ads.setNoAds(account.noAds);
    return saved;
  }

  Future<void> _installReconciledSave(
    String accountRaw,
    String runRaw, {
    required bool retainLocalPaidState,
  }) async {
    final paidNoAds = account.noAds;
    final paidClaims = Map<String, PurchaseClaim>.from(account.purchaseClaims);
    final installed = AccountState.decode(accountRaw);
    if (retainLocalPaidState) {
      installed.noAds = paidNoAds;
      installed.purchaseClaims.addAll(paidClaims);
    }
    _normalizeDailyUtcDates(installed);
    account = installed;
    await _local.writeAccountJson(installed.encode());
    if (runRaw.isEmpty) {
      activeRunJson = null;
      await _local.clearRun();
    } else {
      LegacyRunSave.decode(runRaw);
      activeRunJson = runRaw;
      await _local.writeRunJson(runRaw);
    }
    ads.setNoAds(account.noAds);
    notifyListeners();
  }

  Future<void> _normalizeProgression() async {
    var changed = _normalizeDailyUtcDates(account);
    if (account.tutorialDone) {
      final before = account.unlockedJokerIds.length;
      account.unlockedJokerIds.addAll(tutorialStarterJokerIds);
      changed = changed || account.unlockedJokerIds.length != before;
    }
    final validCosmetics = cosmeticCatalog.map((item) => item.id).toSet();
    final invalidOwned = account.cosmeticsOwned
        .where((id) => !validCosmetics.contains(id))
        .toList();
    if (invalidOwned.isNotEmpty) {
      account.cosmeticsOwned.removeAll(invalidOwned);
      changed = true;
    }
    final table = cosmeticById(account.equipped.table);
    final theme = cosmeticById(account.equipped.theme);
    final sly = cosmeticById(account.equipped.sly);
    final normalizedEquipped = EquippedCosmetics(
      table: table?.kind == CosmeticKind.table && _ownsCosmetic(table!.id)
          ? table.id
          : 'felt_classic',
      theme: theme?.kind == CosmeticKind.theme && _ownsCosmetic(theme!.id)
          ? theme.id
          : 'theme_default',
      sly: sly?.kind == CosmeticKind.sly && _ownsCosmetic(sly!.id)
          ? sly.id
          : 'sly_classic',
    );
    if (normalizedEquipped.table != account.equipped.table ||
        normalizedEquipped.theme != account.equipped.theme ||
        normalizedEquipped.sly != account.equipped.sly) {
      account.equipped = normalizedEquipped;
      changed = true;
    }
    if (account.title.isNotEmpty &&
        !titleCatalog.any((title) => title.id == account.title)) {
      final legacyTitle = titleCatalog
          .where((title) => title.name == account.title)
          .firstOrNull;
      if (legacyTitle != null) {
        account.title = legacyTitle.id;
        changed = true;
      }
    }
    final week = isoWeekKey(DateTime.now());
    if (account.missionWeek != week || account.missionSet.length != 3) {
      account.missionWeek = week;
      account.missionStats.clear();
      account.missionClaimed.clear();
      account.missionRotation = 0;
      account.missionRefreshDate = '';
      account.missionSet
        ..clear()
        ..addAll(chooseWeeklyContracts(weekKey: week, rotation: 0));
      changed = true;
    }
    if (changed) await persistAccount(syncCloud: false);
  }

  static bool _normalizeDailyUtcDates(
    AccountState target, {
    DateTime? now,
    String? localTodayOverride,
  }) {
    final alreadyUtc = target.unknownFields[dailyRunDateUtcMarkerKey] == true;
    if (alreadyUtc) return false;
    final current = now ?? DateTime.now();
    final utcToday = dailyUtcDateKey(current);
    final localToday = localTodayOverride ?? localCalendarDateKey(current);
    final runMigration = migrateLegacyDailyDate(
      storedDate: target.dailyRunDate,
      alreadyUtc: false,
      utcToday: utcToday,
      localToday: localToday,
    );
    final bestMigration = migrateLegacyDailyDate(
      storedDate: target.dailyBest.date,
      alreadyUtc: false,
      utcToday: utcToday,
      localToday: localToday,
    );
    target.dailyRunDate = runMigration.date;
    target.dailyBest = DailyBestRecord(
      date: bestMigration.date,
      score: target.dailyBest.score,
    );
    target.unknownFields[dailyRunDateUtcMarkerKey] = true;
    return true;
  }

  bool _ownsCosmetic(String id) =>
      defaultCosmeticIds.contains(id) || account.cosmeticsOwned.contains(id);

  EquippedCosmetics _equippedWith(CosmeticKind kind, String id) =>
      EquippedCosmetics(
        table: kind == CosmeticKind.table ? id : account.equipped.table,
        theme: kind == CosmeticKind.theme ? id : account.equipped.theme,
        sly: kind == CosmeticKind.sly ? id : account.equipped.sly,
      );

  void _captureRemoteCursors(Map<String, dynamic> response) {
    cloudSaveVersion = _asInt(response['saveVersion']);
    cloudProgressVersion = _asInt(response['progressVersion']);
    billingAdjustmentApplied = _asInt(response['billingAdjustmentApplied']);
    billingAdjustmentTotal = _asInt(response['billingAdjustmentTotal']);
  }

  bool get _ownsCurrentCloudAccount {
    final uid = firebase.user?.uid;
    return uid != null && _local.cloudOwner == uid;
  }

  void _scheduleCloudWrite({Duration delay = const Duration(seconds: 2)}) {
    _cloudTimer?.cancel();
    _cloudTimer = Timer(delay, () => unawaited(cloudSaveNow()));
  }

  Future<void> _stashOwnedPhoneSave(String uid) async {
    await _local.writeString(_accountSlot(uid), _local.accountJson ?? '');
    await _local.writeString(_runSlot(uid), activeRunJson ?? '');
  }

  Future<void> _markCloudDirty(int stamp) =>
      _local.writeInt(_dirtySlot(firebase.user?.uid ?? ''), stamp);

  int _dirtyStamp(String uid) => _local.readInt(_dirtySlot(uid));

  Future<void> _clearCloudDirty(String uid) => _local.remove(_dirtySlot(uid));

  int _latestLocalStamp() =>
      _savedStamp(_local.accountJson) > _savedStamp(activeRunJson)
      ? _savedStamp(_local.accountJson)
      : _savedStamp(activeRunJson);

  static int _savedStamp(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    try {
      final value = jsonDecode(raw);
      return value is Map ? _asInt(value['_savedAt']) : 0;
    } catch (_) {
      return 0;
    }
  }

  static bool _validAccountJson(Object? raw) {
    if (raw is! String || raw.isEmpty) return false;
    try {
      AccountState.decode(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.floor();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static String _todayString() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  static String _safeUid(String uid) => Uri.encodeComponent(uid);
  static String _accountSlot(String uid) =>
      '${_cloudPrefix}account:${_safeUid(uid)}';
  static String _runSlot(String uid) => '${_cloudPrefix}run:${_safeUid(uid)}';
  static String _serverSlot(String uid) =>
      '${_cloudPrefix}server:${_safeUid(uid)}';
  static String _dirtySlot(String uid) =>
      '${_cloudPrefix}dirty:${_safeUid(uid)}';
  static String _conflictSlot(String uid) =>
      '${_cloudPrefix}conflict:${_safeUid(uid)}';

  @override
  void dispose() {
    _disposed = true;
    _cloudTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    firebase.dispose();
    ads.dispose();
    unawaited(audio.dispose());
    billing.dispose();
    playGames.dispose();
    pi.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}

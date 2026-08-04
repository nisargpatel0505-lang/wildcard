import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/daily_utc_date.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/long_term_progression.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'WILDCARD',
      packageName: 'com.nisarg.wildcard',
      version: '8.5.0',
      buildNumber: '64',
      buildSignature: 'test',
      installerStore: null,
    );
  });

  test('daily reward grants Day 1 once and persists tomorrow state', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);

    expect(app.dailyLoginOffer.reward, 5);
    expect(app.dailyLoginOffer.tomorrowReward, 10);
    expect(await app.claimDailyLoginReward(), 5);
    expect(await app.claimDailyLoginReward(), 0);
    expect(app.account.dailyStreak, 1);
    expect(app.account.lastDaily, dailyUtcDateKey());
    expect(app.account.progressCounters[ProgressCounterKey.bestDailyStreak], 1);

    final preferences = await SharedPreferences.getInstance();
    final reloaded = AccountState.decode(
      preferences.getString('wildcard_save_v1')!,
    );
    expect(reloaded.coins, 5);
    expect(reloaded.lastDaily, dailyUtcDateKey());
  });

  test('terminal run updates reliable tier counters exactly once', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    final callbacks = app.gamePersistenceCallbacks();

    const mutation = AccountMutation(
      claimId: 'tier-run:finished',
      kind: AccountMutationKind.runFinished,
      runMode: RunMode.normal,
      won: false,
      bestHeat: 20,
      bestClearedHeat: 19,
      bestScore: 50000,
      stagesCleared: 19,
      enteredEndless: true,
      bestPlay: 8000,
      handsPlayed: 20,
      handTypeCounts: <HandType, int>{HandType.royalFlush: 2},
    );
    expect(await callbacks.mutateAccount(mutation), isTrue);
    expect(await callbacks.mutateAccount(mutation), isTrue);

    expect(app.longTermProgress.endlessEntries, 1);
    expect(app.longTermProgress.runsWon, 1);
    expect(app.longTermProgress.royalFlushes, 2);
    expect(app.longTermProgress.bestSingleHand, 8000);

    expect(await app.claimTieredAchievement('tier_endless_1'), 5);
    expect(await app.claimTieredAchievement('tier_endless_1'), 0);
    expect(await app.claimTieredAchievement('tier_endless_5'), 0);
    expect(app.account.achievementClaimed['tier_endless_1'], isTrue);
  });

  test('old saves synthesize only reliable historical progress', () async {
    final old = <String, Object?>{
      '_savedAt': 1,
      'bestHeat': 20,
      'dailyStreak': 8,
      'stats': <String, Object?>{
        'runs': 10,
        'wins': 7,
        'gWins': 2,
        'hands': 100,
      },
      'achievements': <String, Object?>{'monster_hand': 1},
      'achievementClaimed': <String, Object?>{'monster_hand': true},
      'missionClaimed': <String, Object?>{'m_hands': true, 'm_pair': true},
      'hand:Royal Flush': 4,
      'vaultClaimsV1': <String, Object?>{
        'a': <String, Object?>{'rewardId': 'copper'},
        'b': <String, Object?>{'rewardId': 'polish'},
        'c': <String, Object?>{'rewardId': 'trainer'},
      },
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wildcard_save_v1': jsonEncode(old),
    });

    final app = await AppController.bootstrap();
    addTearDown(app.dispose);

    expect(app.longTermProgress.runsWon, 5);
    expect(app.longTermProgress.endlessEntries, 1);
    expect(app.longTermProgress.royalFlushes, 4);
    expect(app.longTermProgress.bestSingleHand, 3000);
    expect(app.longTermProgress.vaultsOpened, 3);
    expect(app.longTermProgress.bestDailyStreak, 8);
    expect(app.longTermProgress.weeklyMissionsClaimed, 2);
  });

  test('weekly claims are manual, idempotent and lifetime-counted', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    final id = app.account.missionSet.first;
    final mission = weeklyContractCatalog.firstWhere(
      (candidate) => candidate.id == id,
    );
    await app.mutateAccount(
      (account) => account.missionStats[mission.stat] = mission.target,
      syncCloud: false,
    );

    expect(await app.claimWeeklyMission(id), mission.reward);
    expect(await app.claimWeeklyMission(id), 0);
    expect(app.longTermProgress.weeklyMissionsClaimed, 1);
  });

  test(
    'an open app rotates stale weekly state before showing missions',
    () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      await app.mutateAccount((account) {
        account.missionWeek = '2000-W01';
        account.missionStats['hands'] = 999;
        account.missionClaimed['m_hands'] = true;
        account.missionSet
          ..clear()
          ..add('m_hands');
      }, syncCloud: false);

      await app.ensureWeeklyMissionsCurrent();
      expect(app.account.missionWeek, isNot('2000-W01'));
      expect(app.account.missionSet, hasLength(5));
      expect(app.account.missionStats, isEmpty);
      expect(app.account.missionClaimed, isEmpty);
    },
  );

  test('final badge tier unlocks its title after sequential claims', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    await app.mutateAccount(
      (account) =>
          account.progressCounters[ProgressCounterKey.endlessEntries] = 100,
      syncCloud: false,
    );

    expect(app.titleUnlocked('t_eternal', app.progressionSnapshot), isFalse);
    for (final tier in longTermFamilyTiers(LongTermFamily.endless)) {
      await app.claimTieredAchievement(tier.id);
      expect(app.account.achievementClaimed[tier.id], isTrue);
    }
    expect(app.titleUnlocked('t_eternal', app.progressionSnapshot), isTrue);
    await app.equipTitle('t_eternal', app.progressionSnapshot);
    expect(app.account.title, 't_eternal');
  });

  test(
    'vault claim replay does not advance the lifetime counter twice',
    () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      await app.mutateAccount(
        (account) => account.coins = 10000,
        syncCloud: false,
      );

      final first = await app.openJokerVault(
        JokerChestTier.wood,
        claimId: 'progress-vault-1',
        rarityRoll: 0,
        itemRoll: 0,
      );
      final replay = await app.openJokerVault(
        JokerChestTier.wood,
        claimId: 'progress-vault-1',
        rarityRoll: .99,
        itemRoll: .99,
      );
      expect(first, isNotNull);
      expect(replay?.id, first?.id);
      expect(app.longTermProgress.vaultsOpened, 1);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/progression_catalog.dart';

void main() {
  group('v7.1.0 cosmetic catalogue', () {
    test('contains every shipped table, UI theme and Sly look', () {
      expect(cosmeticCatalog, hasLength(32));
      expect(cosmeticCatalog.map((item) => item.id).toSet(), hasLength(32));
      expect(
        cosmeticCatalog.where((item) => item.kind == CosmeticKind.table),
        hasLength(10),
      );
      expect(
        cosmeticCatalog.where((item) => item.kind == CosmeticKind.theme),
        hasLength(14),
      );
      expect(
        cosmeticCatalog.where((item) => item.kind == CosmeticKind.sly),
        hasLength(8),
      );
      expect(
        cosmeticCatalog
            .where((item) => item.isDefault)
            .map((item) => item.id)
            .toSet(),
        defaultCosmeticIds,
      );
      expect(
        cosmeticCatalog.fold<int>(0, (sum, item) => sum + item.price),
        41150,
      );
    });

    test('rarities and premium theme pricing stay intact', () {
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.common),
        hasLength(3),
      );
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.uncommon),
        hasLength(9),
      );
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.rare),
        hasLength(14),
      );
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.wild),
        hasLength(6),
      );
      expect(cosmeticById('theme_neon_heist')?.price, 5000);
      expect(cosmeticById('theme_clockwork')?.price, 5000);
      expect(cosmeticById('sly_devil')?.skin, 'devil');
    });

    test('Cosmetic Vault uses the exact 0.8% theme gate', () {
      final pool = <CosmeticDefinition>[
        cosmeticById('theme_sunset')!,
        cosmeticById('felt_neon')!,
      ];
      expect(
        rollCosmeticVault(pool, themeRoll: 0.007999, itemRoll: 0)?.kind,
        CosmeticKind.theme,
      );
      expect(
        rollCosmeticVault(pool, themeRoll: 0.008, itemRoll: 0)?.kind,
        CosmeticKind.table,
      );
      expect(cosmeticVaultPrice, 750);
    });
  });

  group('achievements and Cabinet gates', () {
    test('mirrors all 44 claimable achievements and reward budget', () {
      expect(achievementCatalog, hasLength(44));
      expect(achievementCatalog.map((item) => item.id).toSet(), hasLength(44));
      expect(
        achievementCatalog.fold<int>(0, (sum, item) => sum + item.reward),
        2797,
      );
    });

    test(
      'hand, run, collection and stake conditions match shipped thresholds',
      () {
        const state = ProgressionSnapshot(
          bestHeat: 15,
          bestClearedHeat: 12,
          stage: 13,
          stagesCleared: 12,
          jokersHeld: 5,
          wildJokersHeld: 2,
          destroyedCards: 5,
          copiedCards: 5,
          boostsBought: 5,
          bestPlay: 3000,
          totalScore: 6000,
          modifiedHeatsCleared: 3,
          enhancedCards: 5,
          glassDouble: true,
          dailyRunPlayed: true,
          claimedMissions: 1,
          titleEquipped: true,
          cosmeticsOwned: 5,
          stakePaid: true,
          stakeNet: 1,
          gauntletWins: 1,
          runsPlayed: 25,
          handsPlayed: 500,
          coins: 2000,
          handTypeCounts: <String, int>{
            'Pair': 1,
            'Two Pair': 1,
            'Three of a Kind': 1,
            'Straight': 1,
            'Flush': 1,
            'Full House': 1,
            'Four of a Kind': 1,
            'Straight Flush': 1,
          },
        );
        expect(
          achievementCatalog.every((item) => achievementIsDone(item.id, state)),
          isTrue,
        );
        expect(
          achievementIsDone(
            'stake_shark',
            const ProgressionSnapshot(stakePaid: true, stakeNet: 0),
          ),
          isFalse,
        );
      },
    );

    test('badge and title catalogue gates remain exact', () {
      expect(badgeCatalog, hasLength(9));
      expect(titleCatalog, hasLength(6));
      const locked = ProgressionSnapshot();
      expect(
        badgeCatalog.any((badge) => badgeIsEarned(badge.id, locked)),
        isFalse,
      );
      expect(titleIsUnlocked('t_rookie', locked), isTrue);
      expect(titleIsUnlocked('t_champ', locked), isFalse);

      const earned = ProgressionSnapshot(
        bestHeat: 13,
        bestClearedHeat: 12,
        bestScore: 5000,
        coins: 2000,
        achievementsEarned: 20,
        cosmeticsOwned: 5,
        unlockedJokers: 40,
      );
      expect(
        badgeCatalog.every((badge) => badgeIsEarned(badge.id, earned)),
        isTrue,
      );
      expect(
        titleCatalog.every((title) => titleIsUnlocked(title.id, earned)),
        isTrue,
      );
    });
  });

  group('weekly missions', () {
    test('catalogue and deterministic shuffle match the JavaScript client', () {
      expect(weeklyContractCatalog, hasLength(6));
      expect(
        weeklyContractCatalog.fold<int>(
          0,
          (sum, mission) => sum + mission.reward,
        ),
        1400,
      );
      expect(weeklySeed('2026-W30#0'), 574722015);
      expect(shuffledWeeklyContractIds(574722015), <String>[
        'm_heats',
        'm_wins',
        'm_boss',
        'm_hands',
        'm_big',
        'm_flush',
      ]);
      expect(chooseWeeklyContracts(weekKey: '2026-W30', rotation: 0), <String>[
        'm_heats',
        'm_wins',
        'm_boss',
      ]);
    });

    test('refresh avoids current and claimed missions when possible', () {
      final next = chooseWeeklyContracts(
        weekKey: '2026-W30',
        rotation: 1,
        currentIds: const <String>['m_heats', 'm_wins', 'm_boss'],
        claimedIds: const <String>['m_big'],
      );
      // Only two contracts are both new and unclaimed, so the shipped fallback
      // fills slot three with the claimed contract before repeating a current one.
      expect(next, <String>['m_flush', 'm_hands', 'm_big']);
      expect(next, isNot(contains('m_heats')));
    });

    test('ISO week keys match the client around year boundaries', () {
      expect(isoWeekKey(DateTime(2026, 7, 21)), '2026-W30');
      expect(isoWeekKey(DateTime(2021, 1, 1)), '2020-W53');
      expect(isoWeekKey(DateTime(2021, 1, 4)), '2021-W01');
    });
  });

  group('starter, mode and daily gates', () {
    test('tutorial grant and mode unlock thresholds match v7.1.0', () {
      expect(tutorialStarterJokerIds, hasLength(10));
      expect(tutorialFirstRunJokerIds, <String>['copper', 'polish']);
      expect(starterGiftCoins, 200);

      const before = ProgressionGates(
        tutorialDone: false,
        bestClearedHeat: 4,
        unlockedJokers: 14,
      );
      expect(before.dailyChallengeUnlocked, isFalse);
      expect(before.stakeUnlocked, isFalse);
      expect(before.gauntletUnlocked, isFalse);
      expect(before.newcomerWoodVaultPriceActive, isTrue);

      const after = ProgressionGates(
        tutorialDone: true,
        bestClearedHeat: 12,
        unlockedJokers: 15,
      );
      expect(after.dailyChallengeUnlocked, isTrue);
      expect(after.stakeUnlocked, isTrue);
      expect(after.gauntletUnlocked, isTrue);
      expect(after.newcomerWoodVaultPriceActive, isFalse);
      expect(newcomerWoodVaultPrice, 60);
    });

    test('daily streak uses 30 + 18 per day and caps at 192', () {
      expect(dailyLoginRewardForStreak(1), 30);
      expect(dailyLoginRewardForStreak(2), 48);
      expect(dailyLoginRewardForStreak(10), 192);
      expect(dailyLoginRewardForStreak(1000), 192);

      final continuing = nextDailyLoginOffer(
        now: DateTime(2026, 7, 21, 18),
        lastClaim: DateTime(2026, 7, 20, 8),
        currentStreak: 4,
      );
      expect(continuing.available, isTrue);
      expect(continuing.streak, 5);
      expect(continuing.reward, 102);

      final alreadyClaimed = nextDailyLoginOffer(
        now: DateTime(2026, 7, 21, 18),
        lastClaim: DateTime(2026, 7, 21, 8),
        currentStreak: 5,
      );
      expect(alreadyClaimed.available, isFalse);
    });

    test('Daily Challenge progression and planned prizes remain disabled', () {
      expect(progressionEnabledForRun(isDailyRun: false), isTrue);
      expect(progressionEnabledForRun(isDailyRun: true), isFalse);
      expect(dailyBoardCoinPrizesActive, isFalse);
      expect(plannedDailyBoardCoinPrizes, <int, int>{1: 300, 2: 200, 3: 200});
    });
  });
}

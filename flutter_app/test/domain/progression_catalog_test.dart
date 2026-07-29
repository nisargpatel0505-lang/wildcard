import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/progression_catalog.dart';

void main() {
  group('cosmetic catalogue', () {
    test('contains every available table, UI theme and Sly look', () {
      expect(cosmeticCatalog, hasLength(60));
      expect(cosmeticCatalog.map((item) => item.id).toSet(), hasLength(60));
      expect(
        cosmeticCatalog.where((item) => item.kind == CosmeticKind.table),
        hasLength(24),
      );
      expect(
        cosmeticCatalog.where((item) => item.kind == CosmeticKind.theme),
        hasLength(21),
      );
      expect(
        cosmeticCatalog.where((item) => item.kind == CosmeticKind.sly),
        hasLength(15),
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
        115650,
      );
    });

    test('rarities and premium theme pricing stay intact', () {
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.common),
        hasLength(5),
      );
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.uncommon),
        hasLength(11),
      );
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.rare),
        hasLength(28),
      );
      expect(
        cosmeticCatalog.where((item) => item.rarity == JokerRarity.wild),
        hasLength(16),
      );
      expect(cosmeticById('theme_neon_heist')?.price, 5000);
      expect(cosmeticById('theme_clockwork')?.price, 5000);
      expect(cosmeticById('sly_devil')?.skin, 'devil');
      expect(cosmeticById('theme_block_drop')?.price, 1000);
      expect(cosmeticById('theme_abyssal')?.price, 1000);
      expect(cosmeticById('theme_desert_mirage')?.price, 1000);
      expect(cosmeticById('sly_block_drop')?.price, 5000);
      expect(cosmeticById('sly_abyssal')?.price, 5000);
      expect(cosmeticById('sly_desert')?.price, 5000);
      expect(cosmeticById('theme_hearts_kingdom')?.price, 1000);
      expect(cosmeticById('theme_spades_kingdom')?.price, 1000);
      expect(cosmeticById('theme_diamonds_kingdom')?.price, 1000);
      expect(cosmeticById('theme_clubs_kingdom')?.price, 1000);
      expect(cosmeticById('felt_hearts_kingdom')?.price, 2800);
      expect(cosmeticById('felt_spades_kingdom')?.price, 2800);
      expect(cosmeticById('felt_diamonds_kingdom')?.price, 3200);
      expect(cosmeticById('felt_clubs_kingdom')?.price, 3200);
      expect(
        cosmeticById('sly_hearts')!.price,
        greaterThan(cosmeticById('theme_ember')!.price),
      );
      expect(
        cosmeticById('sly_spades')!.price,
        greaterThan(cosmeticById('theme_moonlit_mask')!.price),
      );
      expect(
        cosmeticById('sly_diamonds')!.price,
        greaterThan(cosmeticById('theme_clockwork')!.price),
      );
      expect(
        cosmeticById('sly_clubs')!.price,
        greaterThan(cosmeticById('theme_emerald_throne')!.price),
      );
    });

    test('new procedural and premium tables stay registered', () {
      const proceduralIds = <String>{
        'felt_herringbone',
        'felt_art_deco',
        'felt_honeycomb',
        'felt_tartan',
        'felt_circuit_v2',
        'felt_nebula',
      };
      const premiumIds = <String>{
        'felt_midnight_velvet',
        'felt_emerald_royale',
        'felt_neon_grid',
        'felt_obsidian_marble',
      };
      const newTableIds = <String>{...proceduralIds, ...premiumIds};
      final tables = cosmeticCatalog
          .where((item) => newTableIds.contains(item.id))
          .toList();
      expect(tables, hasLength(newTableIds.length));
      expect(tables.map((item) => item.name).toSet(), <String>{
        'Herringbone',
        'Art-Deco Sunburst',
        'Honeycomb',
        'Tartan',
        'Circuit-Board v2',
        'Nebula Felt',
        'Midnight Velvet',
        'Emerald Casino Royale',
        'Neon Grid',
        'Obsidian Marble',
      });
      expect(tables.every((item) => item.kind == CosmeticKind.table), isTrue);
      expect(
        tables
            .where((item) => proceduralIds.contains(item.id))
            .every((item) => item.price >= 250 && item.price <= 800),
        isTrue,
      );
      expect(
        tables
            .where((item) => premiumIds.contains(item.id))
            .every((item) => item.price >= 1500 && item.price <= 3000),
        isTrue,
      );
      expect(cosmeticById('felt_midnight_velvet')?.price, 2200);
      expect(cosmeticById('felt_emerald_royale')?.price, 2500);
      expect(cosmeticById('felt_neon_grid')?.price, 2750);
      expect(cosmeticById('felt_obsidian_marble')?.price, 3000);
    });

    test('Cosmetic Vault uses the exact 0.8% theme gate', () {
      final pool = <CosmeticDefinition>[
        cosmeticById('theme_sunset')!,
        cosmeticById('felt_neon')!,
      ];
      final kindOdds = cosmeticVaultKindOdds(pool);
      expect(kindOdds[CosmeticKind.theme], closeTo(0.008, 0.0000001));
      expect(kindOdds[CosmeticKind.table], closeTo(0.992, 0.0000001));
      expect(
        rollCosmeticVault(pool, themeRoll: 0.007999, itemRoll: 0)?.kind,
        CosmeticKind.theme,
      );
      expect(
        rollCosmeticVault(pool, themeRoll: 0.008, itemRoll: 0)?.kind,
        CosmeticKind.table,
      );
      expect(cosmeticVaultPrice, 1000);
    });

    test('Cosmetic Vault kind odds collapse truthfully as pools complete', () {
      final themeOnly = <CosmeticDefinition>[cosmeticById('theme_sunset')!];
      expect(cosmeticVaultKindOdds(themeOnly), <CosmeticKind, double>{
        CosmeticKind.theme: 1,
      });

      final nonThemeOnly = <CosmeticDefinition>[
        cosmeticById('felt_neon')!,
        cosmeticById('sly_shadow')!,
      ];
      final odds = cosmeticVaultKindOdds(nonThemeOnly);
      expect(odds.values.fold<double>(0, (sum, value) => sum + value), 1);
      expect(odds.containsKey(CosmeticKind.theme), isFalse);
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
      expect(titleCatalog, hasLength(11));
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
        titleCatalog
            .take(6)
            .every((title) => titleIsUnlocked(title.id, earned)),
        isTrue,
      );
      expect(
        titleCatalog
            .skip(6)
            .every((title) => !titleIsUnlocked(title.id, earned)),
        isTrue,
      );
    });
  });

  group('weekly missions', () {
    test('catalogue has five deterministic, multi-run contracts', () {
      expect(weeklyContractCatalog, hasLength(10));
      expect(visibleWeeklyContractCount, 5);
      expect(
        weeklyContractCatalog.fold<int>(
          0,
          (sum, mission) => sum + mission.reward,
        ),
        450,
      );
      expect(weeklySeed('2026-W30#0'), 574722015);
      final first = chooseWeeklyContracts(weekKey: '2026-W30', rotation: 0);
      final retry = chooseWeeklyContracts(weekKey: '2026-W30', rotation: 0);
      expect(first, retry);
      expect(first, hasLength(5));
      expect(first.toSet(), hasLength(5));
      expect(
        first
            .map(
              (id) => weeklyContractCatalog
                  .firstWhere((mission) => mission.id == id)
                  .reward,
            )
            .fold<int>(0, (sum, reward) => sum + reward),
        lessThanOrEqualTo(250),
      );
    });

    test('refresh avoids current and claimed missions when possible', () {
      final next = chooseWeeklyContracts(
        weekKey: '2026-W30',
        rotation: 1,
        currentIds: const <String>['m_heats', 'm_wins', 'm_boss'],
        claimedIds: const <String>['m_big'],
      );
      expect(next, hasLength(5));
      expect(next.toSet(), hasLength(5));
      expect(next, isNot(contains('m_heats')));
    });

    test('weekly refresh keys migrate from old daily dates', () {
      expect(
        weeklyRefreshUsedForWeek(
          storedRefreshKey: '2026-W30',
          weekKey: '2026-W30',
        ),
        isTrue,
      );
      expect(
        weeklyRefreshUsedForWeek(
          storedRefreshKey: '2026-07-22',
          weekKey: '2026-W30',
        ),
        isTrue,
      );
      expect(
        weeklyRefreshUsedForWeek(
          storedRefreshKey: '2026-07-12',
          weekKey: '2026-W30',
        ),
        isFalse,
      );
    });

    test('refresh retains completed unclaimed missions', () {
      final refreshed = refreshedWeeklyContracts(
        weekKey: '2026-W30',
        rotation: 2,
        currentIds: const ['m_heats', 'm_wins', 'm_pair', 'm_hands', 'm_big'],
        claimedIds: const ['m_wins'],
        protectedIds: const ['m_heats', 'm_big'],
      );
      expect(refreshed, hasLength(5));
      expect(refreshed, containsAll(const ['m_heats', 'm_big']));
      expect(refreshed.toSet(), hasLength(5));
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

      const after = ProgressionGates(
        tutorialDone: true,
        bestClearedHeat: 12,
        unlockedJokers: 15,
      );
      expect(after.dailyChallengeUnlocked, isTrue);
      expect(after.stakeUnlocked, isTrue);
      expect(after.gauntletUnlocked, isTrue);
    });

    test('daily streak uses 5/10/15/20 and caps at 25', () {
      expect(dailyLoginRewardForStreak(1), 5);
      expect(dailyLoginRewardForStreak(2), 10);
      expect(dailyLoginRewardForStreak(3), 15);
      expect(dailyLoginRewardForStreak(4), 20);
      expect(dailyLoginRewardForStreak(5), 25);
      expect(dailyLoginRewardForStreak(1000), 25);

      final continuing = nextDailyLoginOffer(
        now: DateTime(2026, 7, 21, 18),
        lastClaim: DateTime(2026, 7, 20, 8),
        currentStreak: 4,
      );
      expect(continuing.available, isTrue);
      expect(continuing.streak, 5);
      expect(continuing.reward, 25);
      expect(continuing.tomorrowReward, 25);

      final alreadyClaimed = nextDailyLoginOffer(
        now: DateTime(2026, 7, 21, 18),
        lastClaim: DateTime(2026, 7, 21, 8),
        currentStreak: 5,
      );
      expect(alreadyClaimed.available, isFalse);

      final missedDay = nextDailyLoginOffer(
        now: DateTime(2026, 7, 21, 18),
        lastClaim: DateTime(2026, 7, 19, 8),
        currentStreak: 20,
      );
      expect(missedDay.streak, 1);
      expect(missedDay.reward, 5);

      final rollback = nextDailyLoginOffer(
        now: DateTime(2026, 7, 20, 18),
        lastClaim: DateTime(2026, 7, 21, 8),
        currentStreak: 5,
      );
      expect(rollback.available, isFalse);
      expect(rollback.streak, 5);
    });

    test('Daily Challenge progression and planned prizes remain disabled', () {
      expect(progressionEnabledForRun(isDailyRun: false), isTrue);
      expect(progressionEnabledForRun(isDailyRun: true), isFalse);
      expect(dailyBoardCoinPrizesActive, isFalse);
      expect(plannedDailyBoardCoinPrizes, <int, int>{1: 300, 2: 200, 3: 200});
    });
  });
}

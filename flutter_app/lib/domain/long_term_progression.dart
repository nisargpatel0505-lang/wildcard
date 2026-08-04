import 'joker_catalog.dart';

/// Durable lifetime counters used by v8.5's sequential badge tracks.
///
/// These keys are intentionally stable save-schema identifiers. Weekly
/// mission progress is reset every ISO week; these counters never are.
abstract final class ProgressCounterKey {
  static const endlessEntries = 'endlessEntries';
  static const runsWon = 'runsWon';
  static const royalFlushes = 'royalFlushes';
  static const bestSingleHand = 'bestSingleHand';
  static const vaultsOpened = 'vaultsOpened';
  static const bestDailyStreak = 'bestDailyStreak';
  static const weeklyMissionsClaimed = 'weeklyMissionsClaimed';
}

enum LongTermFamily {
  endless,
  wins,
  royalFlushes,
  singleHand,
  jokerDiscovery,
  vaults,
  dailyStreak,
  weeklyMissions,
}

enum LongTermTier { bronze, silver, gold, diamond, wild, legend }

class LongTermProgressSnapshot {
  const LongTermProgressSnapshot({
    this.endlessEntries = 0,
    this.runsWon = 0,
    this.royalFlushes = 0,
    this.bestSingleHand = 0,
    this.jokersDiscovered = 0,
    this.vaultsOpened = 0,
    this.bestDailyStreak = 0,
    this.weeklyMissionsClaimed = 0,
  });

  factory LongTermProgressSnapshot.fromCounters(
    Map<String, int> counters, {
    required int jokersDiscovered,
  }) => LongTermProgressSnapshot(
    endlessEntries: counters[ProgressCounterKey.endlessEntries] ?? 0,
    runsWon: counters[ProgressCounterKey.runsWon] ?? 0,
    royalFlushes: counters[ProgressCounterKey.royalFlushes] ?? 0,
    bestSingleHand: counters[ProgressCounterKey.bestSingleHand] ?? 0,
    jokersDiscovered: jokersDiscovered,
    vaultsOpened: counters[ProgressCounterKey.vaultsOpened] ?? 0,
    bestDailyStreak: counters[ProgressCounterKey.bestDailyStreak] ?? 0,
    weeklyMissionsClaimed:
        counters[ProgressCounterKey.weeklyMissionsClaimed] ?? 0,
  );

  final int endlessEntries;
  final int runsWon;
  final int royalFlushes;
  final int bestSingleHand;
  final int jokersDiscovered;
  final int vaultsOpened;
  final int bestDailyStreak;
  final int weeklyMissionsClaimed;

  int valueFor(LongTermFamily family) => switch (family) {
    LongTermFamily.endless => endlessEntries,
    LongTermFamily.wins => runsWon,
    LongTermFamily.royalFlushes => royalFlushes,
    LongTermFamily.singleHand => bestSingleHand,
    LongTermFamily.jokerDiscovery => jokersDiscovered,
    LongTermFamily.vaults => vaultsOpened,
    LongTermFamily.dailyStreak => bestDailyStreak,
    LongTermFamily.weeklyMissions => weeklyMissionsClaimed,
  };
}

class TieredAchievementDefinition {
  const TieredAchievementDefinition({
    required this.id,
    required this.family,
    required this.tier,
    required this.name,
    required this.description,
    required this.threshold,
    required this.rewardCoins,
    this.rewardTitleId,
  });

  final String id;
  final LongTermFamily family;
  final LongTermTier tier;
  final String name;
  final String description;
  final int threshold;
  final int rewardCoins;
  final String? rewardTitleId;
}

const List<TieredAchievementDefinition> tieredAchievementCatalog =
    <TieredAchievementDefinition>[
      TieredAchievementDefinition(
        id: 'tier_endless_1',
        family: LongTermFamily.endless,
        tier: LongTermTier.bronze,
        name: 'Beyond The House',
        description: 'Enter Endless once.',
        threshold: 1,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_endless_5',
        family: LongTermFamily.endless,
        tier: LongTermTier.silver,
        name: 'No Closing Time',
        description: 'Enter Endless 5 times.',
        threshold: 5,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_endless_10',
        family: LongTermFamily.endless,
        tier: LongTermTier.gold,
        name: 'After Hours',
        description: 'Enter Endless 10 times.',
        threshold: 10,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_endless_25',
        family: LongTermFamily.endless,
        tier: LongTermTier.diamond,
        name: 'Deep Run',
        description: 'Enter Endless 25 times.',
        threshold: 25,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_endless_50',
        family: LongTermFamily.endless,
        tier: LongTermTier.wild,
        name: 'Past Midnight',
        description: 'Enter Endless 50 times.',
        threshold: 50,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_endless_100',
        family: LongTermFamily.endless,
        tier: LongTermTier.legend,
        name: 'Eternal Runner',
        description: 'Enter Endless 100 times.',
        threshold: 100,
        rewardCoins: 0,
        rewardTitleId: 't_eternal',
      ),
      TieredAchievementDefinition(
        id: 'tier_wins_1',
        family: LongTermFamily.wins,
        tier: LongTermTier.bronze,
        name: 'First Take',
        description: 'Win 1 Standard run.',
        threshold: 1,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_wins_5',
        family: LongTermFamily.wins,
        tier: LongTermTier.silver,
        name: 'Winning Habit',
        description: 'Win 5 Standard runs.',
        threshold: 5,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_wins_15',
        family: LongTermFamily.wins,
        tier: LongTermTier.gold,
        name: 'House Favourite',
        description: 'Win 15 Standard runs.',
        threshold: 15,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_wins_30',
        family: LongTermFamily.wins,
        tier: LongTermTier.diamond,
        name: 'House Breaker',
        description: 'Win 30 Standard runs.',
        threshold: 30,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_wins_60',
        family: LongTermFamily.wins,
        tier: LongTermTier.wild,
        name: 'Sly Cannot Collect',
        description: 'Win 60 Standard runs.',
        threshold: 60,
        rewardCoins: 0,
        rewardTitleId: 't_house_master',
      ),
      TieredAchievementDefinition(
        id: 'tier_royal_1',
        family: LongTermFamily.royalFlushes,
        tier: LongTermTier.bronze,
        name: 'First Crown',
        description: 'Score 1 Royal Flush.',
        threshold: 1,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_royal_3',
        family: LongTermFamily.royalFlushes,
        tier: LongTermTier.silver,
        name: 'Triple Crown',
        description: 'Score 3 Royal Flushes.',
        threshold: 3,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_royal_10',
        family: LongTermFamily.royalFlushes,
        tier: LongTermTier.gold,
        name: 'Royal Regular',
        description: 'Score 10 Royal Flushes.',
        threshold: 10,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_royal_25',
        family: LongTermFamily.royalFlushes,
        tier: LongTermTier.diamond,
        name: 'Crown Collector',
        description: 'Score 25 Royal Flushes.',
        threshold: 25,
        rewardCoins: 30,
      ),
      TieredAchievementDefinition(
        id: 'tier_royal_50',
        family: LongTermFamily.royalFlushes,
        tier: LongTermTier.wild,
        name: 'Palace Royalty',
        description: 'Score 50 Royal Flushes.',
        threshold: 50,
        rewardCoins: 0,
        rewardTitleId: 't_royal_dealer',
      ),
      TieredAchievementDefinition(
        id: 'tier_hand_500',
        family: LongTermFamily.singleHand,
        tier: LongTermTier.bronze,
        name: 'Heavy Hand',
        description: 'Score 500 in one hand.',
        threshold: 500,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_hand_1500',
        family: LongTermFamily.singleHand,
        tier: LongTermTier.silver,
        name: 'Table Shaker',
        description: 'Score 1,500 in one hand.',
        threshold: 1500,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_hand_3000',
        family: LongTermFamily.singleHand,
        tier: LongTermTier.gold,
        name: 'Monster Hand',
        description: 'Score 3,000 in one hand.',
        threshold: 3000,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_hand_7500',
        family: LongTermFamily.singleHand,
        tier: LongTermTier.diamond,
        name: 'Scorequake',
        description: 'Score 7,500 in one hand.',
        threshold: 7500,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_hand_15000',
        family: LongTermFamily.singleHand,
        tier: LongTermTier.wild,
        name: 'Broken Counter',
        description: 'Score 15,000 in one hand.',
        threshold: 15000,
        rewardCoins: 30,
      ),
      TieredAchievementDefinition(
        id: 'tier_jokers_15',
        family: LongTermFamily.jokerDiscovery,
        tier: LongTermTier.bronze,
        name: 'New Faces',
        description: 'Discover 15 Jokers.',
        threshold: 15,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_jokers_30',
        family: LongTermFamily.jokerDiscovery,
        tier: LongTermTier.silver,
        name: 'Packed Sleeve',
        description: 'Discover 30 Jokers.',
        threshold: 30,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_jokers_50',
        family: LongTermFamily.jokerDiscovery,
        tier: LongTermTier.gold,
        name: 'Joker Cabinet',
        description: 'Discover 50 Jokers.',
        threshold: 50,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_jokers_75',
        family: LongTermFamily.jokerDiscovery,
        tier: LongTermTier.diamond,
        name: 'Full Cast',
        description: 'Discover 75 Jokers.',
        threshold: 75,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_jokers_100',
        family: LongTermFamily.jokerDiscovery,
        tier: LongTermTier.wild,
        name: 'Every Trick',
        description: 'Discover all $activePublicJokerCount active Jokers.',
        threshold: activePublicJokerCount,
        rewardCoins: 30,
      ),
      TieredAchievementDefinition(
        id: 'tier_vaults_1',
        family: LongTermFamily.vaults,
        tier: LongTermTier.bronze,
        name: 'First Lock',
        description: 'Open 1 Vault.',
        threshold: 1,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_vaults_5',
        family: LongTermFamily.vaults,
        tier: LongTermTier.silver,
        name: 'Lockpicker',
        description: 'Open 5 Vaults.',
        threshold: 5,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_vaults_15',
        family: LongTermFamily.vaults,
        tier: LongTermTier.gold,
        name: 'Vault Habit',
        description: 'Open 15 Vaults.',
        threshold: 15,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_vaults_40',
        family: LongTermFamily.vaults,
        tier: LongTermTier.diamond,
        name: 'Master Key',
        description: 'Open 40 Vaults.',
        threshold: 40,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_vaults_100',
        family: LongTermFamily.vaults,
        tier: LongTermTier.wild,
        name: 'Royal Locksmith',
        description: 'Open 100 Vaults.',
        threshold: 100,
        rewardCoins: 0,
        rewardTitleId: 't_vault_keeper',
      ),
      TieredAchievementDefinition(
        id: 'tier_daily_2',
        family: LongTermFamily.dailyStreak,
        tier: LongTermTier.bronze,
        name: 'Back Tomorrow',
        description: 'Reach a 2-day login streak.',
        threshold: 2,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_daily_5',
        family: LongTermFamily.dailyStreak,
        tier: LongTermTier.silver,
        name: 'Five At The Table',
        description: 'Reach a 5-day login streak.',
        threshold: 5,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_daily_10',
        family: LongTermFamily.dailyStreak,
        tier: LongTermTier.gold,
        name: 'Ten-Day Seat',
        description: 'Reach a 10-day login streak.',
        threshold: 10,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_daily_30',
        family: LongTermFamily.dailyStreak,
        tier: LongTermTier.diamond,
        name: 'House Regular',
        description: 'Reach a 30-day login streak.',
        threshold: 30,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_daily_100',
        family: LongTermFamily.dailyStreak,
        tier: LongTermTier.wild,
        name: 'Permanent Seat',
        description: 'Reach a 100-day login streak.',
        threshold: 100,
        rewardCoins: 30,
      ),
      TieredAchievementDefinition(
        id: 'tier_weekly_1',
        family: LongTermFamily.weeklyMissions,
        tier: LongTermTier.bronze,
        name: 'First Contract',
        description: 'Claim 1 Weekly Mission.',
        threshold: 1,
        rewardCoins: 5,
      ),
      TieredAchievementDefinition(
        id: 'tier_weekly_5',
        family: LongTermFamily.weeklyMissions,
        tier: LongTermTier.silver,
        name: 'Reliable Hand',
        description: 'Claim 5 Weekly Missions.',
        threshold: 5,
        rewardCoins: 10,
      ),
      TieredAchievementDefinition(
        id: 'tier_weekly_15',
        family: LongTermFamily.weeklyMissions,
        tier: LongTermTier.gold,
        name: 'Contract Player',
        description: 'Claim 15 Weekly Missions.',
        threshold: 15,
        rewardCoins: 15,
      ),
      TieredAchievementDefinition(
        id: 'tier_weekly_40',
        family: LongTermFamily.weeklyMissions,
        tier: LongTermTier.diamond,
        name: 'Sly On Speed Dial',
        description: 'Claim 40 Weekly Missions.',
        threshold: 40,
        rewardCoins: 20,
      ),
      TieredAchievementDefinition(
        id: 'tier_weekly_100',
        family: LongTermFamily.weeklyMissions,
        tier: LongTermTier.wild,
        name: 'Contract Legend',
        description: 'Claim 100 Weekly Missions.',
        threshold: 100,
        rewardCoins: 0,
        rewardTitleId: 't_contract_legend',
      ),
    ];

List<TieredAchievementDefinition> longTermFamilyTiers(LongTermFamily family) =>
    tieredAchievementCatalog
        .where((definition) => definition.family == family)
        .toList(growable: false);

bool longTermAchievementDone(
  TieredAchievementDefinition definition,
  LongTermProgressSnapshot progress,
) => progress.valueFor(definition.family) >= definition.threshold;

bool longTermAchievementClaimable(
  TieredAchievementDefinition definition,
  LongTermProgressSnapshot progress,
  Map<String, Object?> claimed,
) {
  if (claimed[definition.id] == true ||
      !longTermAchievementDone(definition, progress)) {
    return false;
  }
  final tiers = longTermFamilyTiers(definition.family);
  final index = tiers.indexWhere((candidate) => candidate.id == definition.id);
  if (index <= 0) return index == 0;
  return tiers.take(index).every((tier) => claimed[tier.id] == true);
}

TieredAchievementDefinition? visibleLongTermTier(
  LongTermFamily family,
  Map<String, Object?> claimed,
) {
  final tiers = longTermFamilyTiers(family);
  for (final tier in tiers) {
    if (claimed[tier.id] != true) return tier;
  }
  return tiers.isEmpty ? null : tiers.last;
}

String? titleRewardAchievementId(String titleId) {
  for (final definition in tieredAchievementCatalog) {
    if (definition.rewardTitleId == titleId) return definition.id;
  }
  return null;
}

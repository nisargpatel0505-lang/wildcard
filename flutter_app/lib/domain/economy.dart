import 'dart:math' as math;

import 'game_rules.dart';
import 'joker_catalog.dart';

const int rewardedCoinAmount = 25;
const int rewardedCoinDailyCap = 5;
const int interestPerRunCoins = 8;
const int interestCap = 3;
const int shopRerollCost = 3;
const int standardCompletionBonus = 10;
const Map<JokerRarity, double> shopRarityWeights = <JokerRarity, double>{
  JokerRarity.common: 4,
  JokerRarity.uncommon: 3.2,
  JokerRarity.rare: 3,
  JokerRarity.wild: 1.8,
};

int starterJokerPrice(JokerDefinition joker) => switch (joker.rarity) {
  JokerRarity.common => 6,
  JokerRarity.uncommon => 10,
  JokerRarity.rare => 16,
  JokerRarity.wild => 30,
};

bool isBossPreparationShop({
  required int stage,
  required bool endless,
  required bool gauntlet,
}) => !endless && (gauntlet ? stage == gauntletHeats - 1 : stage == 11);

int shopOfferCount({
  required int stage,
  required bool endless,
  required bool gauntlet,
}) => isBossPreparationShop(stage: stage, endless: endless, gauntlet: gauntlet)
    ? 4
    : 2;

int shopBuyLimit({
  required int stage,
  required bool endless,
  required bool gauntlet,
}) => isBossPreparationShop(stage: stage, endless: endless, gauntlet: gauntlet)
    ? 2
    : 1;

int runCoinInterest(int runCoins) =>
    math.min(interestCap, math.max(0, runCoins) ~/ interestPerRunCoins);

class HeatGrade {
  const HeatGrade(this.label, this.bonus);

  final String label;
  final int bonus;
}

const List<HeatGrade?> heatGrades = <HeatGrade?>[
  null,
  HeatGrade('S', 2),
  HeatGrade('A', 1),
  HeatGrade('B', 0),
  HeatGrade('C', 0),
];

HeatGrade gradeForPlays(int handsPlayed) =>
    heatGrades[handsPlayed.clamp(1, 4)]!;

enum SupplyId { scalpel, copier, dye, enhance, boost }

class SupplyDefinition {
  const SupplyDefinition(this.id, this.name, this.basePrice);

  final SupplyId id;
  final String name;
  final int basePrice;
}

const List<SupplyDefinition> supplyCatalog = <SupplyDefinition>[
  SupplyDefinition(SupplyId.scalpel, 'Scalpel', 3),
  SupplyDefinition(SupplyId.copier, 'Copier', 5),
  SupplyDefinition(SupplyId.dye, 'Dye Kit', 4),
  SupplyDefinition(SupplyId.enhance, 'Enhancer', 6),
  SupplyDefinition(SupplyId.boost, 'Hand Boost', 5),
];

class SupplyPurchaseLedgerEntry {
  const SupplyPurchaseLedgerEntry({
    required this.id,
    required this.stage,
    required this.step,
  });

  final SupplyId id;
  final int stage;
  final int step;

  factory SupplyPurchaseLedgerEntry.fromJson(Map<String, Object?> json) {
    final id = SupplyId.values.firstWhere(
      (candidate) => candidate.name == json['id'],
      orElse: () => throw FormatException('Unknown supply: ${json['id']}'),
    );
    final rawStage = int.tryParse('${json['stage'] ?? 0}') ?? 0;
    final rawStep = int.tryParse('${json['step'] ?? 0}') ?? 0;
    return SupplyPurchaseLedgerEntry(
      id: id,
      stage: math.max(0, rawStage),
      step: rawStep == 10 ? 10 : 5,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.name,
    'stage': stage,
    'step': step,
  };
}

/// v7.1.0 raises each supply permanently by +5, or +10 when bought after
/// Heat 20. Legacy v6.9 saves only stored counts; those migrate to +5 entries.
class SupplyPurchaseLedger {
  SupplyPurchaseLedger([Iterable<SupplyPurchaseLedgerEntry> entries = const []])
    : entries = List<SupplyPurchaseLedgerEntry>.from(entries);

  factory SupplyPurchaseLedger.fromLegacy({
    Object? ledgerJson,
    Object? purchaseCountsJson,
  }) {
    final entries = <SupplyPurchaseLedgerEntry>[];
    if (ledgerJson is List) {
      for (final value in ledgerJson) {
        if (value is! Map) continue;
        try {
          entries.add(
            SupplyPurchaseLedgerEntry.fromJson(
              value.map((key, item) => MapEntry(key.toString(), item)),
            ),
          );
        } on FormatException {
          // The web client drops unknown supply IDs during normalization.
        }
      }
    }
    final counts = purchaseCountsJson is Map
        ? purchaseCountsJson
        : const <Object?, Object?>{};
    for (final id in SupplyId.values) {
      final wanted = math.max(0, int.tryParse('${counts[id.name] ?? 0}') ?? 0);
      var have = entries.where((entry) => entry.id == id).length;
      while (have < wanted) {
        entries.add(SupplyPurchaseLedgerEntry(id: id, stage: 0, step: 5));
        have++;
      }
    }
    return SupplyPurchaseLedger(entries);
  }

  final List<SupplyPurchaseLedgerEntry> entries;

  int count(SupplyId id) => entries.where((entry) => entry.id == id).length;

  int surcharge(SupplyId id) => entries
      .where((entry) => entry.id == id)
      .fold<int>(0, (total, entry) => total + entry.step);

  void record(SupplyId id, int stage) {
    entries.add(
      SupplyPurchaseLedgerEntry(
        id: id,
        stage: math.max(0, stage),
        step: supplyIncreaseForStage(stage),
      ),
    );
  }

  List<Map<String, Object?>> toJson() =>
      entries.map((entry) => entry.toJson()).toList(growable: false);
}

int supplyIncreaseForStage(int stage) => stage > 20 ? 10 : 5;

int supplyPrice(
  SupplyDefinition supply, {
  required SupplyPurchaseLedger ledger,
  bool inflation = false,
}) => supply.basePrice + ledger.surcharge(supply.id) + (inflation ? 2 : 0);

enum JokerChestTier { wood, gold }

class JokerChestDefinition {
  const JokerChestDefinition({
    required this.tier,
    required this.basePrice,
    required this.rarityWeights,
  });

  final JokerChestTier tier;
  final int basePrice;
  final Map<JokerRarity, double> rarityWeights;

  int price(int unlockedCount) =>
      tier == JokerChestTier.wood && unlockedCount < 15 ? 60 : basePrice;

  Map<JokerRarity, double> effectiveOdds(Iterable<JokerDefinition> pool) {
    final available = pool.map((joker) => joker.rarity).toSet();
    final active = <JokerRarity, double>{
      for (final entry in rarityWeights.entries)
        if (entry.value > 0 && available.contains(entry.key))
          entry.key: entry.value,
    };
    final total = active.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const <JokerRarity, double>{};
    return <JokerRarity, double>{
      for (final entry in active.entries) entry.key: entry.value / total,
    };
  }

  JokerDefinition? roll(
    List<JokerDefinition> lockedPool, {
    required double rarityRoll,
    required double itemRoll,
  }) {
    final odds = effectiveOdds(lockedPool);
    if (odds.isEmpty) return null;
    var remaining = rarityRoll.clamp(0.0, 0.9999999999999999);
    var chosen = odds.keys.last;
    for (final entry in odds.entries) {
      remaining -= entry.value;
      if (remaining <= 0) {
        chosen = entry.key;
        break;
      }
    }
    final candidates = lockedPool
        .where((joker) => joker.rarity == chosen)
        .toList();
    final index = (itemRoll.clamp(0.0, 0.9999999999999999) * candidates.length)
        .floor();
    return candidates[index];
  }
}

const Map<JokerChestTier, JokerChestDefinition> jokerChests =
    <JokerChestTier, JokerChestDefinition>{
      JokerChestTier.wood: JokerChestDefinition(
        tier: JokerChestTier.wood,
        basePrice: 100,
        rarityWeights: <JokerRarity, double>{
          JokerRarity.common: 0.70,
          JokerRarity.uncommon: 0.26,
          JokerRarity.rare: 0.04,
          JokerRarity.wild: 0,
        },
      ),
      JokerChestTier.gold: JokerChestDefinition(
        tier: JokerChestTier.gold,
        basePrice: 300,
        rarityWeights: <JokerRarity, double>{
          JokerRarity.common: 0,
          JokerRarity.uncommon: 0.50,
          JokerRarity.rare: 0.42,
          JokerRarity.wild: 0.08,
        },
      ),
    };

const int stakeUnlockHeat = 5;
const int stakeMinimum = 10;
const int stakeStep = 10;
const int stakeHardMaximum = 200;
const List<int> stakePayoutPerHundred = <int>[
  0,
  5,
  10,
  18,
  28,
  40,
  55,
  72,
  92,
  115,
  140,
  170,
  200,
];
const List<int> gauntletStakePayoutPerHundred = <int>[
  0,
  6,
  12,
  20,
  30,
  42,
  58,
  80,
  200,
];

int stakePayout(
  int stake,
  int cleared, {
  RunDifficulty difficulty = RunDifficulty.medium,
}) =>
    (stakePayoutPerHundred[cleared.clamp(0, 12)] *
            stake /
            100 *
            difficulty.stakeMultiplier)
        .round();

int gauntletStakePayout(int stake, int cleared) =>
    (gauntletStakePayoutPerHundred[cleared.clamp(0, 8)] * stake / 100).round();

int maximumStake(int accountCoins, {bool gauntlet = false}) {
  var maximum = math.min(
    stakeHardMaximum,
    (accountCoins * 0.25 ~/ stakeStep) * stakeStep,
  );
  if (gauntlet) {
    maximum = math.min(maximum, (accountCoins / 2 ~/ stakeStep) * stakeStep);
  }
  return maximum;
}

const Set<String> playProductIds = <String>{
  'coins_250',
  'coins_600',
  'coins_1600',
  'coins_3600',
  'coins_8500',
  'remove_ads',
};

const Map<String, int> paidCoinGrants = <String, int>{
  'coins_250': 250,
  'coins_600': 600,
  'coins_1600': 1600,
  'coins_3600': 3600,
  'coins_8500': 8500,
};

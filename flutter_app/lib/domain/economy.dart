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
  // A discovered WILD is still a run-defining offer, not a routine reroll
  // result. Eligibility is separately delayed until the mid-game.
  JokerRarity.wild: 0.45,
};
const int wildShopMinimumHeat = 6;
const int highImpactShopMinimumHeat = 4;
const double highImpactShopWeightMultiplier = 0.5;

/// Non-WILD Jokers whose measured single-Joker lift is large enough to need
/// the same shelf-spacing protection as a WILD.
///
/// The set is deliberately about shop presentation only: rarity, effect,
/// score, price and permanent discovery rules remain unchanged.
const Set<String> highImpactShopJokerIds = <String>{
  'rarity_hunter',
  'flushfund',
  'rule_breaker',
  'danger_music',
  'purist',
  'survivor',
  'ensemble',
};

bool isHighImpactShopJoker(JokerDefinition joker) =>
    highImpactShopJokerIds.contains(joker.id);

bool isPremiumShopOffer(JokerDefinition joker) =>
    joker.rarity == JokerRarity.wild || isHighImpactShopJoker(joker);

bool jokerShopEligibleAtStage(
  JokerDefinition joker, {
  required int stage,
  int wildMinimumStage = wildShopMinimumHeat,
}) =>
    (joker.rarity != JokerRarity.wild || stage >= wildMinimumStage) &&
    (!isHighImpactShopJoker(joker) || stage >= highImpactShopMinimumHeat);

double jokerShopOfferWeight(JokerDefinition joker) =>
    shopRarityWeights[joker.rarity]! *
    (isHighImpactShopJoker(joker) ? highImpactShopWeightMultiplier : 1);

/// Draws weighted, duplicate-free Joker offers and caps the combined
/// high-impact/WILD group at one.
///
/// Callers remain responsible for applying account-discovery and progression
/// gates before passing [eligiblePool]. Injecting the random stream preserves
/// each mode's deterministic RNG ownership.
List<JokerDefinition> rollWeightedJokerOffers(
  Iterable<JokerDefinition> eligiblePool, {
  required int count,
  required double Function() nextDouble,
}) {
  final pool = List<JokerDefinition>.from(eligiblePool);
  final offers = <JokerDefinition>[];
  while (offers.length < count && pool.isNotEmpty) {
    final totalWeight = pool.fold<double>(
      0,
      (total, joker) => total + jokerShopOfferWeight(joker),
    );
    var roll = nextDouble().clamp(0.0, 0.9999999999999999) * totalWeight;
    var chosenIndex = pool.length - 1;
    for (var index = 0; index < pool.length; index++) {
      roll -= jokerShopOfferWeight(pool[index]);
      if (roll <= 0) {
        chosenIndex = index;
        break;
      }
    }
    final chosen = pool.removeAt(chosenIndex);
    offers.add(chosen);
    if (isPremiumShopOffer(chosen)) {
      pool.removeWhere(isPremiumShopOffer);
    }
  }
  return offers;
}

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
    required this.fallbackOrder,
  });

  final JokerChestTier tier;
  final int basePrice;
  final Map<JokerRarity, double> rarityWeights;
  final Map<JokerRarity, List<JokerRarity>> fallbackOrder;

  /// Kept as a method so old UI call sites remain source-compatible. Vault
  /// prices no longer change with collection size.
  int price([int unlockedCount = 0]) => basePrice;

  /// Returns the exact live odds used by [roll].
  ///
  /// Each configured rarity's probability flows to the first available rarity
  /// in its documented fallback list when that tier is exhausted. This makes
  /// duplicate protection deterministic and keeps the disclosed odds truthful
  /// for partially completed collections.
  Map<JokerRarity, double> effectiveOdds(Iterable<JokerDefinition> pool) {
    final available = pool.map((joker) => joker.rarity).toSet();
    final active = <JokerRarity, double>{};
    for (final entry in rarityWeights.entries) {
      if (entry.value <= 0) continue;
      final destinations = <JokerRarity>[
        entry.key,
        ...fallbackOrder[entry.key] ?? const <JokerRarity>[],
      ];
      JokerRarity? destination;
      for (final candidate in destinations) {
        if (available.contains(candidate) &&
            (rarityWeights[candidate] ?? 0) > 0) {
          destination = candidate;
          break;
        }
      }
      if (destination != null) {
        active[destination] = (active[destination] ?? 0) + entry.value;
      }
    }
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

const Map<JokerChestTier, JokerChestDefinition>
jokerChests = <JokerChestTier, JokerChestDefinition>{
  JokerChestTier.wood: JokerChestDefinition(
    tier: JokerChestTier.wood,
    basePrice: 200,
    rarityWeights: <JokerRarity, double>{
      JokerRarity.common: 0.70,
      JokerRarity.uncommon: 0.27,
      JokerRarity.rare: 0.03,
      JokerRarity.wild: 0,
    },
    fallbackOrder: <JokerRarity, List<JokerRarity>>{
      JokerRarity.common: <JokerRarity>[JokerRarity.uncommon, JokerRarity.rare],
      JokerRarity.uncommon: <JokerRarity>[JokerRarity.common, JokerRarity.rare],
      JokerRarity.rare: <JokerRarity>[JokerRarity.uncommon, JokerRarity.common],
    },
  ),
  JokerChestTier.gold: JokerChestDefinition(
    tier: JokerChestTier.gold,
    basePrice: 350,
    rarityWeights: <JokerRarity, double>{
      JokerRarity.common: 0,
      JokerRarity.uncommon: 0.52,
      JokerRarity.rare: 0.44,
      JokerRarity.wild: 0.04,
    },
    fallbackOrder: <JokerRarity, List<JokerRarity>>{
      JokerRarity.uncommon: <JokerRarity>[JokerRarity.rare, JokerRarity.wild],
      JokerRarity.rare: <JokerRarity>[JokerRarity.uncommon, JokerRarity.wild],
      JokerRarity.wild: <JokerRarity>[JokerRarity.rare, JokerRarity.uncommon],
    },
  ),
};

const int stakeUnlockHeat = 5;
const int stakeMinimum = 10;
const int stakeStep = 10;
const int stakeHardMaximum = 200;

/// Gross coins returned per 100 staked after each completed Heat.
///
/// The curve deliberately protects both ends of the contract:
///
/// * Heats 1-8 refund more of an early/mid loss, so the feature is not a
///   new-player coin trap once it unlocks.
/// * Heats 9-12 rise by 45 points in total rather than the previous 85, which
///   limits repeated late-progression farming.
/// * Heat 12 retains a clear 150 return so winning still feels materially
///   different from narrowly missing the finish.
///
/// Difficulty-specific risk is applied by [RunDifficulty.stakeMultiplier].
const List<int> stakePayoutPerHundred = <int>[
  0,
  20,
  35,
  45,
  55,
  70,
  82,
  92,
  100,
  105,
  110,
  115,
  150,
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

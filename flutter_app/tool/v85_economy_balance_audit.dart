import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/long_term_progression.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

const _harness = WildcardSimulationHarness();
const _horizons = <int>[1, 3, 7, 14, 30, 90, 180];
const _collectionMilestonePercents = <int>[10, 25, 50, 75, 90, 100];
const _specificWildJokerId = 'surge';
const _starterIds = <String>[
  'copper',
  'presser',
  'retainer',
  'even',
  'lowball',
  'uniform',
  'fulltable',
  'polish',
  'opening_act',
  'face_value',
];

/// A deterministic approximation of an account with 25 chest discoveries.
///
/// The extra 15 reflect Wood's early mix: nine Common, five Uncommon and one
/// Rare. It contains no WILD because Wood has zero WILD probability.
const _midDiscoveryIds = <String>[
  ..._starterIds,
  'acemag',
  'momentum',
  'inktrade',
  'triple3',
  'dividend',
  'couple',
  'sniper',
  'piggy',
  'cleaner',
  'flushfund',
  'wire',
  'dumpster',
  'overtime',
  'collector',
  'roller',
];

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  _validateAuthoritativeConfiguration();
  final output = Directory(options.outputDirectory)
    ..createSync(recursive: true);
  final started = DateTime.now().toUtc();

  stdout.writeln(
    'WILDCARD v8.5 economy/balance audit '
    'smartRuns=${options.smartRuns} '
    'economyAccounts=${options.economyAccounts} '
    'shopRolls=${options.shopRolls}',
  );

  final smart = _runSmartCohorts(options.smartRuns);
  final shop = _runShopAudit(options.shopRolls);
  final economy = _runEconomyAudit(
    accountCount: options.economyAccounts,
    smartCohorts: smart,
  );
  final verdicts = _buildVerdicts(smart, economy);

  final report = <String, Object?>{
    'schema': 1,
    'generatedAtUtc': started.toIso8601String(),
    'elapsedSeconds':
        DateTime.now().toUtc().difference(started).inMilliseconds / 1000,
    'configuration': <String, Object?>{
      'smartRunsPerCohort': options.smartRuns,
      'economyAccountsPerArchetype': options.economyAccounts,
      'normalFullPoolShopRolls': options.shopRolls,
      'arcadeFullPoolShopRolls': options.shopRolls,
      'metaEconomySeed': '0x85050000',
      'smartSeedBase': '0x71010000',
      'shopSeed': '0x85052000',
      'horizonsDays': _horizons,
      'collectionMilestonePercents': _collectionMilestonePercents,
      'publicJokers': jokerCatalog.length,
      'starterJokers': _starterIds,
      'midDiscoveryJokers': _midDiscoveryIds,
      'highImpactShopJokers': highImpactShopJokerIds.toList(growable: false),
      'highImpactMinimumHeat': highImpactShopMinimumHeat,
      'highImpactWeightMultiplier': highImpactShopWeightMultiplier,
      'wildPityMisses': wildPityAfterShops,
      'vaultPrices': <String, int>{
        'wood': jokerChests[JokerChestTier.wood]!.price(),
        'gold': jokerChests[JokerChestTier.gold]!.price(),
        'cosmetic': cosmeticVaultPrice,
      },
    },
    'beforeAfterEconomy': _beforeAfterEconomy(),
    'smartCohorts': smart.map((cohort) => cohort.toJson()).toList(),
    'shopGeneration': shop,
    'economy': economy,
    'verdicts': verdicts,
    'limitations': const <String>[
      'The Adaptive bot is strategic but not a human skill distribution.',
      'Small smart-cohort samples are directional; Wilson intervals are shown.',
      'Meta-economy accounts sample the measured Medium cohort histograms.',
      'Weekly mission completion is archetype-based and settles at week end.',
      'Legacy achievement income includes explicit milestones only, so it is a '
          'conservative lower bound rather than every possible hand achievement.',
      'Coin packs are currency grants only; no store price or revenue assumption '
          'is made.',
      'Daily Board prizes remain excluded because production prizes are off.',
      'Stake profit/loss is excluded because it is optional and skill-sensitive.',
    ],
  };
  final encoded = '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  final path = '${output.path}/v85_economy_balance_audit.json';
  File(path).writeAsStringSync(encoded);
  stdout.writeln('WROTE ${File(path).absolute.path}');
  if (options.durableOutput case final durable?) {
    final target = File(durable);
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(encoded);
    stdout.writeln('WROTE ${target.absolute.path}');
  }
  for (final verdict in verdicts) {
    stdout.writeln('VERDICT ${verdict['severity']}: ${verdict['message']}');
  }
}

Map<String, Object?> _beforeAfterEconomy() {
  int continuousLoginTotal(int days, int Function(int streak) rewardForStreak) {
    var total = 0;
    for (var streak = 1; streak <= days; streak++) {
      total += rewardForStreak(streak);
    }
    return total;
  }

  final currentWeeklyExpected =
      weeklyContractCatalog.fold<int>(
        0,
        (sum, mission) => sum + mission.reward,
      ) *
      visibleWeeklyContractCount /
      weeklyContractCatalog.length;
  final ownedAfterComeback = <String>{..._starterIds, 'wire'};
  final lockedNonWild = jokerCatalog
      .where(
        (joker) =>
            joker.rarity != JokerRarity.wild &&
            !ownedAfterComeback.contains(joker.id),
      )
      .length;
  final lockedWild = jokerCatalog
      .where(
        (joker) =>
            joker.rarity == JokerRarity.wild &&
            !ownedAfterComeback.contains(joker.id),
      )
      .length;
  final currentEfficientSink =
      lockedNonWild * jokerChests[JokerChestTier.wood]!.price() +
      lockedWild * jokerChests[JokerChestTier.gold]!.price();
  const legacyDirectSink = 17030;
  const legacyEfficientChestSink = 10340;

  return <String, Object?>{
    'baseline': <String, Object?>{
      'label': 'v8.4.0 pre-override',
      'commit': 'b23642ce4e71abf81ec7bb3675759a10b43d5f13',
      'permanentDirectJokerPurchase': true,
      'chosenDirectUnlockCatalogueCost': legacyDirectSink,
      'efficientChestOnlyCatalogueCostAfterComeback': legacyEfficientChestSink,
      'woodPrice': <String, int>{'newcomer': 60, 'standard': 100},
      'goldPrice': 300,
      'dailyLoginCurve': '30 + 18 per day, capped at 192',
      'continuousLoginIncome180Days': continuousLoginTotal(
        180,
        (streak) => math.min(192, 30 + 18 * math.max(0, streak - 1)),
      ),
      'visibleWeeklyMissions': 3,
      'expectedAllVisibleWeeklyReward': 700,
      'longTermTierCoinPool': 0,
    },
    'current': <String, Object?>{
      'label': 'v8.5.0 chest-only progression',
      'permanentDirectJokerPurchase': false,
      'efficientVaultCatalogueCostAfterComeback': currentEfficientSink,
      'efficientWoodOpens': lockedNonWild,
      'efficientGoldOpens': lockedWild,
      'woodPrice': jokerChests[JokerChestTier.wood]!.price(),
      'goldPrice': jokerChests[JokerChestTier.gold]!.price(),
      'dailyLoginCurve': '5 / 10 / 15 / 20 / 25+',
      'continuousLoginIncome180Days': continuousLoginTotal(
        180,
        dailyLoginRewardForStreak,
      ),
      'visibleWeeklyMissions': visibleWeeklyContractCount,
      'expectedAllVisibleWeeklyReward': currentWeeklyExpected,
      'longTermTierCoinPool': tieredAchievementCatalog.fold<int>(
        0,
        (sum, tier) => sum + tier.rewardCoins,
      ),
    },
    'delta': <String, Object?>{
      'vsLegacyDirectSinkCoins': currentEfficientSink - legacyDirectSink,
      'vsLegacyDirectSinkPercent':
          (currentEfficientSink / legacyDirectSink - 1) * 100,
      'vsLegacyEfficientChestSinkCoins':
          currentEfficientSink - legacyEfficientChestSink,
      'dailyLogin180DayDelta':
          continuousLoginTotal(180, dailyLoginRewardForStreak) -
          continuousLoginTotal(
            180,
            (streak) => math.min(192, 30 + 18 * math.max(0, streak - 1)),
          ),
      'expectedWeeklyVisibleDelta': currentWeeklyExpected - 700,
    },
    'interpretation':
        'v8.5 removes deterministic chosen-Joker purchasing and materially '
        'reduces recurring login/weekly faucets while adding small sequential '
        'long-term rewards. The higher duplicate-safe Vault sink is therefore '
        'evaluated with full 180-day account simulations below, not in isolation.',
  };
}

void _validateAuthoritativeConfiguration() {
  if (jokerCatalog.length != 102) {
    throw StateError(
      'Expected 102 public Jokers, found ${jokerCatalog.length}',
    );
  }
  if (_starterIds.toSet().length != 10 ||
      !_starterIds.every(starterJokerIds.contains) ||
      starterJokerIds.any((id) => !_starterIds.contains(id))) {
    throw StateError('The audit starter cohort no longer matches production');
  }
  if (_midDiscoveryIds.toSet().length != 25 ||
      _midDiscoveryIds.any((id) => !jokersById.containsKey(id))) {
    throw StateError('The fixed 25-Joker progression cohort is invalid');
  }
  if (_starterIds.any((id) => jokersById[id]!.rarity == JokerRarity.wild)) {
    throw StateError('A WILD Joker entered the starter cohort');
  }
  if (jokerChests[JokerChestTier.wood]!.price() != 200 ||
      jokerChests[JokerChestTier.gold]!.price() != 350 ||
      cosmeticVaultPrice != 1000) {
    throw StateError('Vault prices drifted from the v8.5 contract');
  }
  if ((jokerChests[JokerChestTier.wood]!.rarityWeights[JokerRarity.wild] ??
          -1) !=
      0) {
    throw StateError('Wood may not roll WILD Jokers');
  }
  if (paidCoinGrants.length != 5 ||
      paidCoinGrants['coins_250'] != 250 ||
      paidCoinGrants['coins_600'] != 600 ||
      paidCoinGrants['coins_1600'] != 1600 ||
      paidCoinGrants['coins_3600'] != 3600 ||
      paidCoinGrants['coins_8500'] != 8500) {
    throw StateError('Current coin-pack grants drifted from the audit matrix');
  }
  if (wildPityAfterShops != 24 ||
      highImpactShopMinimumHeat != 4 ||
      highImpactShopWeightMultiplier != 0.5 ||
      highImpactShopJokerIds.length != 7 ||
      highImpactShopJokerIds.any(
        (id) =>
            jokersById[id] == null ||
            jokersById[id]!.rarity == JokerRarity.wild,
      )) {
    throw StateError('Shop acquisition guardrails drifted');
  }
  if (jokersById[_specificWildJokerId]?.rarity != JokerRarity.wild) {
    throw StateError('The specific-WILD timing target is invalid');
  }
}

List<_SmartCohort> _runSmartCohorts(int runs) {
  final progressionPools = <String, List<String>>{
    'starter_10': _starterIds,
    'discovered_25': _midDiscoveryIds,
    'full_102': jokerCatalog.map((joker) => joker.id).toList(growable: false),
  };
  final result = <_SmartCohort>[];
  for (final difficulty in RunDifficulty.values) {
    for (final progression in progressionPools.entries) {
      final watch = Stopwatch()..start();
      final config = SimulationConfig(
        runs: runs,
        // Match the existing v8.4 strategy-audit seed range so a change in
        // Normal is not hidden by comparing unrelated random samples.
        firstSeed: 0x71010000,
        strategy: SimulationStrategy.adaptive,
        difficulty: difficulty,
        initialJokers: const <String>['copper', 'polish'],
        allJokersUnlocked: false,
        discoveredJokerIds: progression.value,
      );
      final report = _harness.runBatch(config);
      watch.stop();
      if (report.invariantFailureCount != 0) {
        throw StateError(
          '${difficulty.name}/${progression.key} produced '
          '${report.invariantFailureCount} invariant failures',
        );
      }
      final cohort = _SmartCohort(
        difficulty: difficulty,
        progression: progression.key,
        discoveredIds: progression.value,
        report: report,
        elapsed: watch.elapsed,
      );
      result.add(cohort);
      stdout.writeln(
        'SMART ${difficulty.name}/${progression.key}: '
        'wins=${report.wins}/$runs '
        'avgHeat=${report.averageHeatsCleared.toStringAsFixed(2)} '
        'coins/run=${cohort.averageAccountCoinsPerRun.toStringAsFixed(2)} '
        'time=${watch.elapsed.inSeconds}s',
      );
    }
  }
  return result;
}

Map<String, Object?> _runShopAudit(int fullRolls) {
  final samples = <Map<String, Object?>>[];
  samples.add(
    _shopSample(
      id: 'starter_heat_3',
      discoveredIds: _starterIds,
      stage: 3,
      rolls: math.max(20000, fullRolls ~/ 5),
      seed: 0x85052001,
    ),
  );
  samples.add(
    _shopSample(
      id: 'full_102_heat_3',
      discoveredIds: jokerCatalog
          .map((joker) => joker.id)
          .toList(growable: false),
      stage: 3,
      rolls: math.max(20000, fullRolls ~/ 5),
      seed: 0x85052002,
    ),
  );
  samples.add(
    _shopSample(
      id: 'discovered_25_heat_8',
      discoveredIds: _midDiscoveryIds,
      stage: 8,
      rolls: math.max(20000, fullRolls ~/ 5),
      seed: 0x85052003,
    ),
  );
  samples.add(
    _shopSample(
      id: 'full_102_heat_8',
      discoveredIds: jokerCatalog
          .map((joker) => joker.id)
          .toList(growable: false),
      stage: 8,
      rolls: fullRolls,
      seed: 0x85052004,
    ),
  );
  final normalGenerated = samples.fold<int>(
    0,
    (sum, sample) => sum + (sample['shops']! as int),
  );
  final arcadeSamples = <Map<String, Object?>>[
    _arcadeShopSample(
      id: 'arcade_full_102_round_3',
      round: 3,
      rolls: math.max(20000, fullRolls ~/ 5),
      seed: 0x85052005,
    ),
    _arcadeShopSample(
      id: 'arcade_full_102_post_gate',
      round: 12,
      rolls: fullRolls,
      seed: 0x85052006,
    ),
  ];
  final arcadeGenerated = arcadeSamples.fold<int>(
    0,
    (sum, sample) => sum + (sample['shops']! as int),
  );
  final invalid =
      samples.fold<int>(
        0,
        (sum, sample) => sum + (sample['invariantFailures']! as int),
      ) +
      arcadeSamples.fold<int>(
        0,
        (sum, sample) => sum + (sample['invariantFailures']! as int),
      );
  if (invalid != 0) {
    throw StateError('Shop generation produced $invalid invariant failures');
  }
  stdout.writeln(
    'SHOP normal=$normalGenerated arcade=$arcadeGenerated '
    'invariantFailures=$invalid',
  );
  return <String, Object?>{
    'normalShopsGenerated': normalGenerated,
    'arcadeShopsGenerated': arcadeGenerated,
    'totalShopsGenerated': normalGenerated + arcadeGenerated,
    'requiredCoreFullPoolShops': fullRolls,
    'invariantFailures': invalid,
    'normalSamples': samples,
    'arcadeSamples': arcadeSamples,
  };
}

Map<String, Object?> _arcadeShopSample({
  required String id,
  required int round,
  required int rolls,
  required int seed,
}) {
  final random = math.Random(seed);
  final discovered = jokerCatalog.map((joker) => joker.id).toSet();
  const held = <String>{'copper', 'polish'};
  final pool = jokerCatalog
      .where(
        (joker) => discovered.contains(joker.id) && !held.contains(joker.id),
      )
      .where(
        (joker) =>
            jokerShopEligibleAtStage(joker, stage: round, wildMinimumStage: 12),
      )
      .toList(growable: false);
  final rarityOffers = <JokerRarity, int>{
    for (final rarity in JokerRarity.values) rarity: 0,
  };
  var wildShops = 0;
  var highImpactShops = 0;
  var premiumShops = 0;
  var failures = 0;
  for (var shop = 0; shop < rolls; shop++) {
    final offers = rollWeightedJokerOffers(
      pool,
      count: 3,
      nextDouble: random.nextDouble,
    );
    final wildCount = offers
        .where((joker) => joker.rarity == JokerRarity.wild)
        .length;
    final highImpactCount = offers.where(isHighImpactShopJoker).length;
    final premiumCount = offers.where(isPremiumShopOffer).length;
    if (offers.length != 3 ||
        offers.map((joker) => joker.id).toSet().length != offers.length ||
        offers.any(
          (joker) => !discovered.contains(joker.id) || held.contains(joker.id),
        ) ||
        wildCount > 1 ||
        premiumCount > 1 ||
        (round < highImpactShopMinimumHeat && highImpactCount != 0) ||
        (round < 12 && wildCount != 0)) {
      failures++;
    }
    if (wildCount > 0) wildShops++;
    if (highImpactCount > 0) highImpactShops++;
    if (premiumCount > 0) premiumShops++;
    for (final offer in offers) {
      rarityOffers[offer.rarity] = rarityOffers[offer.rarity]! + 1;
    }
  }
  return <String, Object?>{
    'id': id,
    'shops': rolls,
    'round': round,
    'discoveredCount': discovered.length,
    'heldJokerIds': held.toList(growable: false),
    'offerCount': 3,
    'rarityOfferCounts': <String, int>{
      for (final entry in rarityOffers.entries) entry.key.name: entry.value,
    },
    'wildShopRate': wildShops / rolls,
    'highImpactShopRate': highImpactShops / rolls,
    'premiumShopRate': premiumShops / rolls,
    'pityEnabled': false,
    'invariantFailures': failures,
  };
}

Map<String, Object?> _shopSample({
  required String id,
  required List<String> discoveredIds,
  required int stage,
  required int rolls,
  required int seed,
}) {
  final random = math.Random(seed);
  final discovered = discoveredIds.toSet();
  final rarityOffers = <JokerRarity, int>{
    for (final rarity in JokerRarity.values) rarity: 0,
  };
  var wildMissShops = 0;
  var wildShops = 0;
  var highImpactShops = 0;
  var premiumShops = 0;
  var forcedWildShops = 0;
  var failures = 0;
  for (var shop = 0; shop < rolls; shop++) {
    final pool = jokerCatalog
        .where(
          (joker) =>
              discovered.contains(joker.id) &&
              jokerShopEligibleAtStage(joker, stage: stage),
        )
        .toList(growable: true);
    final wildPool = pool
        .where((joker) => joker.rarity == JokerRarity.wild)
        .toList(growable: false);
    final forceWild =
        wildPool.isNotEmpty && wildMissShops >= wildPityAfterShops;
    final offers = <JokerDefinition>[];
    if (forceWild) {
      final chosen = wildPool[random.nextInt(wildPool.length)];
      offers.add(chosen);
      pool.removeWhere(isPremiumShopOffer);
      forcedWildShops++;
    }
    offers.addAll(
      rollWeightedJokerOffers(
        pool,
        count: 2 - offers.length,
        nextDouble: random.nextDouble,
      ),
    );
    final wildCount = offers
        .where((joker) => joker.rarity == JokerRarity.wild)
        .length;
    final highImpactCount = offers.where(isHighImpactShopJoker).length;
    final premiumCount = offers.where(isPremiumShopOffer).length;
    if (offers.map((joker) => joker.id).toSet().length != offers.length ||
        offers.any((joker) => !discovered.contains(joker.id)) ||
        wildCount > 1 ||
        premiumCount > 1 ||
        (stage < wildShopMinimumHeat && wildCount != 0) ||
        (stage < highImpactShopMinimumHeat && highImpactCount != 0)) {
      failures++;
    }
    for (final offer in offers) {
      rarityOffers[offer.rarity] = rarityOffers[offer.rarity]! + 1;
    }
    if (wildCount > 0) {
      wildShops++;
      wildMissShops = 0;
    } else if (wildPool.isNotEmpty) {
      wildMissShops = math.min(wildPityAfterShops, wildMissShops + 1);
    }
    if (highImpactCount > 0) highImpactShops++;
    if (premiumCount > 0) premiumShops++;
  }
  return <String, Object?>{
    'id': id,
    'shops': rolls,
    'stage': stage,
    'discoveredCount': discovered.length,
    'offerCount': 2,
    'rarityOfferCounts': <String, int>{
      for (final entry in rarityOffers.entries) entry.key.name: entry.value,
    },
    'wildShopRate': wildShops / rolls,
    'highImpactShopRate': highImpactShops / rolls,
    'premiumShopRate': premiumShops / rolls,
    'pityForcedShopRate': forcedWildShops / rolls,
    'invariantFailures': failures,
  };
}

Map<String, Object?> _runEconomyAudit({
  required int accountCount,
  required List<_SmartCohort> smartCohorts,
}) {
  final medium = <String, _SmartCohort>{
    for (final cohort in smartCohorts)
      if (cohort.difficulty == RunDifficulty.medium) cohort.progression: cohort,
  };
  final humanProfiles = <_Archetype>[
    const _Archetype(
      name: 'casual_no_ads',
      loginProbability: 0.65,
      runsPerActiveDay: 1,
      rewardedViewsPerActiveDay: 0,
      weeklyMissionCompletion: 0.25,
      cosmeticEveryVaults: 0,
      goldEveryJokerVaults: 0,
      continueEndlessProbability: 0.15,
    ),
    const _Archetype(
      name: 'regular_no_ads',
      loginProbability: 0.90,
      runsPerActiveDay: 2,
      rewardedViewsPerActiveDay: 0,
      weeklyMissionCompletion: 0.55,
      cosmeticEveryVaults: 8,
      goldEveryJokerVaults: 5,
      continueEndlessProbability: 0.30,
    ),
    const _Archetype(
      name: 'regular_optional_ads',
      loginProbability: 0.90,
      runsPerActiveDay: 2,
      rewardedViewsPerActiveDay: 1,
      weeklyMissionCompletion: 0.60,
      cosmeticEveryVaults: 8,
      goldEveryJokerVaults: 5,
      continueEndlessProbability: 0.30,
    ),
    const _Archetype(
      name: 'engaged_rewarded',
      loginProbability: 0.98,
      runsPerActiveDay: 4,
      rewardedViewsPerActiveDay: 3,
      weeklyMissionCompletion: 0.88,
      cosmeticEveryVaults: 6,
      goldEveryJokerVaults: 4,
      continueEndlessProbability: 0.50,
    ),
  ];

  final humanOutput = <String, Object?>{};
  for (
    var profileIndex = 0;
    profileIndex < humanProfiles.length;
    profileIndex++
  ) {
    final profile = humanProfiles[profileIndex];
    final accounts = _simulateAccounts(
      profile: profile,
      accountCount: accountCount,
      seedBase: 0x85050000 + profileIndex * 100000,
      mediumCohorts: medium,
    );
    humanOutput[profile.name] = _economyCohortJson(profile, accounts);
    final horizons =
        (humanOutput[profile.name]! as Map<String, Object?>)['horizons']!
            as Map<String, Object?>;
    stdout.writeln(
      'ECON ${profile.name}: '
      'day30 discovered='
      '${(horizons['30']! as Map<String, Object?>)['jokerDiscoveredMedian']} '
      'day180 full='
      '${(humanOutput[profile.name]! as Map<String, Object?>)['fullJokerCollectionRateBy180']}',
    );
  }

  final acquisitionProfiles = <_Archetype>[
    const _Archetype(
      name: 'wood_only',
      loginProbability: 0.90,
      runsPerActiveDay: 2,
      rewardedViewsPerActiveDay: 0,
      weeklyMissionCompletion: 0.55,
      cosmeticEveryVaults: 0,
      goldEveryJokerVaults: 0,
      continueEndlessProbability: 0.30,
      acquisitionStrategy: _AcquisitionStrategy.woodOnly,
    ),
    const _Archetype(
      name: 'gold_only',
      loginProbability: 0.90,
      runsPerActiveDay: 2,
      rewardedViewsPerActiveDay: 0,
      weeklyMissionCompletion: 0.55,
      cosmeticEveryVaults: 0,
      goldEveryJokerVaults: 0,
      continueEndlessProbability: 0.30,
      acquisitionStrategy: _AcquisitionStrategy.goldOnly,
    ),
    const _Archetype(
      name: 'rational_mixed',
      loginProbability: 0.90,
      runsPerActiveDay: 2,
      rewardedViewsPerActiveDay: 0,
      weeklyMissionCompletion: 0.55,
      cosmeticEveryVaults: 0,
      goldEveryJokerVaults: 0,
      continueEndlessProbability: 0.30,
      acquisitionStrategy: _AcquisitionStrategy.rationalMixed,
    ),
  ];
  final acquisitionOutput = <String, Object?>{};
  for (final profile in acquisitionProfiles) {
    final accounts = _simulateAccounts(
      profile: profile,
      accountCount: accountCount,
      seedBase: 0x85080000,
      mediumCohorts: medium,
    );
    acquisitionOutput[profile.name] = <String, Object?>{
      ..._economyCohortJson(profile, accounts),
      'collectionMilestones': _collectionMilestoneSummary(accounts),
      'rarityAcquisition': _rarityAcquisitionSummary(accounts),
      'specificWildAcquisition': _specificWildSummary(accounts),
      'structuralLimit': switch (profile.acquisitionStrategy) {
        _AcquisitionStrategy.woodOnly =>
          'Wood has zero WILD odds, so this path cannot finish WILD or the '
              'full catalogue.',
        _AcquisitionStrategy.goldOnly =>
          'Gold has no Common fallback, so this path cannot finish Common or '
              'the full catalogue.',
        _AcquisitionStrategy.rationalMixed =>
          'Wood is used until every non-WILD is owned, then Gold is used for '
              'the seven WILD Jokers.',
        _AcquisitionStrategy.balanced => 'No structural restriction.',
      },
    };
  }

  const packIds = <String?>[
    null,
    'coins_250',
    'coins_600',
    'coins_1600',
    'coins_3600',
    'coins_8500',
  ];
  final packAccounts = <String, List<_EconomyAccount>>{};
  final packProfiles = <String, _Archetype>{};
  for (final packId in packIds) {
    final key = packId ?? 'no_pack';
    final profile = _Archetype(
      name: key,
      loginProbability: 0.90,
      runsPerActiveDay: 2,
      rewardedViewsPerActiveDay: 0,
      weeklyMissionCompletion: 0.55,
      cosmeticEveryVaults: 0,
      goldEveryJokerVaults: 0,
      continueEndlessProbability: 0.30,
      acquisitionStrategy: _AcquisitionStrategy.rationalMixed,
      coinPackGrants: packId == null
          ? const <int, String>{}
          : <int, String>{1: packId},
    );
    packProfiles[key] = profile;
    packAccounts[key] = _simulateAccounts(
      profile: profile,
      accountCount: accountCount,
      // Every pack path receives identical non-spending random streams. Pack
      // value is therefore isolated rather than confounded by activity luck.
      seedBase: 0x85090000,
      mediumCohorts: medium,
    );
  }
  final baselineAccounts = packAccounts['no_pack']!;
  final baselineDailyMedian = _dailyMedianJokers(baselineAccounts);
  final baselineMilestones = _collectionMilestoneSummary(baselineAccounts);
  final packOutput = <String, Object?>{};
  for (final key in packAccounts.keys) {
    final accounts = packAccounts[key]!;
    final cohort = _economyCohortJson(packProfiles[key]!, accounts);
    final milestones = _collectionMilestoneSummary(accounts);
    packOutput[key] = <String, Object?>{
      ...cohort,
      'collectionMilestones': milestones,
      'comparisonToNoPack': _packComparison(
        accounts: accounts,
        baselineDailyMedian: baselineDailyMedian,
        baselineMilestones: baselineMilestones,
        currentMilestones: milestones,
      ),
    };
  }

  final totalAccountPaths =
      humanProfiles.length + acquisitionProfiles.length + packIds.length;
  return <String, Object?>{
    'accountsPerCohort': accountCount,
    'accountCohorts': totalAccountPaths,
    'totalAccountsSimulated': totalAccountPaths * accountCount,
    'archetypes': humanOutput,
    'acquisitionStrategies': acquisitionOutput,
    'specificWildAnalyticReference': _specificWildAnalyticReference(),
    'coinPackComparison': <String, Object?>{
      'comparisonProfile':
          'regular no-ad, rational mixed Vault spending, identical random '
          'streams, one Day-1 grant',
      'paths': packOutput,
      'strictNoGameplayImpactClaim': false,
      'guardrail':
          'Packs grant currency only: they cannot choose a Joker, alter score '
          'math, targets, RNG, or buy a leaderboard result. They do accelerate '
          'duplicate-protected collection, which broadens future shop pools; '
          'that indirect gameplay impact is reported rather than hidden.',
    },
    'sharedRules': <String, Object?>{
      'startingCoins': starterGiftCoins,
      'freeComebackJoker': 'wire after first genuine Normal loss',
      'dailyStreak': <String, Object?>{
        'day1': 5,
        'day2': 10,
        'day3': 15,
        'day4': 20,
        'day5Plus': 25,
        'missedDayResets': true,
      },
      'weeklyVisibleMissions': visibleWeeklyContractCount,
      'weeklyMissionRewardRange': <int>[
        weeklyContractCatalog.map((mission) => mission.reward).reduce(math.min),
        weeklyContractCatalog.map((mission) => mission.reward).reduce(math.max),
      ],
      'rewardedCoinAmount': rewardedCoinAmount,
      'rewardedDailyCap': rewardedCoinDailyCap,
      'jokerAcquisition': 'starter + comeback + Joker Vaults only',
      'duplicateProtection': true,
      'directPermanentJokerPurchase': false,
      'coinPacksGrantCurrencyOnly': true,
      'coinPacksCannotChooseJoker': true,
      'coinPacksDoNotAlterScoringOrTargets': true,
    },
  };
}

List<_EconomyAccount> _simulateAccounts({
  required _Archetype profile,
  required int accountCount,
  required int seedBase,
  required Map<String, _SmartCohort> mediumCohorts,
}) {
  return <_EconomyAccount>[
    for (var index = 0; index < accountCount; index++)
      _EconomyAccount(
        profile: profile,
        seed: seedBase + index,
        mediumCohorts: mediumCohorts,
      )..runThrough(_horizons.last),
  ];
}

Map<String, Object?> _economyCohortJson(
  _Archetype profile,
  List<_EconomyAccount> accounts,
) {
  final finalSnapshots = accounts
      .map((account) => account.snapshots[_horizons.last]!)
      .toList(growable: false);
  return <String, Object?>{
    'assumptions': profile.toJson(),
    'accounts': accounts.length,
    'horizons': <String, Object?>{
      for (final horizon in _horizons)
        '$horizon': _aggregateHorizon(
          accounts.map((account) => account.snapshots[horizon]!).toList(),
        ),
    },
    'fullJokerCollectionRateBy180':
        finalSnapshots.where((item) => item.fullJokerCollection).length /
        accounts.length,
    'fullCosmeticCollectionRateBy180':
        finalSnapshots.where((item) => item.fullCosmeticCollection).length /
        accounts.length,
    'fullJokerCollectionDayMedian': _nullableMedian(
      accounts.map((account) => account.fullJokerCollectionDay),
    ),
    'fullCosmeticCollectionDayMedian': _nullableMedian(
      accounts.map((account) => account.fullCosmeticCollectionDay),
    ),
    'insolvencyFlagRateBy180':
        finalSnapshots.where((item) => item.insolvencyFlag).length /
        accounts.length,
    'tooFastUnlockFlagRateBy180':
        finalSnapshots.where((item) => item.tooFastUnlockFlag).length /
        accounts.length,
    'directJokerPurchaseSpend': 0,
  };
}

Map<String, Object?> _collectionMilestoneSummary(
  List<_EconomyAccount> accounts,
) {
  return <String, Object?>{
    for (final percent in _collectionMilestonePercents)
      '$percent': () {
        final threshold = (jokerCatalog.length * percent / 100).ceil();
        final days = accounts.map(
          (account) => account.firstDayAtJokerCount(threshold),
        );
        final completed = days.whereType<int>().toList(growable: false);
        return <String, Object?>{
          'thresholdJokers': threshold,
          'completionRateBy180': completed.length / accounts.length,
          'medianDay': _nullableMedian(days),
          'meanDay': _nullableMean(days),
        };
      }(),
  };
}

Map<String, Object?> _rarityAcquisitionSummary(List<_EconomyAccount> accounts) {
  return <String, Object?>{
    for (final rarity in JokerRarity.values)
      rarity.name: <String, Object?>{
        'catalogueCount': jokerCatalog
            .where((joker) => joker.rarity == rarity)
            .length,
        'starterOwnedCount': _starterIds
            .where((id) => jokersById[id]!.rarity == rarity)
            .length,
        'firstVaultDiscoveryDayMedian': _nullableMedian(
          accounts.map((account) => account.firstVaultRarityDay[rarity]),
        ),
        'firstVaultDiscoveryDayMean': _nullableMean(
          accounts.map((account) => account.firstVaultRarityDay[rarity]),
        ),
        'completeRarityRateBy180':
            accounts
                .where(
                  (account) => account.fullRarityCollectionDay[rarity] != null,
                )
                .length /
            accounts.length,
        'completeRarityDayMedian': _nullableMedian(
          accounts.map((account) => account.fullRarityCollectionDay[rarity]),
        ),
      },
  };
}

Map<String, Object?> _specificWildSummary(List<_EconomyAccount> accounts) {
  final target = jokersById[_specificWildJokerId]!;
  final acquired = accounts
      .where((account) => account.specificWildAcquisitionDay != null)
      .toList(growable: false);
  return <String, Object?>{
    'jokerId': target.id,
    'jokerName': target.name,
    'acquisitionRateBy180': acquired.length / accounts.length,
    'dayMedian': _nullableMedian(
      accounts.map((account) => account.specificWildAcquisitionDay),
    ),
    'dayMean': _nullableMean(
      accounts.map((account) => account.specificWildAcquisitionDay),
    ),
    'jokerVaultOrdinalMedian': _nullableMedian(
      accounts.map((account) => account.specificWildJokerVaultOrdinal),
    ),
    'jokerVaultOrdinalMean': _nullableMean(
      accounts.map((account) => account.specificWildJokerVaultOrdinal),
    ),
    'goldVaultOrdinalMedian': _nullableMedian(
      accounts.map((account) => account.specificWildGoldVaultOrdinal),
    ),
    'goldVaultOrdinalMean': _nullableMean(
      accounts.map((account) => account.specificWildGoldVaultOrdinal),
    ),
    'vaultSpendAtAcquisitionMedian': _nullableMedian(
      accounts.map((account) => account.specificWildVaultSpend),
    ),
    'rationalMixedExactGoldChestExpectationAfterNonWild': 4,
  };
}

Map<String, Object?> _specificWildAnalyticReference() {
  final ownedAfterComeback = <String>{..._starterIds, 'wire'};
  int remaining(JokerRarity rarity) => jokerCatalog
      .where(
        (joker) =>
            joker.rarity == rarity && !ownedAfterComeback.contains(joker.id),
      )
      .length;
  final uncommon = remaining(JokerRarity.uncommon);
  final rare = remaining(JokerRarity.rare);
  final wild = remaining(JokerRarity.wild);
  final memo = <(int, int, int), double>{};
  double expectedGold(int uncommonLeft, int rareLeft, int wildLeft) {
    if (wildLeft <= 0) return 0;
    final key = (uncommonLeft, rareLeft, wildLeft);
    final cached = memo[key];
    if (cached != null) return cached;
    final available = <JokerRarity>{
      if (uncommonLeft > 0) JokerRarity.uncommon,
      if (rareLeft > 0) JokerRarity.rare,
      JokerRarity.wild,
    };
    final odds = <JokerRarity, double>{};
    final chest = jokerChests[JokerChestTier.gold]!;
    for (final entry in chest.rarityWeights.entries) {
      if (entry.value <= 0) continue;
      final destinations = <JokerRarity>[
        entry.key,
        ...chest.fallbackOrder[entry.key] ?? const <JokerRarity>[],
      ];
      final destination = destinations.where(available.contains).firstOrNull;
      if (destination != null) {
        odds[destination] = (odds[destination] ?? 0) + entry.value;
      }
    }
    final total = odds.values.fold<double>(0, (sum, value) => sum + value);
    final uncommonChance = (odds[JokerRarity.uncommon] ?? 0) / total;
    final rareChance = (odds[JokerRarity.rare] ?? 0) / total;
    final wildChance = (odds[JokerRarity.wild] ?? 0) / total;
    final value =
        1 +
        (uncommonLeft > 0
            ? uncommonChance *
                  expectedGold(uncommonLeft - 1, rareLeft, wildLeft)
            : 0) +
        (rareLeft > 0
            ? rareChance * expectedGold(uncommonLeft, rareLeft - 1, wildLeft)
            : 0) +
        wildChance *
            (wildLeft - 1) /
            wildLeft *
            expectedGold(uncommonLeft, rareLeft, wildLeft - 1);
    memo[key] = value;
    return value;
  }

  final goldOnlyExpected = expectedGold(uncommon, rare, wild);
  final rationalGoldExpected = (wild + 1) / 2;
  final lockedNonWild = jokerCatalog
      .where(
        (joker) =>
            joker.rarity != JokerRarity.wild &&
            !ownedAfterComeback.contains(joker.id),
      )
      .length;
  return <String, Object?>{
    'jokerId': _specificWildJokerId,
    'jokerName': jokersById[_specificWildJokerId]!.name,
    'startingLockedCounts': <String, int>{
      'uncommon': uncommon,
      'rare': rare,
      'wild': wild,
    },
    'goldOnlyUncensoredExpectedGoldChests': goldOnlyExpected,
    'goldOnlyUncensoredExpectedCoins':
        goldOnlyExpected * jokerChests[JokerChestTier.gold]!.price(),
    'rationalMixedExpectedGoldChestsAfterNonWild': rationalGoldExpected,
    'rationalMixedExpectedTotalJokerVaults':
        lockedNonWild + rationalGoldExpected,
    'rationalMixedExpectedCoins':
        lockedNonWild * jokerChests[JokerChestTier.wood]!.price() +
        rationalGoldExpected * jokerChests[JokerChestTier.gold]!.price(),
    'woodOnlyExpectedChests': null,
    'woodOnlyReason': 'Wood has zero WILD probability.',
  };
}

List<num> _dailyMedianJokers(List<_EconomyAccount> accounts) => <num>[
  for (var dayIndex = 0; dayIndex < _horizons.last; dayIndex++)
    _percentile(
      accounts.map((account) => account.jokerCountByDay[dayIndex]),
      0.50,
    ),
];

Map<String, Object?> _packComparison({
  required List<_EconomyAccount> accounts,
  required List<num> baselineDailyMedian,
  required Map<String, Object?> baselineMilestones,
  required Map<String, Object?> currentMilestones,
}) {
  final horizonComparison = <String, Object?>{};
  for (final horizon in _horizons) {
    final currentMedian = _percentile(
      accounts.map((account) => account.jokerCountByDay[horizon - 1]),
      0.50,
    );
    final baselineMedian = baselineDailyMedian[horizon - 1];
    final equivalentIndex = baselineDailyMedian.indexWhere(
      (count) => count >= currentMedian,
    );
    horizonComparison['$horizon'] = <String, Object?>{
      'jokerDiscoveredMedian': currentMedian,
      'collectionPercentMedian': currentMedian / jokerCatalog.length * 100,
      'jokerDeltaVsNoPack': currentMedian - baselineMedian,
      'collectionPercentagePointDeltaVsNoPack':
          (currentMedian - baselineMedian) / jokerCatalog.length * 100,
      'noPackEquivalentDay': equivalentIndex < 0 ? null : equivalentIndex + 1,
      'medianLeadDaysVsNoPack': equivalentIndex < 0
          ? null
          : equivalentIndex + 1 - horizon,
    };
  }
  return <String, Object?>{
    'horizons': horizonComparison,
    'milestoneDaysSavedVsNoPack': <String, Object?>{
      for (final percent in _collectionMilestonePercents)
        '$percent': () {
          final baseline =
              (baselineMilestones['$percent']!
                      as Map<String, Object?>)['medianDay']
                  as num?;
          final current =
              (currentMilestones['$percent']!
                      as Map<String, Object?>)['medianDay']
                  as num?;
          return baseline == null || current == null
              ? null
              : baseline - current;
        }(),
    },
  };
}

num? _nullableMedian(Iterable<int?> source) {
  final values = source.whereType<int>().toList();
  return values.isEmpty ? null : _percentile(values, 0.50);
}

double? _nullableMean(Iterable<int?> source) {
  final values = source.whereType<int>().toList(growable: false);
  if (values.isEmpty) return null;
  return values.reduce((left, right) => left + right) / values.length;
}

Map<String, Object?> _aggregateHorizon(List<_EconomySnapshot> values) {
  double rate(bool Function(_EconomySnapshot item) test) =>
      values.where(test).length / values.length;
  return <String, Object?>{
    'coinsP10': _percentile(values.map((item) => item.coins), 0.10),
    'coinsMedian': _percentile(values.map((item) => item.coins), 0.50),
    'coinsP90': _percentile(values.map((item) => item.coins), 0.90),
    'jokerDiscoveredP10': _percentile(
      values.map((item) => item.jokersDiscovered),
      0.10,
    ),
    'jokerDiscoveredMedian': _percentile(
      values.map((item) => item.jokersDiscovered),
      0.50,
    ),
    'jokerDiscoveredP90': _percentile(
      values.map((item) => item.jokersDiscovered),
      0.90,
    ),
    'cosmeticsMedian': _percentile(
      values.map((item) => item.cosmeticsOwned),
      0.50,
    ),
    'vaultsMedian': _percentile(values.map((item) => item.vaultsOpened), 0.50),
    'incomeMedian': _percentile(values.map((item) => item.totalIncome), 0.50),
    'runIncomeMedian': _percentile(values.map((item) => item.runIncome), 0.50),
    'loginIncomeMedian': _percentile(
      values.map((item) => item.loginIncome),
      0.50,
    ),
    'weeklyIncomeMedian': _percentile(
      values.map((item) => item.weeklyIncome),
      0.50,
    ),
    'rewardedIncomeMedian': _percentile(
      values.map((item) => item.rewardedIncome),
      0.50,
    ),
    'packIncomeMedian': _percentile(
      values.map((item) => item.packIncome),
      0.50,
    ),
    'progressionIncomeMedian': _percentile(
      values.map((item) => item.progressionIncome),
      0.50,
    ),
    'fullJokerCollectionRate': rate((item) => item.fullJokerCollection),
    'fullCosmeticCollectionRate': rate((item) => item.fullCosmeticCollection),
    'insolvencyFlagRate': rate((item) => item.insolvencyFlag),
    'tooFastUnlockFlagRate': rate((item) => item.tooFastUnlockFlag),
  };
}

num _percentile(Iterable<int> source, double percentile) {
  final values = source.toList()..sort();
  final position = (values.length - 1) * percentile;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return values[lower];
  final fraction = position - lower;
  return double.parse(
    (values[lower] * (1 - fraction) + values[upper] * fraction).toStringAsFixed(
      1,
    ),
  );
}

List<Map<String, Object?>> _buildVerdicts(
  List<_SmartCohort> smart,
  Map<String, Object?> economy,
) {
  _SmartCohort cohort(RunDifficulty difficulty, String progression) =>
      smart.firstWhere(
        (item) =>
            item.difficulty == difficulty && item.progression == progression,
      );
  final mediumFull = cohort(RunDifficulty.medium, 'full_102');
  final hardFull = cohort(RunDifficulty.hard, 'full_102');
  final mediumInterval = mediumFull.winRate95;
  const referenceLow = 0.326;
  const referenceHigh = 0.386;
  final normalOverlapsReference =
      mediumInterval.$1 <= referenceHigh && mediumInterval.$2 >= referenceLow;
  final hardSevere =
      hardFull.report.winRate < 0.03 &&
      hardFull.report.averageHeatsCleared < 6.0;

  final archetypes = economy['archetypes']! as Map<String, Object?>;
  final fastProfiles = <String>[];
  final insolventProfiles = <String>[];
  for (final entry in archetypes.entries) {
    final profile = entry.value as Map<String, Object?>;
    if ((profile['tooFastUnlockFlagRateBy180']! as double) > 0.10) {
      fastProfiles.add(entry.key);
    }
    if ((profile['insolvencyFlagRateBy180']! as double) > 0.25) {
      insolventProfiles.add(entry.key);
    }
  }
  final packComparison = economy['coinPackComparison']! as Map<String, Object?>;
  final packPaths = packComparison['paths']! as Map<String, Object?>;
  final tooFastPackPaths = <String>[
    for (final entry in packPaths.entries)
      if (((entry.value as Map<String, Object?>)['tooFastUnlockFlagRateBy180']!
              as double) >
          0.10)
        entry.key,
  ];
  return <Map<String, Object?>>[
    <String, Object?>{
      'id': 'normal_stability',
      'severity': normalOverlapsReference ? 'pass' : 'needs-larger-sample',
      'message': normalOverlapsReference
          ? 'Medium/full overlaps the v8.4.1 35.6% reference interval; no '
                'Normal target change is supported.'
          : 'Medium/full does not overlap the v8.4.1 reference interval; rerun '
                'a larger cohort before changing Normal.',
    },
    <String, Object?>{
      'id': 'hard_difficulty',
      'severity': hardSevere ? 'review' : 'pass',
      'message': hardSevere
          ? 'Hard/full meets the predeclared severe-friction threshold; inspect '
                'before release, but do not rebalance from this sample alone.'
          : 'Hard/full does not meet the severe-friction threshold; no immediate '
                'Hard target change is supported.',
    },
    <String, Object?>{
      'id': 'economy_unlock_speed',
      'severity': fastProfiles.isEmpty ? 'pass' : 'review',
      'message': fastProfiles.isEmpty
          ? 'No archetype crosses the too-fast collection threshold.'
          : 'Too-fast collection flags exceeded 10% for: '
                '${fastProfiles.join(', ')}.',
    },
    <String, Object?>{
      'id': 'economy_insolvency',
      'severity': insolventProfiles.isEmpty ? 'pass' : 'review',
      'message': insolventProfiles.isEmpty
          ? 'No archetype exceeds the 25% sustained-insolvency threshold.'
          : 'Sustained inability to afford the intended next Vault exceeded '
                '25% for: ${insolventProfiles.join(', ')}.',
    },
    const <String, Object?>{
      'id': 'direct_joker_sink',
      'severity': 'pass',
      'message':
          'The model spends zero account coins on direct permanent '
          'Joker purchases; all non-starter discovery uses Vaults.',
    },
    <String, Object?>{
      'id': 'coin_pack_acceleration_guardrail',
      'severity': tooFastPackPaths.isEmpty ? 'pass' : 'review',
      'message': tooFastPackPaths.isEmpty
          ? 'No Day-1 coin pack path crosses the predeclared too-fast '
                'collection threshold.'
          : 'The following currency-only pack paths cross the predeclared '
                'too-fast collection threshold: ${tooFastPackPaths.join(', ')}. '
                'They still cannot choose a Joker or alter scoring, but this '
                'acceleration must not be described as strict zero-impact '
                'non-P2W.',
    },
  ];
}

int _accountCoinsForRun(int heatsCleared) {
  var result = 0;
  for (var heat = 1; heat <= math.min(12, heatsCleared); heat++) {
    result += accountReward(heat);
  }
  if (heatsCleared >= 12) result += standardCompletionBonus;
  return result;
}

class _SmartCohort {
  const _SmartCohort({
    required this.difficulty,
    required this.progression,
    required this.discoveredIds,
    required this.report,
    required this.elapsed,
  });

  final RunDifficulty difficulty;
  final String progression;
  final List<String> discoveredIds;
  final SimulationBatchReport report;
  final Duration elapsed;

  double get averageAccountCoinsPerRun =>
      report.results
          .map((run) => _accountCoinsForRun(run.heatsCleared))
          .reduce((left, right) => left + right) /
      report.results.length;

  (double, double) get winRate95 => _wilson(report.wins, report.results.length);

  Map<String, Object?> toJson() {
    final interval = winRate95;
    return <String, Object?>{
      'difficulty': difficulty.name,
      'progression': progression,
      'discoveredCount': discoveredIds.length,
      'discoveredIds': discoveredIds,
      ...report.toJson(),
      'averageAccountCoinsPerRun': averageAccountCoinsPerRun,
      'winRate95': <String, double>{'low': interval.$1, 'high': interval.$2},
      'elapsedSeconds': elapsed.inMilliseconds / 1000,
    };
  }
}

(double, double) _wilson(int successes, int total) {
  if (total <= 0) return (0, 0);
  const z = 1.959963984540054;
  final rate = successes / total;
  final denominator = 1 + z * z / total;
  final centre = (rate + z * z / (2 * total)) / denominator;
  final radius =
      z *
      math.sqrt((rate * (1 - rate) + z * z / (4 * total)) / total) /
      denominator;
  return (math.max(0, centre - radius), math.min(1, centre + radius));
}

enum _AcquisitionStrategy { balanced, woodOnly, goldOnly, rationalMixed }

class _Archetype {
  const _Archetype({
    required this.name,
    required this.loginProbability,
    required this.runsPerActiveDay,
    required this.rewardedViewsPerActiveDay,
    required this.weeklyMissionCompletion,
    required this.cosmeticEveryVaults,
    required this.goldEveryJokerVaults,
    required this.continueEndlessProbability,
    this.acquisitionStrategy = _AcquisitionStrategy.balanced,
    this.coinPackGrants = const <int, String>{},
  });

  final String name;
  final double loginProbability;
  final int runsPerActiveDay;
  final int rewardedViewsPerActiveDay;
  final double weeklyMissionCompletion;
  final int cosmeticEveryVaults;
  final int goldEveryJokerVaults;
  final double continueEndlessProbability;
  final _AcquisitionStrategy acquisitionStrategy;
  final Map<int, String> coinPackGrants;

  Map<String, Object?> toJson() => <String, Object?>{
    'loginProbability': loginProbability,
    'runsPerActiveDay': runsPerActiveDay,
    'rewardedViewsPerActiveDay': rewardedViewsPerActiveDay,
    'weeklyMissionCompletion': weeklyMissionCompletion,
    'cosmeticEveryVaults': cosmeticEveryVaults,
    'goldEveryJokerVaults': goldEveryJokerVaults,
    'continueEndlessProbability': continueEndlessProbability,
    'acquisitionStrategy': acquisitionStrategy.name,
    'coinPackGrants': <String, String>{
      for (final entry in coinPackGrants.entries) '${entry.key}': entry.value,
    },
  };
}

class _EconomyAccount {
  _EconomyAccount({
    required this.profile,
    required int seed,
    required this.mediumCohorts,
  }) : coins = starterGiftCoins,
       activityRandom = math.Random(seed ^ 0x13579),
       runRandom = math.Random(seed ^ 0x24680),
       eventRandom = math.Random(seed ^ 0x97531),
       weeklyRandom = math.Random(seed ^ 0x86420),
       vaultRandom = math.Random(seed ^ 0x55aa55aa),
       unlockedJokers = Set<String>.from(_starterIds),
       ownedCosmetics = Set<String>.from(defaultCosmeticIds),
       totalIncome = starterGiftCoins,
       progressionIncome = 0;

  final _Archetype profile;
  final math.Random activityRandom;
  final math.Random runRandom;
  final math.Random eventRandom;
  final math.Random weeklyRandom;
  final math.Random vaultRandom;
  final Map<String, _SmartCohort> mediumCohorts;
  final Set<String> unlockedJokers;
  final Set<String> ownedCosmetics;
  final Set<String> claimedTierIds = <String>{};
  final Set<String> claimedLegacyIds = <String>{};
  final Map<int, _EconomySnapshot> snapshots = <int, _EconomySnapshot>{};
  final List<int> jokerCountByDay = <int>[];
  final Map<JokerRarity, int> firstVaultRarityDay = <JokerRarity, int>{};
  final Map<JokerRarity, int> fullRarityCollectionDay = <JokerRarity, int>{};

  int coins;
  int totalIncome;
  int runIncome = 0;
  int loginIncome = 0;
  int weeklyIncome = 0;
  int rewardedIncome = 0;
  int packIncome = 0;
  int progressionIncome;
  int vaultSpend = 0;
  int vaultsOpened = 0;
  int jokerVaultsOpened = 0;
  int woodVaultsOpened = 0;
  int goldVaultsOpened = 0;
  int weeklyMissionsClaimed = 0;
  int dailyStreak = 0;
  int bestDailyStreak = 0;
  int lastLoginDay = 0;
  int runs = 0;
  int wins = 0;
  int endlessEntries = 0;
  int royalFlushes = 0;
  int bestSingleHand = 0;
  int handsPlayed = 0;
  int maxHeatsCleared = 0;
  int consecutiveCashStrappedActiveDays = 0;
  int? fullJokerCollectionDay;
  int? fullCosmeticCollectionDay;
  int? specificWildAcquisitionDay;
  int? specificWildJokerVaultOrdinal;
  int? specificWildGoldVaultOrdinal;
  int? specificWildVaultSpend;
  bool comebackClaimed = false;
  bool insolvencyFlag = false;
  bool tooFastUnlockFlag = false;

  void runThrough(int days) {
    for (var day = 1; day <= days; day++) {
      final active =
          day == 1 || activityRandom.nextDouble() < profile.loginProbability;
      if (active) _activeDay(day);
      if (day % 7 == 0) _settleWeeklyMissions(day);
      _claimProgressionRewards();
      if (active) _spendCoins(day);
      _claimProgressionRewards();
      jokerCountByDay.add(unlockedJokers.length);
      if (_horizons.contains(day)) snapshots[day] = _snapshot(day);
    }
  }

  void _activeDay(int day) {
    dailyStreak = lastLoginDay == day - 1 ? dailyStreak + 1 : 1;
    lastLoginDay = day;
    bestDailyStreak = math.max(bestDailyStreak, dailyStreak);
    _credit(dailyLoginRewardForStreak(dailyStreak), _IncomeKind.login);

    final pack = profile.coinPackGrants[day];
    if (pack != null) {
      final grant = paidCoinGrants[pack];
      if (grant == null) throw StateError('Unknown coin pack $pack');
      _credit(grant, _IncomeKind.pack);
    }

    final adViews = math.min(
      rewardedCoinDailyCap,
      profile.rewardedViewsPerActiveDay,
    );
    _credit(adViews * rewardedCoinAmount, _IncomeKind.rewarded);

    for (var run = 0; run < profile.runsPerActiveDay; run++) {
      final cohort = unlockedJokers.length < 20
          ? mediumCohorts['starter_10']!
          : unlockedJokers.length < 50
          ? mediumCohorts['discovered_25']!
          : mediumCohorts['full_102']!;
      final sampled = cohort
          .report
          .results[runRandom.nextInt(cohort.report.results.length)];
      runs++;
      handsPlayed += sampled.handsPlayed;
      maxHeatsCleared = math.max(maxHeatsCleared, sampled.heatsCleared);
      _credit(_accountCoinsForRun(sampled.heatsCleared), _IncomeKind.run);
      if (sampled.heatsCleared >= 12) {
        wins++;
        if (eventRandom.nextDouble() < profile.continueEndlessProbability) {
          endlessEntries++;
        }
      } else if (!comebackClaimed) {
        final comeback = jokersById['wire']!;
        if (!unlockedJokers.contains(comeback.id)) {
          unlockedJokers.add(comeback.id);
          _updateRarityCompletion(day);
        }
        comebackClaimed = true;
      }
      // Rare event proxy used only for the low-value sequential Royal track.
      if (eventRandom.nextDouble() < sampled.handsPlayed * 0.00015) {
        royalFlushes++;
      }
      final singleHandProxy = sampled.heatsCleared >= 12
          ? 3000
          : sampled.heatsCleared >= 10
          ? 1500
          : sampled.heatsCleared >= 6
          ? 500
          : 0;
      bestSingleHand = math.max(bestSingleHand, singleHandProxy);
    }
    _claimLegacyMilestones();
  }

  void _settleWeeklyMissions(int day) {
    final missionIds = chooseWeeklyContracts(
      weekKey: 'SIM-W${day ~/ 7}',
      rotation: 0,
    );
    for (final id in missionIds) {
      if (weeklyRandom.nextDouble() >= profile.weeklyMissionCompletion) {
        continue;
      }
      final mission = weeklyContractCatalog.firstWhere((item) => item.id == id);
      weeklyMissionsClaimed++;
      _credit(mission.reward, _IncomeKind.weekly);
    }
    _claimLegacyMilestones();
  }

  void _spendCoins(int day) {
    var bought = false;
    for (var guard = 0; guard < 128; guard++) {
      final choice = _nextVaultChoice();
      if (choice == null) break;
      final price = switch (choice) {
        _VaultChoice.wood => jokerChests[JokerChestTier.wood]!.price(),
        _VaultChoice.gold => jokerChests[JokerChestTier.gold]!.price(),
        _VaultChoice.cosmetic => cosmeticVaultPrice,
      };
      if (coins < price) break;
      final beforeJokers = unlockedJokers.length;
      final beforeCosmetics = ownedCosmetics.length;
      switch (choice) {
        case _VaultChoice.wood:
        case _VaultChoice.gold:
          final tier = choice == _VaultChoice.wood
              ? JokerChestTier.wood
              : JokerChestTier.gold;
          final locked = jokerCatalog
              .where((joker) => !unlockedJokers.contains(joker.id))
              .toList(growable: false);
          final reward = jokerChests[tier]!.roll(
            locked,
            rarityRoll: vaultRandom.nextDouble(),
            itemRoll: vaultRandom.nextDouble(),
          );
          if (reward == null || unlockedJokers.contains(reward.id)) {
            throw StateError('Joker Vault duplicate/fallthrough failure');
          }
          unlockedJokers.add(reward.id);
          firstVaultRarityDay.putIfAbsent(reward.rarity, () => day);
          if (reward.id == _specificWildJokerId) {
            specificWildAcquisitionDay ??= day;
            specificWildJokerVaultOrdinal ??= jokerVaultsOpened + 1;
            specificWildGoldVaultOrdinal ??= tier == JokerChestTier.gold
                ? goldVaultsOpened + 1
                : null;
            specificWildVaultSpend ??= vaultSpend + price;
          }
          jokerVaultsOpened++;
          if (tier == JokerChestTier.wood) {
            woodVaultsOpened++;
          } else {
            goldVaultsOpened++;
          }
          _updateRarityCompletion(day);
        case _VaultChoice.cosmetic:
          final locked = cosmeticCatalog
              .where(
                (cosmetic) =>
                    !cosmetic.isDefault &&
                    !ownedCosmetics.contains(cosmetic.id),
              )
              .toList(growable: false);
          final reward = rollCosmeticVault(
            locked,
            themeRoll: vaultRandom.nextDouble(),
            itemRoll: vaultRandom.nextDouble(),
          );
          if (reward == null || ownedCosmetics.contains(reward.id)) {
            throw StateError('Cosmetic Vault duplicate/fallthrough failure');
          }
          ownedCosmetics.add(reward.id);
      }
      if (unlockedJokers.length == beforeJokers &&
          ownedCosmetics.length == beforeCosmetics) {
        throw StateError('Vault spent coins without a new item');
      }
      coins -= price;
      vaultSpend += price;
      vaultsOpened++;
      bought = true;
      if (unlockedJokers.length == jokerCatalog.length) {
        fullJokerCollectionDay ??= day;
      }
      if (ownedCosmetics.length == cosmeticCatalog.length) {
        fullCosmeticCollectionDay ??= day;
      }
    }

    final next = _nextVaultChoice();
    final nextPrice = switch (next) {
      _VaultChoice.wood => jokerChests[JokerChestTier.wood]!.price(),
      _VaultChoice.gold => jokerChests[JokerChestTier.gold]!.price(),
      _VaultChoice.cosmetic => cosmeticVaultPrice,
      null => 0,
    };
    if (next != null && coins < nextPrice && !bought) {
      consecutiveCashStrappedActiveDays++;
      if (consecutiveCashStrappedActiveDays >= 14) insolvencyFlag = true;
    } else {
      consecutiveCashStrappedActiveDays = 0;
    }
    if (day <= 7 && unlockedJokers.length >= 50 ||
        day <= 30 && unlockedJokers.length == jokerCatalog.length) {
      tooFastUnlockFlag = true;
    }
  }

  _VaultChoice? _nextVaultChoice() {
    final lockedJokers = jokerCatalog
        .where((joker) => !unlockedJokers.contains(joker.id))
        .toList(growable: false);
    final lockedCosmetics = cosmeticCatalog.length - ownedCosmetics.length;
    final lockedNonWild = lockedJokers
        .where((joker) => joker.rarity != JokerRarity.wild)
        .length;
    final lockedWild = lockedJokers
        .where((joker) => joker.rarity == JokerRarity.wild)
        .length;
    final woodAvailable = jokerChests[JokerChestTier.wood]!
        .effectiveOdds(lockedJokers)
        .isNotEmpty;
    final goldAvailable = jokerChests[JokerChestTier.gold]!
        .effectiveOdds(lockedJokers)
        .isNotEmpty;
    switch (profile.acquisitionStrategy) {
      case _AcquisitionStrategy.woodOnly:
        return woodAvailable ? _VaultChoice.wood : null;
      case _AcquisitionStrategy.goldOnly:
        return goldAvailable ? _VaultChoice.gold : null;
      case _AcquisitionStrategy.rationalMixed:
        if (lockedNonWild > 0 && woodAvailable) return _VaultChoice.wood;
        if (lockedWild > 0 && goldAvailable) return _VaultChoice.gold;
        return null;
      case _AcquisitionStrategy.balanced:
        break;
    }
    if (lockedNonWild == 0 && lockedWild == 0) {
      return lockedCosmetics > 0 ? _VaultChoice.cosmetic : null;
    }
    if (profile.cosmeticEveryVaults > 0 &&
        lockedCosmetics > 0 &&
        unlockedJokers.length >= 20 &&
        (vaultsOpened + 1) % profile.cosmeticEveryVaults == 0) {
      return _VaultChoice.cosmetic;
    }
    if (lockedNonWild == 0) return _VaultChoice.gold;
    if (profile.goldEveryJokerVaults > 0 &&
        unlockedJokers.length >= 20 &&
        (jokerVaultsOpened + 1) % profile.goldEveryJokerVaults == 0 &&
        jokerChests[JokerChestTier.gold]!
            .effectiveOdds(
              jokerCatalog.where((joker) => !unlockedJokers.contains(joker.id)),
            )
            .isNotEmpty) {
      return _VaultChoice.gold;
    }
    return _VaultChoice.wood;
  }

  void _updateRarityCompletion(int day) {
    for (final rarity in JokerRarity.values) {
      if (fullRarityCollectionDay.containsKey(rarity)) continue;
      final allOwned = jokerCatalog
          .where((joker) => joker.rarity == rarity)
          .every((joker) => unlockedJokers.contains(joker.id));
      if (allOwned) fullRarityCollectionDay[rarity] = day;
    }
  }

  int? firstDayAtJokerCount(int target) {
    final index = jokerCountByDay.indexWhere((count) => count >= target);
    return index < 0 ? null : index + 1;
  }

  void _claimProgressionRewards() {
    var claimed = true;
    while (claimed) {
      claimed = false;
      final progress = LongTermProgressSnapshot(
        endlessEntries: endlessEntries,
        runsWon: wins,
        royalFlushes: royalFlushes,
        bestSingleHand: bestSingleHand,
        jokersDiscovered: unlockedJokers.length,
        vaultsOpened: vaultsOpened,
        bestDailyStreak: bestDailyStreak,
        weeklyMissionsClaimed: weeklyMissionsClaimed,
      );
      final claimedMap = <String, Object?>{
        for (final id in claimedTierIds) id: true,
      };
      for (final definition in tieredAchievementCatalog) {
        if (!longTermAchievementClaimable(definition, progress, claimedMap)) {
          continue;
        }
        claimedTierIds.add(definition.id);
        _credit(definition.rewardCoins, _IncomeKind.progression);
        claimed = true;
      }
    }
  }

  void _claimLegacyMilestones() {
    void claim(String id, bool earned) {
      if (!earned || !claimedLegacyIds.add(id)) return;
      final definition = achievementCatalog.firstWhere((item) => item.id == id);
      _credit(definition.reward, _IncomeKind.progression);
    }

    claim('first_pair', runs >= 1);
    claim('heat3', maxHeatsCleared >= 3);
    claim('heat6', maxHeatsCleared >= 6);
    claim('heat7', maxHeatsCleared >= 7);
    claim('heat10', maxHeatsCleared >= 10);
    claim('first_win', wins >= 1);
    claim('endless_reach', endlessEntries >= 1);
    claim('veteran_25', runs >= 25);
    claim('dealer_500', handsPlayed >= 500);
    claim('mission_one', weeklyMissionsClaimed >= 1);
    claim(
      'wild_joker',
      unlockedJokers.any((id) => jokersById[id]?.rarity == JokerRarity.wild),
    );
    claim(
      'full_wild',
      unlockedJokers
              .where((id) => jokersById[id]?.rarity == JokerRarity.wild)
              .length >=
          2,
    );
    claim('couture_5', ownedCosmetics.length >= 5);
    claim('bankroll', coins >= 500);
    claim('bankroll_2000', coins >= 2000);
  }

  void _credit(int amount, _IncomeKind kind) {
    if (amount <= 0) return;
    coins += amount;
    totalIncome += amount;
    switch (kind) {
      case _IncomeKind.run:
        runIncome += amount;
      case _IncomeKind.login:
        loginIncome += amount;
      case _IncomeKind.weekly:
        weeklyIncome += amount;
      case _IncomeKind.rewarded:
        rewardedIncome += amount;
      case _IncomeKind.pack:
        packIncome += amount;
      case _IncomeKind.progression:
        progressionIncome += amount;
    }
  }

  _EconomySnapshot _snapshot(int day) => _EconomySnapshot(
    day: day,
    coins: coins,
    jokersDiscovered: unlockedJokers.length,
    cosmeticsOwned: ownedCosmetics.length,
    vaultsOpened: vaultsOpened,
    totalIncome: totalIncome,
    runIncome: runIncome,
    loginIncome: loginIncome,
    weeklyIncome: weeklyIncome,
    rewardedIncome: rewardedIncome,
    packIncome: packIncome,
    progressionIncome: progressionIncome,
    fullJokerCollection: fullJokerCollectionDay != null,
    fullCosmeticCollection: fullCosmeticCollectionDay != null,
    insolvencyFlag: insolvencyFlag,
    tooFastUnlockFlag: tooFastUnlockFlag,
  );
}

enum _VaultChoice { wood, gold, cosmetic }

enum _IncomeKind { run, login, weekly, rewarded, pack, progression }

class _EconomySnapshot {
  const _EconomySnapshot({
    required this.day,
    required this.coins,
    required this.jokersDiscovered,
    required this.cosmeticsOwned,
    required this.vaultsOpened,
    required this.totalIncome,
    required this.runIncome,
    required this.loginIncome,
    required this.weeklyIncome,
    required this.rewardedIncome,
    required this.packIncome,
    required this.progressionIncome,
    required this.fullJokerCollection,
    required this.fullCosmeticCollection,
    required this.insolvencyFlag,
    required this.tooFastUnlockFlag,
  });

  final int day;
  final int coins;
  final int jokersDiscovered;
  final int cosmeticsOwned;
  final int vaultsOpened;
  final int totalIncome;
  final int runIncome;
  final int loginIncome;
  final int weeklyIncome;
  final int rewardedIncome;
  final int packIncome;
  final int progressionIncome;
  final bool fullJokerCollection;
  final bool fullCosmeticCollection;
  final bool insolvencyFlag;
  final bool tooFastUnlockFlag;
}

class _Options {
  const _Options({
    required this.smartRuns,
    required this.economyAccounts,
    required this.shopRolls,
    required this.outputDirectory,
    required this.durableOutput,
  });

  factory _Options.parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      if (!argument.startsWith('--') || !argument.contains('=')) {
        throw FormatException('Expected --name=value, got "$argument"');
      }
      final separator = argument.indexOf('=');
      values[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
    int positive(String name, int fallback) {
      final value = int.tryParse(values[name] ?? '$fallback');
      if (value == null || value < 1) {
        throw FormatException('--$name must be a positive integer');
      }
      return value;
    }

    return _Options(
      smartRuns: positive('smart-runs', 20),
      economyAccounts: positive('economy-accounts', 1000),
      shopRolls: positive('shop-rolls', 100000),
      outputDirectory:
          values['output'] ?? 'build/simulation/v85_economy_balance',
      durableOutput: values['durable-output'],
    );
  }

  final int smartRuns;
  final int economyAccounts;
  final int shopRolls;
  final String outputDirectory;
  final String? durableOutput;
}

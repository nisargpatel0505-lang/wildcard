import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/game/game_controller.dart';
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

  group('authoritative Vault configuration', () {
    test('Deep-Endless WILD drought protection starts after 24 misses', () {
      expect(wildPityAfterShops, 24);
    });

    test('measured high-impact Jokers use the shared shelf guardrail', () {
      expect(highImpactShopMinimumHeat, 4);
      expect(highImpactShopWeightMultiplier, 0.5);
      expect(highImpactShopJokerIds, <String>{
        'rarity_hunter',
        'flushfund',
        'rule_breaker',
        'danger_music',
        'purist',
        'survivor',
        'ensemble',
      });
      for (final joker in jokerCatalog) {
        if (!highImpactShopJokerIds.contains(joker.id)) continue;
        expect(joker.rarity, isNot(JokerRarity.wild));
        expect(
          jokerShopEligibleAtStage(joker, stage: highImpactShopMinimumHeat - 1),
          isFalse,
        );
        expect(
          jokerShopEligibleAtStage(joker, stage: highImpactShopMinimumHeat),
          isTrue,
        );
        expect(
          jokerShopOfferWeight(joker),
          shopRarityWeights[joker.rarity]! * highImpactShopWeightMultiplier,
        );
      }
    });

    test('prices and disclosed full-pool odds match the roll source', () {
      final wood = jokerChests[JokerChestTier.wood]!;
      final gold = jokerChests[JokerChestTier.gold]!;

      expect(wood.price(0), 200);
      expect(wood.price(101), 200);
      expect(gold.price(0), 350);
      expect(cosmeticVaultPrice, 1000);

      final woodOdds = wood.effectiveOdds(jokerCatalog);
      final goldOdds = gold.effectiveOdds(jokerCatalog);
      expect(woodOdds[JokerRarity.common], closeTo(.70, 1e-12));
      expect(woodOdds[JokerRarity.uncommon], closeTo(.27, 1e-12));
      expect(woodOdds[JokerRarity.rare], closeTo(.03, 1e-12));
      expect(woodOdds[JokerRarity.wild] ?? 0, 0);
      expect(goldOdds[JokerRarity.uncommon], closeTo(.52, 1e-12));
      expect(goldOdds[JokerRarity.rare], closeTo(.44, 1e-12));
      expect(goldOdds[JokerRarity.wild], closeTo(.04, 1e-12));

      final cosmeticOdds = cosmeticVaultEffectiveOdds(
        cosmeticCatalog.where((cosmetic) => !cosmetic.isDefault),
      );
      expect(
        cosmeticOdds.values.fold<double>(0, (sum, value) => sum + value),
        closeTo(1, 1e-12),
      );
      expect(cosmeticOdds.keys, isNotEmpty);
    });

    test('duplicate protection falls through deterministically', () {
      final wood = jokerChests[JokerChestTier.wood]!;
      final uncommon = jokerCatalog.firstWhere(
        (joker) => joker.rarity == JokerRarity.uncommon,
      );
      final rare = jokerCatalog.firstWhere(
        (joker) => joker.rarity == JokerRarity.rare,
      );
      final liveOdds = wood.effectiveOdds(<JokerDefinition>[uncommon, rare]);

      expect(liveOdds[JokerRarity.uncommon], closeTo(.97, 1e-12));
      expect(liveOdds[JokerRarity.rare], closeTo(.03, 1e-12));
      expect(
        wood.roll(
          <JokerDefinition>[uncommon, rare],
          rarityRoll: 0,
          itemRoll: 0,
        ),
        uncommon,
      );
      expect(
        wood.roll(<JokerDefinition>[rare], rarityRoll: 0, itemRoll: 0),
        rare,
      );
    });

    test('Wood can never resolve a WILD and exhausted pools are safe', () {
      final wood = jokerChests[JokerChestTier.wood]!;
      final wild = jokerCatalog.firstWhere(
        (joker) => joker.rarity == JokerRarity.wild,
      );
      expect(wood.effectiveOdds(<JokerDefinition>[wild]), isEmpty);
      expect(
        wood.roll(
          <JokerDefinition>[wild],
          rarityRoll: .999999,
          itemRoll: .999999,
        ),
        isNull,
      );
      for (var step = 0; step < 1000; step++) {
        final reward = wood.roll(
          jokerCatalog,
          rarityRoll: step / 1000,
          itemRoll: ((step * 37) % 1000) / 1000,
        );
        expect(reward?.rarity, isNot(JokerRarity.wild));
      }
    });

    test(
      'weighted shop offers are deterministic, unique, and max one WILD',
      () {
        final pool = jokerCatalog
            .where((joker) => joker.id != 'copper' && joker.id != 'polish')
            .toList(growable: false);
        final firstRandom = math.Random(0x85052401);
        final secondRandom = math.Random(0x85052401);
        var shopsWithWild = 0;

        for (var shop = 0; shop < 50000; shop++) {
          final first = rollWeightedJokerOffers(
            pool,
            count: 3,
            nextDouble: firstRandom.nextDouble,
          );
          final second = rollWeightedJokerOffers(
            pool,
            count: 3,
            nextDouble: secondRandom.nextDouble,
          );
          expect(
            first.map((joker) => joker.id),
            orderedEquals(second.map((joker) => joker.id)),
          );
          expect(first, hasLength(3));
          expect(first.map((joker) => joker.id).toSet(), hasLength(3));
          final wildCount = first
              .where((joker) => joker.rarity == JokerRarity.wild)
              .length;
          expect(wildCount, lessThanOrEqualTo(1));
          expect(first.where(isPremiumShopOffer).length, lessThanOrEqualTo(1));
          if (wildCount == 1) shopsWithWild++;
        }

        final wildShopRate = shopsWithWild / 50000;
        expect(wildShopRate, inInclusiveRange(0.02, 0.04));
      },
    );
  });

  group('durable account discovery', () {
    test(
      'legacy ownership is preserved while starters are migrated in',
      () async {
        final legacyOwned = jokerCatalog.firstWhere(
          (joker) => !joker.starter && joker.rarity == JokerRarity.uncommon,
        );
        SharedPreferences.setMockInitialValues(<String, Object>{
          'wildcard_save_v1': AccountState(
            unlockedJokerIds: <String>{legacyOwned.id},
          ).encode(),
        });

        final app = await AppController.bootstrap();
        addTearDown(app.dispose);
        expect(app.account.unlockedJokerIds, contains(legacyOwned.id));
        expect(app.account.unlockedJokerIds, containsAll(starterJokerIds));
        expect(
          app.account.unlockedJokerIds,
          hasLength(starterJokerIds.length + 1),
        );
      },
    );

    test('a Joker Vault saves once and replays one idempotent claim', () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      final existing = jokerCatalog.firstWhere(
        (joker) => !joker.starter && joker.rarity == JokerRarity.rare,
      );
      await app.mutateAccount((account) {
        account.coins = 1000;
        account.unlockedJokerIds.add(existing.id);
      }, syncCloud: false);
      final before = Set<String>.from(app.account.unlockedJokerIds);

      final reward = await app.openJokerVault(
        JokerChestTier.wood,
        claimId: 'test-wood-claim',
        rarityRoll: 0,
        itemRoll: 0,
      );
      expect(reward, isNotNull);
      expect(reward!.rarity, isNot(JokerRarity.wild));
      expect(app.account.coins, 800);
      expect(app.account.unlockedJokerIds, containsAll(before));
      expect(app.account.unlockedJokerIds, contains(reward.id));
      final afterFirst = Set<String>.from(app.account.unlockedJokerIds);

      final replay = await app.openJokerVault(
        JokerChestTier.wood,
        claimId: 'test-wood-claim',
        rarityRoll: .999,
        itemRoll: .999,
      );
      expect(replay?.id, reward.id);
      expect(app.account.coins, 800);
      expect(app.account.unlockedJokerIds, afterFirst);

      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString('wildcard_save_v1');
      expect(saved, isNotNull);
      expect(
        AccountState.decode(saved!).unlockedJokerIds,
        containsAll(afterFirst),
      );
    });

    test('the tutorial comeback Vault cannot award a WILD', () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      await app.mutateAccount((account) {
        account.firstLossCoached = true;
        account.tutorialChestClaimed = false;
      }, syncCloud: false);

      final reward = await app.claimTutorialComebackJoker();
      expect(reward, isNotNull);
      expect(reward!.rarity, anyOf(JokerRarity.common, JokerRarity.uncommon));
      expect(isHighImpactShopJoker(reward), isFalse);
    });

    test(
      'Gold can disclose and award its configured four-percent WILD',
      () async {
        final app = await AppController.bootstrap();
        addTearDown(app.dispose);
        await app.mutateAccount((account) {
          account.coins = 500;
        }, syncCloud: false);

        final reward = await app.openJokerVault(
          JokerChestTier.gold,
          claimId: 'test-gold-wild',
          rarityRoll: .99,
          itemRoll: 0,
        );
        expect(
          jokerChests[JokerChestTier.gold]!.effectiveOdds(
            jokerCatalog,
          )[JokerRarity.wild],
          closeTo(.04, 1e-12),
        );
        expect(reward?.rarity, JokerRarity.wild);
        expect(app.account.coins, 150);
      },
    );

    test('full Joker collection cannot be charged again', () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      await app.mutateAccount((account) {
        account.coins = 2000;
        account.unlockedJokerIds.addAll(jokerCatalog.map((joker) => joker.id));
      }, syncCloud: false);

      expect(
        await app.openJokerVault(JokerChestTier.wood, claimId: 'full-wood'),
        isNull,
      );
      expect(
        await app.openJokerVault(JokerChestTier.gold, claimId: 'full-gold'),
        isNull,
      );
      expect(app.account.coins, 2000);
      expect(app.account.unlockedJokerIds, hasLength(jokerCatalog.length));
    });

    test('Cosmetic Vault cannot mutate permanent Joker discovery', () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      await app.mutateAccount((account) {
        account.coins = 1200;
      }, syncCloud: false);
      final before = Set<String>.from(app.account.unlockedJokerIds);

      final cosmetic = await app.openCosmeticVault(
        claimId: 'test-cosmetic',
        themeRoll: 1,
        itemRoll: 0,
      );
      expect(cosmetic, isNotNull);
      expect(app.account.coins, 200);
      expect(app.account.cosmeticsOwned, contains(cosmetic!.id));
      expect(app.account.unlockedJokerIds, before);
    });
  });

  group('run-only Sly shop', () {
    test(
      'an undiscovered start boost is rejected without a coin charge',
      () async {
        final locked = jokerCatalog.firstWhere((joker) => !joker.starter);
        final mutations = <AccountMutation>[];
        final game = await GameController.startNew(
          config: GameRunConfig(
            rngSeed: 300,
            runId: 'locked-start-boost',
            unlockedJokerIds: starterJokerIds.toSet(),
            startBoostJokerId: locked.id,
            startBoostCost: 30,
          ),
          callbacks: GamePersistenceCallbacks(
            writeRun: (_, _) async {},
            clearRun: () async {},
            mutateAccount: (mutation) async {
              mutations.add(mutation);
              return true;
            },
          ),
          wait: (_) async {},
        );
        addTearDown(game.dispose);

        expect(game.state.jokerIds, isNot(contains(locked.id)));
        expect(game.startBoostJoker, isNull);
        expect(game.startBoostCost, 0);
        expect(
          mutations
              .singleWhere(
                (mutation) => mutation.kind == AccountMutationKind.runEntry,
              )
              .coinDelta,
          0,
        );
      },
    );

    test('normal and Daily shelves use only account discoveries', () async {
      final discoveries = starterJokerIds.toSet();
      for (final mode in <RunMode>[RunMode.normal, RunMode.daily]) {
        final game = await _openShop(
          seed: mode == RunMode.normal ? 301 : 302,
          mode: mode,
          discoveries: discoveries,
        );
        addTearDown(game.dispose);
        expect(game.jokerOffers, isNotEmpty);
        expect(
          game.jokerOffers.every((joker) => discoveries.contains(joker.id)),
          isTrue,
        );
      }
    });

    test(
      'a run purchase equips temporarily without account discovery',
      () async {
        final discoveries = starterJokerIds.toSet();
        final game = await _openShop(seed: 303, discoveries: discoveries);
        addTearDown(game.dispose);
        game.state.runCoins = 100;
        final offer = game.jokerOffers.first;

        expect((await game.buyJoker(offer.id)).ok, isTrue);
        expect(game.state.jokerIds, contains(offer.id));
        expect(discoveries, starterJokerIds.toSet());
      },
    );

    test('stale locked offers are rejected before purchase', () async {
      final discoveries = starterJokerIds.toSet();
      final game = await _openShop(seed: 304, discoveries: discoveries);
      addTearDown(game.dispose);
      final locked = jokerCatalog.firstWhere(
        (joker) => !discoveries.contains(joker.id),
      );
      game.state.runCoins = 100;
      game.jokerOffers
        ..clear()
        ..add(locked);

      final result = await game.buyJoker(locked.id);
      expect(result.ok, isFalse);
      expect(result.message, contains('Joker Vault'));
      expect(game.state.jokerIds, isNot(contains(locked.id)));
      expect(discoveries, isNot(contains(locked.id)));
    });

    test('WILD is absent early and capped at one from Heat 6 onward', () async {
      final all = jokerCatalog.map((joker) => joker.id).toSet();
      final early = await _openShop(
        seed: 305,
        discoveries: all,
        wildMissShops: wildPityAfterShops,
      );
      addTearDown(early.dispose);
      expect(
        early.jokerOffers.where((joker) => joker.rarity == JokerRarity.wild),
        isEmpty,
      );
      expect(early.jokerOffers.where(isHighImpactShopJoker), isEmpty);

      final mid = await _openShop(
        seed: 306,
        discoveries: all,
        heat: wildShopMinimumHeat,
        wildMissShops: wildPityAfterShops,
      );
      addTearDown(mid.dispose);
      expect(
        mid.jokerOffers.where((joker) => joker.rarity == JokerRarity.wild),
        hasLength(1),
      );
      final pityAfterNaturalShop = mid.wildMissShops;
      mid.state.runCoins = 100;
      for (var reroll = 0; reroll < 12; reroll++) {
        expect((await mid.rerollShop()).ok, isTrue);
        expect(
          mid.jokerOffers.where((joker) => joker.rarity == JokerRarity.wild),
          hasLength(lessThanOrEqualTo(1)),
        );
        expect(
          mid.wildMissShops,
          lessThanOrEqualTo(pityAfterNaturalShop),
          reason: 'rerolls may reset but must never advance WILD pity',
        );
      }
    });
  });
}

Future<GameController> _openShop({
  required int seed,
  required Set<String> discoveries,
  RunMode mode = RunMode.normal,
  int heat = 1,
  int wildMissShops = 0,
}) async {
  final game = await GameController.startNew(
    config: GameRunConfig(
      rngSeed: seed,
      runId: 'vault-test-$seed',
      mode: mode,
      dailyDate: mode == RunMode.daily ? '2026-07-28' : '',
      unlockedJokerIds: discoveries,
    ),
    callbacks: _callbacks,
    wait: (_) async {},
  );
  game.state.stage = heat;
  game.wildMissShops = wildMissShops;
  game.state.stageScore = game.target - 1;
  await game.toggleCard(game.hand.first.uid!);
  expect((await game.playSelected()).ok, isTrue);
  expect(game.phase, RunPhase.shop);
  return game;
}

final GamePersistenceCallbacks _callbacks = GamePersistenceCallbacks(
  writeRun: (_, _) async {},
  clearRun: () async {},
  mutateAccount: (_) async => true,
);

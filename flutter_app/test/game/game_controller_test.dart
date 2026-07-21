import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/legacy_save_schema.dart';
import 'package:wildcard/domain/random_streams.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  Future<void> noWait(Duration _) async {}

  test('zero-cost runs still persist a durable entry event', () async {
    final normalHarness = _Harness();
    await GameController.startNew(
      config: _config(seed: 71000, runId: 'free-normal'),
      callbacks: normalHarness.callbacks,
      wait: noWait,
    );
    final normalEntry = normalHarness.mutations.singleWhere(
      (mutation) => mutation.kind == AccountMutationKind.runEntry,
    );
    expect(normalEntry.claimId, 'free-normal:entry');
    expect(normalEntry.coinDelta, 0);

    final dailyHarness = _Harness();
    await GameController.startNew(
      config: _config(seed: 71000, runId: 'free-daily', mode: RunMode.daily),
      callbacks: dailyHarness.callbacks,
      wait: noWait,
    );
    final dailyEntry = dailyHarness.mutations.singleWhere(
      (mutation) => mutation.kind == AccountMutationKind.runEntry,
    );
    expect(dailyEntry.claimId, 'free-daily:entry');
    expect(dailyEntry.coinDelta, 0);
    expect(dailyEntry.runMode, RunMode.daily);
  });

  test('same seed deals an identical deterministic opening hand', () async {
    final first = await GameController.startNew(
      config: _config(seed: 71001, runId: 'same-a'),
      callbacks: _Harness().callbacks,
      wait: noWait,
    );
    final second = await GameController.startNew(
      config: _config(seed: 71001, runId: 'same-b'),
      callbacks: _Harness().callbacks,
      wait: noWait,
    );

    expect(
      second.hand.map((card) => '${card.uid}:${card.rank}:${card.suit}'),
      first.hand.map((card) => '${card.uid}:${card.rank}:${card.suit}'),
    );
    expect(second.state.rngCounters.toJson(), first.state.rngCounters.toJson());
  });

  test(
    'scoring checkpoints before luck and resumes the same exact play',
    () async {
      String? prepared;
      final baselineHarness = _Harness(
        onWrite: (encoded, checkpoint) {
          if (checkpoint == RunCheckpoint.scoringPrepared) prepared = encoded;
        },
      );
      final glassDeck = baseCardSet()
          .map((card) => card.copyWith(enhancement: CardEnhancement.glass))
          .toList();
      final baseline = await GameController.startNew(
        config: _config(
          seed: 424242,
          runId: 'resume-luck',
          initialDeck: glassDeck,
        ),
        callbacks: baselineHarness.callbacks,
        wait: noWait,
      );
      await baseline.toggleCard(baseline.hand.first.uid!);
      expect((await baseline.playSelected()).ok, isTrue);
      expect(prepared, isNotNull);

      final recoveredHarness = _Harness();
      final recovered = await GameController.resume(
        encoded: prepared!,
        callbacks: recoveredHarness.callbacks,
        unlockedJokerIds: jokersById.keys.toSet(),
        wait: noWait,
      );
      expect(recovered.pendingTransition?['kind'], 'play');
      expect((await recovered.recoverPendingTransition()).ok, isTrue);

      expect(recovered.totalScore, baseline.totalScore);
      expect(recovered.state.shatteredCount, baseline.state.shatteredCount);
      expect(recovered.state.cards.length, baseline.state.cards.length);
      expect(
        recovered.state.rngCounters[RandomStream.luck],
        baseline.state.rngCounters[RandomStream.luck],
      );
      expect(
        recoveredHarness.checkpoints,
        containsAllInOrder(<RunCheckpoint>[
          RunCheckpoint.scoringPrepared,
          RunCheckpoint.scoringCommitted,
        ]),
      );
    },
  );

  test('a spent discard and replacement hand are saved immediately', () async {
    final harness = _Harness();
    final game = await GameController.startNew(
      config: _config(seed: 9901),
      callbacks: harness.callbacks,
      wait: noWait,
    );
    final originalHand = game.hand.map((card) => card.uid).toList();
    await game.toggleCard(game.hand.first.uid!);

    expect((await game.discardSelected()).ok, isTrue);
    expect(game.state.discardsLeft, discardsPerHeat - 1);
    expect(game.hand.map((card) => card.uid), isNot(originalHand));
    expect(harness.checkpoints.last, RunCheckpoint.discardCommitted);
    final saved = jsonDecode(harness.writes.last) as Map<String, dynamic>;
    expect(saved['discardsLeft'], discardsPerHeat - 1);
    expect(saved['hand'], hasLength(handSize));
  });

  test('Heat clear awards once and opens a deterministic shop', () async {
    final harness = _Harness();
    final game = await GameController.startNew(
      config: _config(seed: 8080),
      callbacks: harness.callbacks,
      wait: noWait,
    );
    game.state.stageScore = game.target - 1;
    await game.toggleCard(game.hand.first.uid!);

    expect((await game.playSelected()).ok, isTrue);
    expect(game.phase, RunPhase.shop);
    expect(game.state.stagesCleared, 1);
    expect(game.jokerOffers, hasLength(2));
    expect(game.supplyOffers, hasLength(2));
    expect(
      harness.mutations.where(
        (mutation) => mutation.kind == AccountMutationKind.heatReward,
      ),
      hasLength(1),
    );
    expect(
      harness.mutations
          .singleWhere(
            (mutation) => mutation.kind == AccountMutationKind.heatReward,
          )
          .claimId,
      '${game.runId}:heat:1',
    );
  });

  test(
    'supply is once per type per shop and price rise is permanent',
    () async {
      final game = await _openFirstShop(noWait);
      game.state.runCoins = 100;
      game.supplyOffers
        ..clear()
        ..add(
          supplyCatalog.firstWhere((supply) => supply.id == SupplyId.scalpel),
        );
      final supply = game.supplyOffers.single;
      final before = game.priceForSupply(supply);
      final target = game.state.cards.first;

      expect(
        (await game.buySupply(
          SupplyId.scalpel,
          SupplySelection(cardId: target.uid),
        )).ok,
        isTrue,
      );
      expect(game.state.cards, hasLength(51));
      expect(game.supplyLedger.count(SupplyId.scalpel), 1);
      expect(game.priceForSupply(supply), before + 5);
      expect(
        (await game.buySupply(
          SupplyId.scalpel,
          SupplySelection(cardId: game.state.cards.first.uid),
        )).ok,
        isFalse,
      );
    },
  );

  test('copy cap, enhancement guard and 24-card floor are enforced', () async {
    final game = await _openFirstShop(noWait);
    game.state.runCoins = 500;
    final source = game.state.cards.first;
    game.supplyOffers
      ..clear()
      ..add(supplyCatalog.firstWhere((supply) => supply.id == SupplyId.copier));
    expect(
      (await game.buySupply(
        SupplyId.copier,
        SupplySelection(cardId: source.uid),
      )).ok,
      isTrue,
    );
    expect(
      game.state.cards
          .where((card) => card.rank == source.rank && card.suit == source.suit)
          .length,
      2,
    );
    expect(
      game.state.cards
          .where(
            (card) =>
                card.rank == source.rank &&
                card.suit == source.suit &&
                card.copied,
          )
          .single
          .enhancement,
      isNull,
    );

    game.state.cards.removeRange(24, game.state.cards.length);
    game.supplyOffers
      ..clear()
      ..add(
        supplyCatalog.firstWhere((supply) => supply.id == SupplyId.scalpel),
      );
    game.suppliesBoughtThisShop.remove(SupplyId.scalpel);
    expect(
      (await game.buySupply(
        SupplyId.scalpel,
        SupplySelection(cardId: game.state.cards.first.uid),
      )).ok,
      isFalse,
    );
    expect(game.state.cards, hasLength(24));
  });

  test(
    'Endless cadence and late modifier stack use ModifierSelector',
    () async {
      final game = await GameController.startNew(
        config: _config(seed: 12345),
        callbacks: _Harness().callbacks,
        wait: noWait,
      );
      game.state.endless = true;
      game.state.stage = 14;
      game.phase = RunPhase.shop;
      expect((await game.leaveShop()).ok, isTrue);
      expect(game.state.stage, 15);
      expect(game.state.modifiers, hasLength(1));

      game.state.stage = 50;
      game.phase = RunPhase.shop;
      expect((await game.leaveShop()).ok, isTrue);
      expect(game.state.stage, 51);
      expect(game.state.modifiers, hasLength(2));
      expect(game.state.modifiers.any((modifier) => modifier.isHard), isTrue);
    },
  );

  test('THE HOUSE blocks exactly two equipped Jokers at Heat 12', () async {
    final game = await GameController.startNew(
      config: _config(
        seed: 777,
        initialJokers: const <String>[
          'copper',
          'presser',
          'retainer',
          'even',
          'lowball',
        ],
      ),
      callbacks: _Harness().callbacks,
      wait: noWait,
    );
    game.state.stage = 11;
    game.phase = RunPhase.shop;
    expect((await game.leaveShop()).ok, isTrue);
    expect(game.state.modifiers, <HeatModifier>[HeatModifier.theHouse]);
    expect(game.state.blockedJokerIds, hasLength(2));
    expect(
      game.state.blockedJokerIds.difference(game.state.jokerIds.toSet()),
      isEmpty,
    );
  });

  test('standard victory can continue into Endless Heat 13', () async {
    final game = await GameController.startNew(
      config: _config(seed: 1977),
      callbacks: _Harness().callbacks,
      wait: noWait,
    );
    game.state.stage = 11;
    game.state.stagesCleared = 11;
    game.phase = RunPhase.shop;
    await game.leaveShop();
    game.state.stageScore = game.target - 1;
    await game.toggleCard(game.hand.first.uid!);
    await game.playSelected();

    expect(game.phase, RunPhase.victory);
    expect(game.state.stage, 12);
    expect((await game.continueEndless()).ok, isTrue);
    expect(game.phase, RunPhase.game);
    expect(game.state.stage, 13);
    expect(game.state.endless, isTrue);
    expect(game.state.modifiers, isEmpty);
  });

  test('Gauntlet ends at Heat 8 and cannot enter Endless', () async {
    final harness = _Harness();
    final game = await GameController.startNew(
      config: _config(seed: 888, mode: RunMode.gauntlet),
      callbacks: harness.callbacks,
      wait: noWait,
    );
    game.state.stage = 7;
    game.state.stagesCleared = 7;
    game.phase = RunPhase.shop;
    await game.leaveShop();
    game.state.stageScore = game.target - 1;
    await game.toggleCard(game.hand.first.uid!);
    await game.playSelected();

    expect(game.phase, RunPhase.victory);
    expect(game.state.modifiers, <HeatModifier>[HeatModifier.theHouse]);
    expect((await game.continueEndless()).ok, isFalse);
    expect((await game.bankVictory()).ok, isTrue);
    expect(game.endReason, RunEndReason.gauntletWon);
    expect(
      harness.mutations.any(
        (mutation) => mutation.claimId == '${game.runId}:completion:gauntlet',
      ),
      isTrue,
    );
  });

  test(
    'Daily is Medium, uses the date seed, and has no revive or coin awards',
    () async {
      final harness = _Harness();
      const date = '2026-07-21';
      final game = await GameController.startNew(
        config: GameRunConfig(
          rngSeed: 999999,
          runId: 'daily-test',
          mode: RunMode.daily,
          difficulty: RunDifficulty.hard,
          dailyDate: date,
        ),
        callbacks: harness.callbacks,
        wait: noWait,
      );
      expect(game.state.difficulty, RunDifficulty.medium);
      expect(game.state.rngSeed, dailySeed(date));
      game.state.handsLeft = 1;
      await game.toggleCard(game.hand.first.uid!);
      await game.playSelected();

      expect(game.phase, RunPhase.ended);
      expect(game.endReason, RunEndReason.defeated);
      expect(
        harness.mutations.where(
          (mutation) => mutation.kind == AccountMutationKind.heatReward,
        ),
        isEmpty,
      );
      final finished = harness.mutations.singleWhere(
        (mutation) => mutation.kind == AccountMutationKind.runFinished,
      );
      expect(finished.dailyDate, date);
      expect(finished.dailyScore, game.totalScore);
      expect(finished.handsPlayed, 1);
      expect(finished.handTypeCounts.values.fold<int>(0, (a, b) => a + b), 1);
      expect(finished.stagesCleared, game.state.stagesCleared);
      expect(finished.jokerIds, game.state.jokerIds);
    },
  );

  test(
    'boss-prep shop supports buy, reroll, sell and full-slot swap',
    () async {
      final harness = _Harness();
      final initial = jokerCatalog.take(5).map((joker) => joker.id).toList();
      final game = await GameController.startNew(
        config: _config(seed: 5511, initialJokers: initial),
        callbacks: harness.callbacks,
        wait: noWait,
      );
      game.phase = RunPhase.shop;
      game.state.stage = 11;
      game.state.runCoins = 100;
      final offer = jokerCatalog.firstWhere(
        (joker) => !game.state.jokerIds.contains(joker.id),
      );
      game.jokerOffers
        ..clear()
        ..add(offer);
      final old = jokersById[game.state.jokerIds.first]!;
      final expectedCoins = 100 + game.sellValue(old) - offer.price;

      expect((await game.buyJoker(offer.id, swapIndex: 0)).ok, isTrue);
      expect(game.state.jokerIds.first, offer.id);
      expect(game.state.runCoins, expectedCoins);
      expect(game.canReroll, isTrue, reason: 'boss prep permits a second buy');
      expect((await game.rerollShop()).ok, isTrue);
      expect(game.state.runCoins, expectedCoins - shopRerollCost);
      final sold = jokersById[game.state.jokerIds.last]!;
      final beforeSell = game.state.runCoins;
      expect((await game.sellJoker(game.state.jokerIds.length - 1)).ok, isTrue);
      expect(game.state.runCoins, beforeSell + game.sellValue(sold));
    },
  );

  test('supplies bought after Heat 20 add ten to every future price', () async {
    final game = await _openFirstShop(noWait);
    game.state.stage = 21;
    game.state.runCoins = 100;
    final supply = supplyCatalog.firstWhere(
      (candidate) => candidate.id == SupplyId.scalpel,
    );
    game.supplyOffers
      ..clear()
      ..add(supply);
    final before = game.priceForSupply(supply);
    expect(
      (await game.buySupply(
        SupplyId.scalpel,
        SupplySelection(cardId: game.state.cards.first.uid),
      )).ok,
      isTrue,
    );
    expect(game.supplyLedger.entries.last.step, 10);
    expect(game.priceForSupply(supply), before + 10);
  });

  test(
    'Gauntlet stake settlement applies its second loss exactly once',
    () async {
      final harness = _Harness();
      final game = await GameController.startNew(
        config: _config(seed: 9191, mode: RunMode.gauntlet, stake: 100),
        callbacks: harness.callbacks,
        wait: noWait,
      );
      expect((await game.abandon()).ok, isTrue);
      final entry = harness.mutations.singleWhere(
        (mutation) => mutation.kind == AccountMutationKind.runEntry,
      );
      final settlement = harness.mutations.singleWhere(
        (mutation) => mutation.kind == AccountMutationKind.stakeSettlement,
      );
      expect(entry.coinDelta, -100);
      expect(settlement.coinDelta, -100);
      expect(game.stakeNet, -200);
    },
  );

  test(
    'failed standard Heat offers one revive and marks rankings local',
    () async {
      final harness = _Harness();
      final game = await GameController.startNew(
        config: _config(seed: 2020),
        callbacks: harness.callbacks,
        wait: noWait,
      );
      game.state.handsLeft = 1;
      await game.toggleCard(game.hand.first.uid!);
      await game.playSelected();

      expect(game.phase, RunPhase.revive);
      expect(game.terminalPending, isTrue);
      expect((await game.acceptRevive()).ok, isTrue);
      expect(game.phase, RunPhase.game);
      expect(game.state.handsLeft, 1);
      expect(game.reviveUsed, isTrue);
      expect(game.leaderboardEligible, isFalse);
      game.glassDouble = true;
      expect((await game.abandon()).ok, isTrue);
      final finished = harness.mutations.singleWhere(
        (mutation) => mutation.kind == AccountMutationKind.runFinished,
      );
      expect(finished.leaderboardEligible, isFalse);
      expect(
        finished.enhancedCount,
        game.state.cards.where((card) => card.enhancement != null).length,
      );
      expect(finished.glassDouble, isTrue);
    },
  );

  test(
    'legacy save roundtrip keeps unknown fields and active shelves',
    () async {
      final game = await _openFirstShop(noWait);
      final raw = game.toLegacyJson()
        ..['futureServerField'] = <String, int>{'x': 7};
      final resumed = await GameController.resume(
        encoded: jsonEncode(raw),
        callbacks: _Harness().callbacks,
        unlockedJokerIds: jokersById.keys.toSet(),
        wait: noWait,
      );

      expect(resumed.phase, RunPhase.shop);
      expect(resumed.toLegacyJson()['futureServerField'], <String, int>{
        'x': 7,
      });
      expect(
        resumed.jokerOffers.map((joker) => joker.id),
        game.jokerOffers.map((joker) => joker.id),
      );
      expect(
        resumed.supplyOffers.map((supply) => supply.id),
        game.supplyOffers.map((supply) => supply.id),
      );
    },
  );

  test('new Flutter saves populate every v7.1 legacy run field', () async {
    final game = await GameController.startNew(
      config: _config(seed: 71045),
      callbacks: _Harness().callbacks,
      wait: noWait,
    );
    expect(
      legacyRunSaveFields.difference(game.toLegacyJson().keys.toSet()),
      isEmpty,
    );
  });

  test('normal pacing remains human-readable and fast remains sequenced', () {
    expect(
      ScoringPacing.normal.jokerBeat,
      greaterThan(ScoringPacing.fast.jokerBeat),
    );
    expect(
      ScoringPacing.normal.jokerBeat,
      greaterThanOrEqualTo(const Duration(milliseconds: 450)),
    );
    expect(ScoringPacing.fast.cardBeat, isNot(Duration.zero));
  });
}

GameRunConfig _config({
  int seed = 1,
  String? runId,
  List<PlayingCard>? initialDeck,
  List<String> initialJokers = const <String>[],
  RunMode mode = RunMode.normal,
  int stake = 0,
}) => GameRunConfig(
  rngSeed: seed,
  runId: runId ?? 'test-$seed',
  mode: mode,
  unlockedJokerIds: jokersById.keys.toSet(),
  initialDeck: initialDeck,
  initialJokerIds: initialJokers,
  stake: stake,
);

Future<GameController> _openFirstShop(ScoringWait wait) async {
  final game = await GameController.startNew(
    config: _config(seed: 31337),
    callbacks: _Harness().callbacks,
    wait: wait,
  );
  game.state.stageScore = game.target - 1;
  await game.toggleCard(game.hand.first.uid!);
  await game.playSelected();
  expect(game.phase, RunPhase.shop);
  return game;
}

class _Harness {
  _Harness({this.onWrite});

  final void Function(String encoded, RunCheckpoint checkpoint)? onWrite;
  final List<String> writes = <String>[];
  final List<RunCheckpoint> checkpoints = <RunCheckpoint>[];
  final List<AccountMutation> mutations = <AccountMutation>[];
  var clears = 0;

  late final GamePersistenceCallbacks callbacks = GamePersistenceCallbacks(
    writeRun: (encoded, checkpoint) async {
      writes.add(encoded);
      checkpoints.add(checkpoint);
      onWrite?.call(encoded, checkpoint);
    },
    clearRun: () async {
      clears++;
    },
    mutateAccount: (mutation) async {
      mutations.add(mutation);
      return true;
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

Future<void> _noWait(Duration _) async {}

void main() {
  test('clear rewards match the measured schedule and bound Endless', () {
    expect(
      [for (var heat = 1; heat <= 12; heat++) astraAccountReward(heat)],
      [4, 4, 4, 7, 7, 7, 10, 10, 10, 13, 13, 13],
    );
    expect(astraAccountReward(0), 0);
    expect(astraAccountReward(-5), 0);
    for (final heat in [13, 24, 50, 100, 10000]) {
      expect(astraAccountReward(heat), 13);
    }
    expect(modeAccountReward(RunMode.daily, 12), 0);
    expect(modeCompletionBonus(RunMode.daily), 0);
    expect(jokerChests[JokerChestTier.wood]!.price(14), 60);
    expect(jokerChests[JokerChestTier.wood]!.price(15), 100);
    expect(jokerChests[JokerChestTier.gold]!.price(15), 300);
    expect(maximumStake(10000), 0);
  });

  test('optional ad bonus never exceeds earned coins or 25 per placement', () {
    expect(astraRunAdBonus(-1), 0);
    expect(astraRunAdBonus(0), 0);
    expect(astraRunAdBonus(4), 4);
    expect(astraRunAdBonus(25), 25);
    expect(astraRunAdBonus(63), 25);
    expect(astraRunAdBonus(122), 25);
    expect(astraRunAdBonus(9999999), 25);
  });

  for (final difficulty in RunDifficulty.values) {
    test(
      'Normal ${difficulty.name} banks 122 once across save and Endless',
      () async {
        final ledger = _RewardLedger();
        var game = await _start(ledger, difficulty: difficulty);
        for (var heat = 1; heat <= 12; heat++) {
          await _clear(game);
          if (heat < 12) await game.leaveShop();
        }
        expect(game.phase, RunPhase.victory);
        expect(ledger.coins, 122);
        expect(game.accountEarned, 122);
        final saved = game.encodeLegacySave();
        game.dispose();
        game = await GameController.resume(
          encoded: saved,
          callbacks: ledger.callbacks,
          unlockedJokerIds: starterJokerIds.toSet(),
          wait: _noWait,
        );
        addTearDown(game.dispose);
        expect(game.accountEarned, 122);
        expect((await game.continueEndless()).ok, isTrue);
        expect((await game.continueEndless()).ok, isFalse);
        await _clear(game);
        expect(ledger.coins, 135);
        expect(game.accountEarned, 135);
        expect((await game.abandon()).ok, isTrue);
        expect(ledger.coins, 135);
        expect(
          ledger.applied.where(
            (m) => m.kind == AccountMutationKind.completionReward,
          ),
          hasLength(1),
        );
      },
    );
  }

  test('Gauntlet pays 63 through eight clears and banks only once', () async {
    final ledger = _RewardLedger();
    final game = await _start(ledger, mode: RunMode.gauntlet);
    addTearDown(game.dispose);
    for (var heat = 1; heat <= 8; heat++) {
      await _clear(game);
      if (heat < 8) await game.leaveShop();
    }
    expect(game.phase, RunPhase.victory);
    expect(ledger.coins, 63);
    expect(game.accountEarned, 63);
    expect((await game.bankVictory()).ok, isTrue);
    expect((await game.bankVictory()).ok, isFalse);
    expect(ledger.coins, 63);
    expect((await game.continueEndless()).ok, isFalse);
  });

  test('Daily full clear has no direct repeatable coin payout', () async {
    final ledger = _RewardLedger();
    final game = await _start(ledger, mode: RunMode.daily);
    addTearDown(game.dispose);
    for (var heat = 1; heat <= 12; heat++) {
      await _clear(game);
      if (heat < 12) await game.leaveShop();
    }
    expect(game.phase, RunPhase.victory);
    expect((await game.bankVictory()).ok, isTrue);
    expect(ledger.coins, 0);
    expect(game.accountEarned, 0);
    expect(
      ledger.applied.where(
        (m) =>
            m.kind == AccountMutationKind.heatReward ||
            m.kind == AccountMutationKind.completionReward,
      ),
      isEmpty,
    );
  });

  test('new wagers are disabled but legacy saved stake is honored', () async {
    final ledger = _RewardLedger();
    final fresh = await _start(ledger, stake: 100);
    expect(fresh.stake, 0);
    expect(ledger.coins, 0);
    final raw = jsonDecode(fresh.encodeLegacySave()) as Map<String, dynamic>;
    fresh.dispose();
    // Existing installs have already paid this 100-coin entry; importing the
    // checkpoint must preserve what the old contract still owes the player.
    raw['stake'] = 100;
    raw['stagesCleared'] = 6;
    final restored = await GameController.resume(
      encoded: jsonEncode(raw),
      callbacks: ledger.callbacks,
      unlockedJokerIds: starterJokerIds.toSet(),
      wait: _noWait,
    );
    addTearDown(restored.dispose);
    expect(restored.stake, 100);
    expect((await restored.abandon()).ok, isTrue);
    expect(ledger.coins, stakePayout(100, 6));
    expect(
      ledger.applied.where(
        (m) => m.kind == AccountMutationKind.stakeSettlement,
      ),
      hasLength(1),
    );
  });
}

Future<GameController> _start(
  _RewardLedger ledger, {
  RunMode mode = RunMode.normal,
  RunDifficulty difficulty = RunDifficulty.medium,
  int stake = 0,
}) => GameController.startNew(
  config: GameRunConfig(
    rngSeed: 98317,
    mode: mode,
    difficulty: difficulty,
    dailyDate: '2026-09-08',
    stake: stake,
    unlockedJokerIds: starterJokerIds.toSet(),
  ),
  callbacks: ledger.callbacks,
  wait: _noWait,
);

Future<void> _clear(GameController game) async {
  // Exercise the real clear/credit/checkpoint lifecycle without making this
  // reward test depend on bot quality or a particular randomized modifier.
  game.state.modifiers.clear();
  game.state.blockedJokerIds.clear();
  game.state.stageScore = game.target - 1;
  await game.toggleCard(game.hand.first.uid!);
  expect((await game.playSelected()).ok, isTrue);
}

class _RewardLedger {
  int coins = 0;
  final applied = <AccountMutation>[];
  final claims = <String>{};
  late final callbacks = GamePersistenceCallbacks(
    writeRun: (_, _) async {},
    clearRun: () async {},
    mutateAccount: (mutation) async {
      if (claims.add(mutation.claimId)) {
        coins += mutation.coinDelta;
        applied.add(mutation);
      }
      return true;
    },
  );
}

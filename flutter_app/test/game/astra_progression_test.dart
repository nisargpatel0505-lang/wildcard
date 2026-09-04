import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/random_streams.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

Future<void> _noWait(Duration _) async {}

void main() {
  test(
    'Astra defeat ends cleanly without an unavailable ad revive',
    () async {
      final game = await _start();
      addTearDown(game.dispose);
      game.state.handsLeft = 1;
      await game.toggleCard(game.hand.first.uid!);
      await game.playSelected();
      expect(game.phase, RunPhase.ended);
      expect(game.reviveUsed, isFalse);
    },
    skip: !astraEnabled,
  );
  test(
    'draft has three distinct hand engines and zero account progression',
    () {
      for (var seed = 0; seed < 30; seed++) {
        final choices = astraStarterChoices(seed);
        expect(choices.map((joker) => joker.id).toSet(), <String>{
          'polish',
          'flushfund',
          'wire',
        });
        expect(
          choices.any((joker) => joker.effect == JokerEffect.devTwentyX),
          false,
        );
      }
      expect(astraAccountReward(0), 0);
      expect(
        List.generate(
          3,
          (i) => astraAccountReward(i + 1),
        ).reduce((a, b) => a + b),
        26,
      );
      expect(
        List.generate(
          12,
          (i) => astraAccountReward(i + 1),
        ).reduce((a, b) => a + b),
        104,
      );
      expect(astraWoodVaultPrice(14), 60);
      expect(astraWoodVaultPrice(15), 100);
      expect(astraGoldVaultPrice, 300);
    },
  );

  group(
    'compiled Astra experiment',
    () {
      test(
        'borrowed starter is free and does not alter the opening deal',
        () async {
          final mutations = <AccountMutation>[];
          final callbacks = GamePersistenceCallbacks(
            writeRun: (_, _) async {},
            clearRun: () async {},
            mutateAccount: (mutation) async {
              mutations.add(mutation);
              return true;
            },
          );
          final runs = <GameController>[];
          for (final id in astraStarterJokerIds) {
            runs.add(
              await GameController.startNew(
                config: GameRunConfig(
                  rngSeed: 9931,
                  startBoostJokerId: id,
                  startBoostCost: 999,
                  stake: 200,
                ),
                callbacks: callbacks,
                wait: _noWait,
              ),
            );
          }
          addTearDown(() {
            for (final run in runs) {
              run.dispose();
            }
          });
          expect(mutations.every((mutation) => mutation.coinDelta == 0), true);
          for (var i = 0; i < runs.length; i++) {
            expect(runs[i].state.jokerIds, <String>[astraStarterJokerIds[i]]);
            expect(runs[i].unlockedJokerIds, isEmpty);
            expect(
              runs[i].hand.map((card) => card.toJson()),
              runs.first.hand.map((card) => card.toJson()),
            );
            expect(
              runs[i].state.rngCounters.toJson(),
              runs.first.state.rngCounters.toJson(),
            );
          }
          expect(maximumStake(100000), 0);
        },
      );

      test(
        'free reroll persists and renews only in the next opening shop',
        () async {
          final game = await _start();
          addTearDown(game.dispose);
          await _clear(game);
          expect(game.jokerOffers, hasLength(3));
          expect(game.lastHeatReward!.accountCoins, 8);
          expect(game.lastHeatReward!.runCoins, 6);
          final coins = game.state.runCoins;
          final drawCounter = game.state.rngCounters[RandomStream.deck];
          expect(game.currentRerollCost, 0);
          expect((await game.rerollShop()).ok, true);
          expect(game.state.runCoins, coins);
          expect(game.currentRerollCost, shopRerollCost);
          final resumed = await GameController.resume(
            encoded: game.encodeLegacySave(),
            callbacks: GamePersistenceCallbacks.memoryOnly(),
            unlockedJokerIds: starterJokerIds.toSet(),
            wait: _noWait,
          );
          addTearDown(resumed.dispose);
          expect(
            resumed.jokerOffers.map((joker) => joker.id),
            game.jokerOffers.map((joker) => joker.id),
          );
          expect(resumed.currentRerollCost, shopRerollCost);
          expect(resumed.state.rngCounters[RandomStream.deck], drawCounter);
          expect((await resumed.rerollShop()).ok, true);
          expect(resumed.state.runCoins, coins - shopRerollCost);
          await resumed.leaveShop();
          await _clear(resumed);
          expect(resumed.state.stage, 2);
          expect(resumed.currentRerollCost, 0);
          await resumed.leaveShop();
          await _clear(resumed);
          await resumed.leaveShop();
          await _clear(resumed);
          expect(resumed.state.stage, 4);
          expect(resumed.currentRerollCost, shopRerollCost);
        },
      );

      test(
        'Daily keeps its original rewards, offers and paid rerolls',
        () async {
          final daily = await _start(mode: RunMode.daily);
          addTearDown(daily.dispose);
          await _clear(daily);
          expect(daily.jokerOffers, hasLength(2));
          expect(daily.currentRerollCost, shopRerollCost);
          expect(daily.lastHeatReward!.accountCoins, 0);
          expect(daily.lastHeatReward!.runCoins, runReward(1));
          expect(
            daily.toLegacyJson().containsKey('astraFreeRerollUsedAtHeat'),
            false,
          );
        },
      );
    },
    skip: !astraEnabled
        ? 'Run with --dart-define=WILDCARD_ASTRA_BUILD=true'
        : false,
  );
}

Future<GameController> _start({RunMode mode = RunMode.normal}) =>
    GameController.startNew(
      config: GameRunConfig(
        rngSeed: 98317,
        mode: mode,
        dailyDate: '2026-09-04',
        unlockedJokerIds: starterJokerIds.toSet(),
      ),
      callbacks: GamePersistenceCallbacks.memoryOnly(),
      wait: _noWait,
    );

Future<void> _clear(GameController game) async {
  game.state.stageScore = game.target - 1;
  await game.toggleCard(game.hand.first.uid!);
  expect((await game.playSelected()).ok, true);
  expect(game.phase, RunPhase.shop);
}

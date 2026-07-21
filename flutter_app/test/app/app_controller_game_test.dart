import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/daily_utc_date.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'WILDCARD',
      packageName: 'com.nisarg.wildcard',
      version: '8.0.0-dev.1',
      buildNumber: '46',
      buildSignature: 'test',
      installerStore: null,
    );
  });

  test('run mutations are idempotent and update durable progression', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    await app.mutateAccount((account) {
      account.coins = 500;
      account.tutorialDone = true;
    }, syncCloud: false);
    final callbacks = app.gamePersistenceCallbacks();

    const entry = AccountMutation(
      claimId: 'run-1:entry',
      kind: AccountMutationKind.runEntry,
      coinDelta: -30,
      runMode: RunMode.normal,
    );
    expect(await callbacks.mutateAccount(entry), isTrue);
    expect(await callbacks.mutateAccount(entry), isTrue);
    expect(app.account.coins, 470);

    const finished = AccountMutation(
      claimId: 'run-1:finished',
      kind: AccountMutationKind.runFinished,
      bestHeat: 13,
      bestClearedHeat: 12,
      bestScore: 6400,
      runMode: RunMode.normal,
      won: true,
      handsPlayed: 27,
      handTypeCounts: <HandType, int>{
        HandType.highCard: 10,
        HandType.pair: 12,
        HandType.flush: 3,
        HandType.fullHouse: 2,
      },
      bestPlay: 1700,
      stagesCleared: 12,
      jokerIds: <String>['copper', 'polish'],
      modifiersSurvived: <String>['Cold Deck', 'THE HOUSE'],
      destroyedCount: 5,
      copiedCount: 3,
      boostsBought: 3,
      enhancedCount: 2,
      glassDouble: true,
    );
    expect(await callbacks.mutateAccount(finished), isTrue);
    expect(await callbacks.mutateAccount(finished), isTrue);

    expect(app.account.stats.runs, 1);
    expect(app.account.stats.wins, 1);
    expect(app.account.stats.hands, 27);
    expect(app.account.bestHeat, 13);
    expect(app.account.bestClearedHeat, 12);
    expect(app.account.bestScore, 6400);
    expect(app.account.topRuns.single.score, 6400);
    expect(app.account.missionStats['hands'], 27);
    expect(app.account.missionStats['flush'], 3);
    expect(app.account.missionStats['bighand'], 2);
    expect(app.account.achievements['first_win'], isNotNull);
    expect(app.account.achievements['glasswork'], isNotNull);
    expect(
      app.account.rewardClaims.where((id) => id == 'run-1:finished'),
      hasLength(1),
    );
  });

  test(
    'Daily launch consumes one resumable attempt without normal stats',
    () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      final callbacks = app.gamePersistenceCallbacks(dailyDate: '2026-07-21');

      const first = AccountMutation(
        claimId: 'daily-a:entry',
        kind: AccountMutationKind.runEntry,
        runMode: RunMode.daily,
      );
      const retry = AccountMutation(
        claimId: 'daily-b:entry',
        kind: AccountMutationKind.runEntry,
        runMode: RunMode.daily,
      );
      expect(await callbacks.mutateAccount(first), isTrue);
      expect(app.account.dailyRunDate, '2026-07-21');
      expect(app.account.unknownFields[dailyRunDateUtcMarkerKey], isTrue);
      expect(await callbacks.mutateAccount(retry), isFalse);

      expect(
        await callbacks.mutateAccount(
          const AccountMutation(
            claimId: 'daily-a:finished',
            kind: AccountMutationKind.runFinished,
            runMode: RunMode.daily,
            dailyDate: '2026-07-21',
            dailyScore: 1234,
            handsPlayed: 8,
            handTypeCounts: <HandType, int>{HandType.royalFlush: 1},
            bestPlay: 999999,
            stagesCleared: 12,
            jokerIds: <String>[
              'copper',
              'polish',
              'allin',
              'modded',
              'shortcut',
            ],
            destroyedCount: 20,
            copiedCount: 20,
            boostsBought: 10,
            enhancedCount: 20,
            glassDouble: true,
          ),
        ),
        isTrue,
      );
      expect(app.account.dailyBest.score, 1234);
      expect(app.account.stats.runs, 0);
      expect(app.account.bestScore, 0);
      expect(app.account.achievements.keys, contains('daily_debut'));
      expect(app.account.achievements.keys, isNot(contains('straight_flush')));
      expect(app.account.achievements.keys, isNot(contains('glasswork')));
    },
  );

  test('a completed Standard run remains a win after Endless defeat', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    final callbacks = app.gamePersistenceCallbacks();

    expect(
      await callbacks.mutateAccount(
        const AccountMutation(
          claimId: 'endless-loss:finished',
          kind: AccountMutationKind.runFinished,
          runMode: RunMode.normal,
          won: false,
          bestHeat: 20,
          bestClearedHeat: 19,
          bestScore: 58652,
          stagesCleared: 19,
        ),
      ),
      isTrue,
    );

    expect(app.account.stats.runs, 1);
    expect(app.account.stats.wins, 1);
    expect(app.account.runLog.single.won, isTrue);
    expect(app.account.missionStats['wins'], 1);
  });

  test('run coin double is durable and idempotent', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    await app.mutateAccount((account) {
      account.coins = 100;
      account.noAds = true;
    }, syncCloud: false);

    expect(
      await app.claimRunCoinDouble(
        runId: 'double-test-123456',
        baseCoins: 75,
        mode: RunMode.normal,
      ),
      isTrue,
    );
    expect(
      await app.claimRunCoinDouble(
        runId: 'double-test-123456',
        baseCoins: 75,
        mode: RunMode.normal,
      ),
      isTrue,
    );

    expect(app.account.coins, 175);
    expect(app.account.adViews, 1);
    expect(
      app.account.rewardClaims.where(
        (claim) => claim == 'double-test-123456:double',
      ),
      hasLength(1),
    );
  });

  test('scoring checkpoints defer cloud work but remain locally durable', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    final callbacks = app.gamePersistenceCallbacks();

    const prepared =
        '{"v":1,"_savedAt":100,"phase":"game","hand":[],"pendingTransition":{"kind":"play"}}';
    await callbacks.writeRun(prepared, RunCheckpoint.scoringPrepared);

    expect(app.cloudWritesDeferredForScoring, isTrue);
    expect(app.activeRunJson, prepared);

    const committed =
        '{"v":1,"_savedAt":101,"phase":"game","hand":[],"pendingTransition":null}';
    await callbacks.writeRun(committed, RunCheckpoint.scoringCommitted);

    expect(app.cloudWritesDeferredForScoring, isFalse);
    expect(app.activeRunJson, committed);
  });
}

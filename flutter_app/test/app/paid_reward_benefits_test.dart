import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/services/ad_service.dart';

Future<AppController> _app({
  bool paid = true,
  bool privacyAccepted = true,
  AdService? ads,
}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.legacyAccountKey: AccountState(
      coins: 100,
      noAds: paid,
      tutorialDone: true,
      starterGiftClaimed: true,
      musicOn: false,
      muted: true,
    ).encode(),
    AppConstants.migrationMarkerKey: true,
  });
  final app = await AppController.bootstrap(adService: ads);
  // Supply the durable acceptance marker without starting external SDKs in
  // these controller tests. Ad completion is a local fake, never a real ad.
  if (privacyAccepted) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.privacyAcceptedKey,
      jsonEncode({
        'version': AppConstants.privacyPolicyVersion,
        'acceptedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'paid bonuses need no ad fill, SDK or ad consent and share five slots',
    () async {
      var presentations = 0;
      final ads = AdService(
        rewardedPresenter: () async {
          presentations++;
          return null;
        },
      );
      final app = await _app(ads: ads);
      addTearDown(app.dispose);
      expect(ads.ready, isFalse);
      expect(app.instantRewardBonuses, isTrue);
      expect(await app.claimRewardedCoins(), isTrue);
      expect(app.account.coins, 125);

      final beforeRefresh = app.account.coins;
      expect(await app.refreshWeeklyMissionsWithRewardedAd(), isTrue);
      expect(app.account.coins, beforeRefresh);
      expect(await app.refreshWeeklyMissionsWithRewardedAd(), isFalse);
      expect(app.account.adViews, 2);

      expect(
        await app.claimRunCoinDouble(
          runId: 'paid-run',
          baseCoins: 75,
          mode: RunMode.normal,
        ),
        isTrue,
      );
      expect(app.account.coins, 125 + astraRunAdBonus(75));
      expect(
        await app.claimRewardedRevive(
          runId: 'paid-revive',
          mode: RunMode.normal,
        ),
        isTrue,
      );
      expect(app.account.adViews, 4);
      expect(await app.claimRewardedCoins(), isTrue);
      final paidBalance = app.account.coins;
      expect(app.rewardedViewsLeftToday, 0);
      expect(app.canClaimRewardedRevive('paid-revive'), isTrue);
      expect(app.canClaimRewardedRevive('another-revive'), isFalse);
      expect(await app.claimRewardedCoins(), isFalse);
      expect(
        await app.claimRewardedRevive(
          runId: 'another-revive',
          mode: RunMode.normal,
        ),
        isFalse,
      );
      expect(app.account.coins, paidBalance);
      expect(presentations, 0);

      // Repeating an already delivered run reward does not consume a slot.
      expect(
        await app.claimRunCoinDouble(
          runId: 'paid-run',
          baseCoins: 75,
          mode: RunMode.normal,
        ),
        isTrue,
      );
      expect(
        await app.claimRewardedRevive(
          runId: 'paid-revive',
          mode: RunMode.normal,
        ),
        isTrue,
      );
      expect(app.account.adViews, 5);
      expect(app.account.coins, paidBalance);
      final prefs = await SharedPreferences.getInstance();
      final saved = AccountState.decode(
        prefs.getString(AppConstants.legacyAccountKey)!,
      );
      expect(saved.adViews, 5);
      expect(
        saved.rewardClaims,
        containsAll(['paid-run:double', 'paid-revive:revive']),
      );
      expect(saved.noAds, isTrue);
    },
  );

  test('paid benefit cannot bypass first-launch privacy acceptance', () async {
    final app = await _app(privacyAccepted: false);
    addTearDown(app.dispose);
    expect(await app.claimRewardedCoins(), isFalse);
    expect(await app.refreshWeeklyMissionsWithRewardedAd(), isFalse);
    expect(app.account.coins, 100);
    expect(app.account.adViews, 0);
  });

  test('unpaid and revoked accounts require completed rewarded ads', () async {
    var presentations = 0;
    RewardItem? completion;
    final app = await _app(
      ads: AdService(
        rewardedPresenter: () async {
          presentations++;
          return completion;
        },
      ),
    );
    addTearDown(app.dispose);
    // This is the state applied by authoritative entitlement restoration.
    await app.mutateAccount(
      (account) => account.noAds = false,
      syncCloud: false,
    );
    expect(app.instantRewardBonuses, isFalse);
    expect(await app.claimRewardedCoins(), isFalse);
    expect(app.account.adViews, 0);
    completion = RewardItem(1, 'test-completion');
    expect(await app.claimRewardedCoins(), isTrue);
    expect(app.account.coins, 125);
    expect(app.account.adViews, 1);
    expect(presentations, 2);
  });

  test(
    'owner ad suppression does not grant instant bonuses, even if paid',
    () async {
      for (final paid in [false, true]) {
        final app = await _app(paid: paid, ads: AdService(ownerNoAds: true));
        expect(app.instantRewardBonuses, isFalse);
        expect(app.rewardedViewsLeftToday, 0);
        expect(await app.claimRewardedCoins(), isFalse);
        expect(
          await app.claimRewardedRevive(
            runId: 'owner-revive',
            mode: RunMode.normal,
          ),
          isFalse,
        );
        expect(app.account.coins, 100);
        expect(app.account.noAds, paid);
        app.dispose();
      }
    },
  );

  test(
    'simultaneous duplicate paid run claims consume one slot and one grant',
    () async {
      final app = await _app();
      addTearDown(app.dispose);
      await Future.wait([
        app.claimRunCoinDouble(
          runId: 'same',
          baseCoins: 60,
          mode: RunMode.normal,
        ),
        app.claimRunCoinDouble(
          runId: 'same',
          baseCoins: 60,
          mode: RunMode.normal,
        ),
      ]);
      expect(app.account.adViews, 1);
      expect(app.account.coins, 100 + astraRunAdBonus(60));
      expect(
        app.account.rewardClaims.where((id) => id == 'same:double').length,
        1,
      );
    },
  );

  test('unpaid in-flight placement cannot open another ad', () async {
    final completion = Completer<RewardItem?>();
    var presentations = 0;
    final app = await _app(
      paid: false,
      ads: AdService(
        rewardedPresenter: () {
          presentations++;
          return completion.future;
        },
      ),
    );
    addTearDown(app.dispose);
    final pending = app.claimRewardedCoins();
    expect(await app.claimRewardedCoins(), isFalse);
    completion.complete(RewardItem(1, 'test-completion'));
    expect(await pending, isTrue);
    expect(presentations, 1);
    expect(app.account.adViews, 1);
    expect(app.account.coins, 125);
  });

  test('paid Daily mode still cannot receive a run bonus or revive', () async {
    final app = await _app();
    addTearDown(app.dispose);
    expect(
      await app.claimRunCoinDouble(
        runId: 'daily',
        baseCoins: 75,
        mode: RunMode.daily,
      ),
      isFalse,
    );
    expect(
      await app.claimRewardedRevive(runId: 'daily', mode: RunMode.daily),
      isFalse,
    );
    expect(app.account.adViews, 0);
  });

  test(
    'account replaced while rewarded ad is open cannot receive its reward',
    () async {
      final completion = Completer<RewardItem?>();
      final app = await _app(
        paid: false,
        ads: AdService(rewardedPresenter: () => completion.future),
      );
      addTearDown(app.dispose);
      final oldAccount = app.account;
      final pending = app.claimRewardedCoins();
      app.account = AccountState(coins: 500, noAds: false);
      completion.complete(RewardItem(1, 'test-completion'));
      expect(await pending, isFalse);
      expect(app.account.coins, 500);
      expect(app.account.adViews, 0);
      expect(oldAccount.coins, 100);
      expect(oldAccount.adViews, 0);
    },
  );
}

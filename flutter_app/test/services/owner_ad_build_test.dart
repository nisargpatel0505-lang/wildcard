import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/build_options.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/services/ad_service.dart';
import 'package:wildcard/services/forced_ad_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default build follows the explicit owner-only compile flag', () {
    final ads = AdService();
    addTearDown(ads.dispose);
    expect(ads.ownerNoAds, ownerPhoneNoAdsBuild);
    expect(ads.adsEnabled, !ownerPhoneNoAdsBuild);
  });

  test('owner override blocks all SDK and presenter entry points', () async {
    const channel = MethodChannel('plugins.flutter.io/google_mobile_ads');
    var sdkCalls = 0;
    var presenterCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          sdkCalls++;
          throw StateError('The owner build must never call the ad SDK.');
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final ads = AdService(
      ownerNoAds: true,
      rewardedPresenter: () async {
        presenterCalls++;
        return RewardItem(1, 'coin');
      },
      interstitialPresenter: () async {
        presenterCalls++;
        return true;
      },
    );
    addTearDown(ads.dispose);

    expect(await ads.initializeAfterPrivacyAcceptance(), isFalse);
    await ads.showPrivacyOptions();
    expect(await ads.showRewarded(), isNull);
    expect(await ads.showInterstitial(), isFalse);
    expect(
      await ads.showTerminalInterstitial(
        const TerminalInterstitialContext(
          runId: 'owner-finish',
          handsPlayed: 12,
          stagesCleared: 3,
        ),
      ),
      isFalse,
    );
    ads.setForcedAdsRemoved(false);
    expect(ads.ready, isFalse);
    expect(ads.rewardedReady, isFalse);
    expect(ads.interstitialReady, isFalse);
    expect(ads.privacyOptionsRequired, isFalse);
    expect(sdkCalls, 0);
    expect(presenterCalls, 0);
    expect(ads.forcedInterstitialPolicy.lastShownAt, isNull);
  });

  test(
    'public build keeps optional rewards after paid forced-ad removal',
    () async {
      var rewardedCalls = 0;
      var forcedCalls = 0;
      final ads = AdService(
        ownerNoAds: false,
        rewardedPresenter: () async {
          rewardedCalls++;
          return RewardItem(1, 'coin');
        },
        interstitialPresenter: () async {
          forcedCalls++;
          return true;
        },
      );
      addTearDown(ads.dispose);
      expect(ads.adsEnabled, isTrue);
      expect(await ads.showInterstitial(), isTrue);
      ads.setForcedAdsRemoved(true);
      expect(await ads.showInterstitial(), isFalse);
      expect(await ads.showRewarded(), isNotNull);
      expect(forcedCalls, 1);
      expect(rewardedCalls, 1);
    },
  );

  test('switch cannot manufacture or remove a purchased entitlement', () {
    final unpaid = AccountState(noAds: false);
    final paid = AccountState(noAds: true);
    expect(
      effectiveNoAdsFor(unpaid, profileBuild: false, ownerNoAds: true),
      isTrue,
    );
    expect(
      effectiveNoAdsFor(unpaid, profileBuild: false, ownerNoAds: false),
      isFalse,
    );
    expect(
      effectiveNoAdsFor(paid, profileBuild: false, ownerNoAds: true),
      isTrue,
    );
    expect(
      effectiveNoAdsFor(paid, profileBuild: false, ownerNoAds: false),
      isTrue,
    );
    expect(unpaid.noAds, isFalse);
    expect(paid.noAds, isTrue);
  });

  test('compiled phone override grants no fake rewards or claims', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    final before = app.account.encode();
    if (ownerPhoneNoAdsBuild) {
      expect(app.rewardedViewsLeftToday, 0);
      expect(app.effectiveNoAds, isTrue);
      expect(await app.claimRewardedCoins(), isFalse);
      expect(await app.ads.initializeAfterPrivacyAcceptance(), isFalse);
      expect(app.account.encode(), before);
    } else {
      expect(app.rewardedViewsLeftToday, 5);
      expect(app.effectiveNoAds, isFalse);
    }
    expect(app.account.noAds, isFalse);
  });
}

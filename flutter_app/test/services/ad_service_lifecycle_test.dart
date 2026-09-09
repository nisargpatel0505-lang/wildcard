// Pinned SDK channel harness, following its own platform-free test pattern.
// ignore_for_file: implementation_imports

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:wildcard/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  late List<MethodCall> calls;
  late List<InterstitialAd> pendingInterstitials;
  late bool failInterstitialLoads;
  late bool consentAllowsAds;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    pendingInterstitials = [];
    failInterstitialLoads = true;
    consentAllowsAds = true;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ump, (call) async {
      switch (call.method) {
        case 'ConsentInformation#canRequestAds':
          return consentAllowsAds;
        case 'ConsentInformation#getPrivacyOptionsRequirementStatus':
          return 1;
        case 'ConsentInformation#requestConsentInfoUpdate':
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          return null;
        default:
          throw StateError('Unexpected UMP request: ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case '_init':
        case 'disposeAd':
        case 'showAdWithoutView':
          return null;
        case 'MobileAds#initialize':
          return InitializationStatus(<String, AdapterStatus>{});
        case 'loadRewardedAd':
          final ad =
              instanceManager.adFor(call.arguments['adId']) as RewardedAd;
          ad.rewardedAdLoadCallback.onAdFailedToLoad(
            LoadAdError(3, 'test', 'No fill in test harness', null),
          );
          return null;
        case 'loadInterstitialAd':
          final ad =
              instanceManager.adFor(call.arguments['adId']) as InterstitialAd;
          if (failInterstitialLoads) {
            ad.adLoadCallback.onAdFailedToLoad(
              LoadAdError(3, 'test', 'No fill in test harness', null),
            );
          } else {
            pendingInterstitials.add(ad);
          }
          return null;
        default:
          throw StateError('Unexpected ad request: ${call.method}');
      }
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ump, null);
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> waitForPendingLoad() async {
    for (var tick = 0; tick < 20 && pendingInterstitials.isEmpty; tick++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(pendingInterstitials, hasLength(1));
  }

  test(
    'consent denial prevents native initialization and ad requests',
    () async {
      consentAllowsAds = false;
      final ads = AdService(ownerNoAds: false);
      addTearDown(ads.dispose);
      expect(await ads.initializeAfterPrivacyAcceptance(), isFalse);
      expect(ads.ready, isFalse);
      expect(calls, isEmpty);
      expect(ads.privacyOptionsRequired, isTrue);
    },
  );

  test(
    'late Remove Ads entitlement cancels an interstitial awaiting load',
    () async {
      final ads = AdService(ownerNoAds: false);
      addTearDown(ads.dispose);
      expect(await ads.initializeAfterPrivacyAcceptance(), isTrue);
      failInterstitialLoads = false;
      final showResult = ads.showInterstitial();
      await waitForPendingLoad();
      final pending = pendingInterstitials.single;
      final pendingId = instanceManager.adIdFor(pending);

      ads.setForcedAdsRemoved(true);
      pending.adLoadCallback.onAdLoaded(pending);
      // If a regression requests a display, finish it to avoid an unbounded test.
      await Future<void>.delayed(Duration.zero);
      pending.fullScreenContentCallback?.onAdDismissedFullScreenContent?.call(
        pending,
      );

      expect(await showResult, isFalse);
      expect(ads.interstitialReady, isFalse);
      expect(
        calls.where((call) => call.method == 'showAdWithoutView'),
        isEmpty,
      );
      expect(
        calls.where(
          (call) =>
              call.method == 'disposeAd' && call.arguments['adId'] == pendingId,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'late load after service disposal is discarded without showing',
    () async {
      final ads = AdService(ownerNoAds: false);
      expect(await ads.initializeAfterPrivacyAcceptance(), isTrue);
      failInterstitialLoads = false;
      final showResult = ads.showInterstitial();
      await waitForPendingLoad();
      final pending = pendingInterstitials.single;
      ads.dispose();
      pending.adLoadCallback.onAdLoaded(pending);
      expect(await showResult, isFalse);
      expect(
        calls.where((call) => call.method == 'showAdWithoutView'),
        isEmpty,
      );
    },
  );
}

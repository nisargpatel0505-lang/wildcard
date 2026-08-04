import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/services/ad_service.dart';

void main() {
  test('profile ad-free override never mutates the paid entitlement', () {
    final account = AccountState(noAds: false);

    expect(effectiveNoAdsFor(account, profileBuild: true), isTrue);
    expect(effectiveNoAdsFor(account, profileBuild: false), isFalse);
    expect(account.noAds, isFalse);

    account.noAds = true;
    expect(effectiveNoAdsFor(account, profileBuild: false), isTrue);
  });

  test('forced-ad entitlement never manufactures a rewarded claim', () async {
    final ads = AdService()..setForcedAdsRemoved(true);
    addTearDown(ads.dispose);

    expect(ads.forcedAdsRemoved, isTrue);
    expect(ads.interstitialReady, isFalse);
    expect(await ads.showRewarded(), isNull);
    expect(await ads.showInterstitial(), isFalse);
  });
}

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

  test('ad-free service resolves rewards without initializing an ad', () async {
    final ads = AdService()..setNoAds(true);
    addTearDown(ads.dispose);

    expect(await ads.initializeAfterPrivacyAcceptance(), isTrue);
    expect(ads.ready, isTrue);
    expect(ads.rewardedReady, isFalse);
    expect(ads.interstitialReady, isFalse);

    final reward = await ads.showRewarded();
    expect(reward, isNotNull);
    expect(reward!.type, 'ad_free');
    expect(await ads.showInterstitial(), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wildcard/services/ad_service.dart';
import 'package:wildcard/services/forced_ad_policy.dart';

void main() {
  TerminalInterstitialContext terminal({
    String runId = 'run-2',
    bool tutorial = false,
    bool firstRun = false,
    bool abandoned = false,
    int hands = 8,
    int cleared = 2,
  }) => TerminalInterstitialContext(
    runId: runId,
    isTutorial: tutorial,
    isFirstRun: firstRun,
    abandoned: abandoned,
    handsPlayed: hands,
    stagesCleared: cleared,
  );

  test('forced entitlement only blocks forced interstitials', () async {
    var rewardedCalls = 0;
    var interstitialCalls = 0;
    final ads = AdService(
      rewardedPresenter: () async {
        rewardedCalls++;
        return RewardItem(1, 'test_reward');
      },
      interstitialPresenter: () async {
        interstitialCalls++;
        return true;
      },
    )..setForcedAdsRemoved(true);
    addTearDown(ads.dispose);

    expect(await ads.showRewarded(), isNotNull);
    expect(rewardedCalls, 1);
    expect(await ads.showTerminalInterstitial(terminal()), isFalse);
    expect(interstitialCalls, 0);
  });

  test('optional rewards never receive a phantom ad-free completion', () async {
    final ads = AdService()..setForcedAdsRemoved(true);
    addTearDown(ads.dispose);

    expect(await ads.showRewarded(), isNull);
  });

  test('policy excludes tutorial, first run and short abandon', () {
    final policy = ForcedInterstitialPolicy();

    expect(
      policy.evaluate(terminal(tutorial: true), forcedAdsRemoved: false),
      ForcedInterstitialDecision.tutorial,
    );
    expect(
      policy.evaluate(terminal(firstRun: true), forcedAdsRemoved: false),
      ForcedInterstitialDecision.firstRun,
    );
    expect(
      policy.evaluate(
        terminal(abandoned: true, hands: 1, cleared: 0),
        forcedAdsRemoved: false,
      ),
      ForcedInterstitialDecision.shortAbandon,
    );
    expect(
      policy.evaluate(
        terminal(abandoned: true, hands: 3, cleared: 0),
        forcedAdsRemoved: false,
      ),
      ForcedInterstitialDecision.allowed,
    );
  });

  test('one terminal attempt is allowed per run', () {
    final policy = ForcedInterstitialPolicy();
    final context = terminal(runId: 'single-terminal');

    expect(
      policy.beginAttempt(context, forcedAdsRemoved: false),
      ForcedInterstitialDecision.allowed,
    );
    expect(
      policy.beginAttempt(context, forcedAdsRemoved: false),
      ForcedInterstitialDecision.alreadyAttemptedForRun,
    );
  });

  test('successful forced ad starts a nine-minute cooldown', () {
    var now = DateTime.utc(2026, 7, 28, 12);
    final policy = ForcedInterstitialPolicy(now: () => now);

    expect(
      policy.beginAttempt(terminal(runId: 'run-a'), forcedAdsRemoved: false),
      ForcedInterstitialDecision.allowed,
    );
    policy.recordShown();
    now = now.add(const Duration(minutes: 8, seconds: 59));
    expect(
      policy.evaluate(terminal(runId: 'run-b'), forcedAdsRemoved: false),
      ForcedInterstitialDecision.cooldown,
    );
    now = now.add(const Duration(seconds: 1));
    expect(
      policy.evaluate(terminal(runId: 'run-b'), forcedAdsRemoved: false),
      ForcedInterstitialDecision.allowed,
    );
  });

  test('non-owner terminal ad records success and cannot repeat', () async {
    var shown = 0;
    final ads = AdService(
      interstitialPresenter: () async {
        shown++;
        return true;
      },
    );
    addTearDown(ads.dispose);
    final context = terminal(runId: 'real-terminal');

    expect(await ads.showTerminalInterstitial(context), isTrue);
    expect(await ads.showTerminalInterstitial(context), isFalse);
    expect(shown, 1);
  });
}

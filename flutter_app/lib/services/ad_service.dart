import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/app_constants.dart';
import 'forced_ad_policy.dart';

enum AdServiceState {
  idle,
  requestingConsent,
  initializing,
  ready,
  unavailable,
}

class AdService extends ChangeNotifier {
  AdService({
    ForcedInterstitialPolicy? forcedInterstitialPolicy,
    @visibleForTesting this.rewardedPresenter,
    @visibleForTesting this.interstitialPresenter,
  }) : forcedInterstitialPolicy =
           forcedInterstitialPolicy ?? ForcedInterstitialPolicy();

  static const bool _forceTestAds = bool.fromEnvironment(
    'WILDCARD_ADS_TESTING',
    defaultValue: false,
  );

  AdServiceState _state = AdServiceState.idle;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  Object? _lastError;
  bool _privacyOptionsRequired = false;
  bool _forcedAdsRemoved = false;
  @visibleForTesting
  final Future<RewardItem?> Function()? rewardedPresenter;

  @visibleForTesting
  final Future<bool> Function()? interstitialPresenter;
  final ForcedInterstitialPolicy forcedInterstitialPolicy;

  AdServiceState get state => _state;
  Object? get lastError => _lastError;
  bool get ready => _state == AdServiceState.ready;
  bool get rewardedReady => _rewarded != null;
  bool get interstitialReady => _interstitial != null;
  bool get privacyOptionsRequired => _privacyOptionsRequired;
  bool get forcedAdsRemoved => _forcedAdsRemoved;

  /// Legacy name retained for callers while the persisted `noAds` field keeps
  /// save and purchase compatibility. It now means forced ads only.
  bool get noAds => forcedAdsRemoved;
  bool get testing => !kReleaseMode || _forceTestAds;

  String get rewardedAdUnitId => testing
      ? AppConstants.testRewardedAdId
      : AppConstants.productionRewardedAdId;

  String get interstitialAdUnitId => testing
      ? AppConstants.testInterstitialAdId
      : AppConstants.productionInterstitialAdId;

  void setForcedAdsRemoved(bool value) {
    if (_forcedAdsRemoved == value) return;
    _forcedAdsRemoved = value;
    if (value) {
      _interstitial?.dispose();
      _interstitial = null;
    } else if (ready) {
      unawaited(_loadInterstitial());
    }
    notifyListeners();
  }

  void setNoAds(bool value) => setForcedAdsRemoved(value);

  /// Must only be called after WILDCARD's first-launch privacy gate is accepted.
  Future<bool> initializeAfterPrivacyAcceptance() async {
    if (ready) return true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _state = AdServiceState.unavailable;
      notifyListeners();
      return false;
    }

    _lastError = null;
    _state = AdServiceState.requestingConsent;
    notifyListeners();
    try {
      Object? consentError;
      try {
        await _requestConsentInformation();
      } catch (error) {
        // UMP explicitly allows using a valid consent decision retained from a
        // previous session after a transient update/form failure.
        consentError = error;
      }
      try {
        _privacyOptionsRequired =
            await ConsentInformation.instance
                .getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
      } catch (error) {
        consentError ??= error;
      }
      final canRequestAds = await ConsentInformation.instance.canRequestAds();
      _lastError = consentError;
      if (!canRequestAds) {
        _state = AdServiceState.unavailable;
        notifyListeners();
        return false;
      }

      _state = AdServiceState.initializing;
      notifyListeners();
      await MobileAds.instance.initialize();
      _state = AdServiceState.ready;
      await Future.wait<void>([
        _loadRewarded(),
        if (!_forcedAdsRemoved) _loadInterstitial(),
      ]);
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = error;
      _state = AdServiceState.unavailable;
      notifyListeners();
      return false;
    }
  }

  Future<void> _requestConsentInformation() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          FormError? formError;
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            formError = error;
          });
          if (completer.isCompleted) return;
          if (formError == null) {
            completer.complete();
          } else {
            completer.completeError(formError!);
          }
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
      (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    await completer.future;
  }

  Future<void> showPrivacyOptions() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(error);
      }
    });
    await completer.future;
  }

  Future<void> _loadRewarded() async {
    if (!ready || _rewarded != null) return;
    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          notifyListeners();
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _lastError = error;
          notifyListeners();
          completer.complete();
        },
      ),
    );
    await completer.future;
  }

  Future<RewardItem?> showRewarded() async {
    final testPresenter = rewardedPresenter;
    if (testPresenter != null) return testPresenter();
    if (!ready) return null;
    if (_rewarded == null) await _loadRewarded();
    final ad = _rewarded;
    if (ad == null) return null;
    _rewarded = null;
    notifyListeners();

    final completer = Completer<RewardItem?>();
    RewardItem? earned;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        if (!completer.isCompleted) completer.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        shownAd.dispose();
        _lastError = error;
        if (!completer.isCompleted) completer.complete(null);
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, reward) => earned = reward);
    return completer.future;
  }

  Future<void> _loadInterstitial() async {
    if (!ready || _forcedAdsRemoved || _interstitial != null) return;
    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          notifyListeners();
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _lastError = error;
          notifyListeners();
          completer.complete();
        },
      ),
    );
    await completer.future;
  }

  Future<bool> showInterstitial() async {
    if (_forcedAdsRemoved) return false;
    final testPresenter = interstitialPresenter;
    if (testPresenter != null) return testPresenter();
    if (!ready) return false;
    if (_interstitial == null) await _loadInterstitial();
    final ad = _interstitial;
    if (ad == null) return false;
    _interstitial = null;
    notifyListeners();

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        completer.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        shownAd.dispose();
        _lastError = error;
        completer.complete(false);
        _loadInterstitial();
      },
    );
    ad.show();
    return completer.future;
  }

  /// The only public gameplay path for a forced interstitial.
  ///
  /// Rewarded placements intentionally do not consult this entitlement or
  /// policy: they remain optional and only return a reward after Google's
  /// completion callback.
  Future<bool> showTerminalInterstitial(
    TerminalInterstitialContext context,
  ) async {
    final decision = forcedInterstitialPolicy.beginAttempt(
      context,
      forcedAdsRemoved: _forcedAdsRemoved,
    );
    if (decision != ForcedInterstitialDecision.allowed) return false;
    final shown = await showInterstitial();
    if (shown) forcedInterstitialPolicy.recordShown();
    return shown;
  }

  @override
  void dispose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }
}

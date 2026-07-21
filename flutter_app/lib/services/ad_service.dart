import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/app_constants.dart';

enum AdServiceState {
  idle,
  requestingConsent,
  initializing,
  ready,
  unavailable,
}

class AdService extends ChangeNotifier {
  static const bool _forceTestAds = bool.fromEnvironment(
    'WILDCARD_ADS_TESTING',
    defaultValue: false,
  );

  AdServiceState _state = AdServiceState.idle;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  Object? _lastError;
  bool _privacyOptionsRequired = false;
  bool _noAds = false;

  AdServiceState get state => _state;
  Object? get lastError => _lastError;
  bool get ready => _state == AdServiceState.ready;
  bool get rewardedReady => _rewarded != null;
  bool get interstitialReady => _interstitial != null;
  bool get privacyOptionsRequired => _privacyOptionsRequired;
  bool get noAds => _noAds;
  bool get testing => !kReleaseMode || _forceTestAds;

  String get rewardedAdUnitId => testing
      ? AppConstants.testRewardedAdId
      : AppConstants.productionRewardedAdId;

  String get interstitialAdUnitId => testing
      ? AppConstants.testInterstitialAdId
      : AppConstants.productionInterstitialAdId;

  void setNoAds(bool value) {
    if (_noAds == value) return;
    _noAds = value;
    if (value) {
      _rewarded?.dispose();
      _rewarded = null;
      _interstitial?.dispose();
      _interstitial = null;
    } else if (ready) {
      unawaited(_loadRewarded());
      unawaited(_loadInterstitial());
    }
    notifyListeners();
  }

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
        if (!_noAds) _loadRewarded(),
        if (!_noAds) _loadInterstitial(),
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
    if (!ready || _noAds || _interstitial != null) return;
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
    if (!ready || _noAds) return false;
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

  @override
  void dispose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }
}

/* WILDCARD native bridge for the Capacitor Android shell.
   Native services are optional, but native purchases always fail closed: the
   Android build must never fall back to the browser's demo purchase flow. */
(function () {
  'use strict';

  var C = window.Capacitor;
  if (!C || !C.isNativePlatform || !C.isNativePlatform()) return;

  var P = C.Plugins || {};
  var WN = { isNative: true };
  window.WildcardNative = WN;

  function callback(cb, value) {
    if (!cb) return;
    try { cb(value); } catch (e) {}
  }

  /* =============== FIREBASE ACCOUNT + PLAY GAMES =============== */
  var Cloud = P.WildcardCloud;
  WN.cloudAvailable = !!Cloud;
  if (Cloud) {
    WN.cloudAuthState = function () { return Cloud.authState(); };
    WN.cloudSignInGoogle = function () { return Cloud.signInWithGoogle(); };
    WN.cloudSignOut = function () { return Cloud.signOut(); };
    WN.cloudReadSave = function () { return Cloud.readCloudSave(); };
    WN.cloudWriteSave = function (accountJson, runJson, clientSavedAt) {
      return Cloud.writeCloudSave({
        accountJson: accountJson || '',
        runJson: runJson || '',
        clientSavedAt: Math.max(0, Number(clientSavedAt) || Date.now())
      });
    };
    WN.playGamesState = function () { return Cloud.playGamesState(); };
    WN.playGamesSignIn = function () { return Cloud.signInPlayGames(); };
    WN.submitPlayGamesScore = function (score) {
      return Cloud.submitScore({ score: Math.max(0, Math.floor(Number(score) || 0)) });
    };
    WN.loadPlayGamesLeaderboard = function (span) {
      return Cloud.loadLeaderboardScores({ span: span || 'all' });
    };
    WN.showPlayGamesLeaderboard = function () { return Cloud.showLeaderboard(); };
  }

  /* ======================= PHONE PERSISTENCE ======================= */
  var Preferences = P.Preferences;
  var SAVE_KEYS = ['wildcard_save_v1', 'wildcard_run_v1'];
  var PREF_PREFIX = 'wildcard.phone.';

  WN.storageReady = Promise.resolve({});
  if (Preferences) {
    WN.storageReady = Promise.all(SAVE_KEYS.map(function (key) {
      return Preferences.get({ key: PREF_PREFIX + key })
        .then(function (result) { return [key, result && result.value || null]; })
        .catch(function () { return [key, null]; });
    })).then(function (pairs) {
      var out = {};
      pairs.forEach(function (pair) { out[pair[0]] = pair[1]; });
      return out;
    });

    WN.persist = function (key, value) {
      return Preferences.set({ key: PREF_PREFIX + key, value: String(value) }).catch(function () {});
    };
    WN.removePersisted = function (key) {
      return Preferences.remove({ key: PREF_PREFIX + key }).catch(function () {});
    };
  }

  /* ============================ HAPTICS ============================ */
  var Haptics = P.Haptics;
  WN.haptic = function (kind) {
    if (!Haptics) return;
    try {
      if (kind === 'success' || kind === 'warning' || kind === 'error') {
        Haptics.notification({ type: kind.toUpperCase() }).catch(function () {});
      } else {
        var style = kind === 'heavy' ? 'HEAVY' : kind === 'medium' ? 'MEDIUM' : 'LIGHT';
        Haptics.impact({ style: style }).catch(function () {});
      }
    } catch (e) {}
  };

  /* ============================== ADS ============================= */
  var AdMob = P.AdMob;
  var REWARDED_AD_ID = 'ca-app-pub-3940256099942544/5224354917';
  var INTERSTITIAL_AD_ID = 'ca-app-pub-3940256099942544/1033173712';
  var AD_TESTING = true;
  var ad = {
    allowed: false,
    consentStatus: 'UNKNOWN',
    privacyRequired: false,
    rewardedReady: false,
    rewardedPreparing: false,
    rewardedInFlight: false,
    rewardedEarned: false,
    rewardedCb: null,
    interstitialReady: false,
    interstitialPreparing: false,
    interstitialCb: null
  };

  WN.getPrivacyState = function () {
    return {
      allowed: ad.allowed,
      status: ad.consentStatus,
      privacyRequired: ad.privacyRequired,
      testing: AD_TESTING
    };
  };

  function prepareRewarded() {
    if (!AdMob || !ad.allowed || ad.rewardedPreparing || ad.rewardedReady) return;
    ad.rewardedPreparing = true;
    AdMob.prepareRewardVideoAd({ adId: REWARDED_AD_ID, isTesting: AD_TESTING, immersiveMode: true })
      .catch(function () { ad.rewardedPreparing = false; });
  }

  function prepareInterstitial() {
    if (!AdMob || !ad.allowed || ad.interstitialPreparing || ad.interstitialReady) return;
    ad.interstitialPreparing = true;
    AdMob.prepareInterstitial({ adId: INTERSTITIAL_AD_ID, isTesting: AD_TESTING, immersiveMode: true })
      .catch(function () { ad.interstitialPreparing = false; });
  }

  function prepareAds() {
    prepareRewarded();
    prepareInterstitial();
  }

  function settleRewarded(success) {
    var cb = ad.rewardedCb;
    if (!cb) return false;
    ad.rewardedCb = null;
    callback(cb, !!success);
    return true;
  }

  function finishRewardedShow() {
    var earned = ad.rewardedEarned;
    ad.rewardedInFlight = false;
    ad.rewardedEarned = false;
    ad.rewardedReady = false;
    prepareRewarded();
    if (!earned) settleRewarded(false);
  }

  function applyConsentInfo(info) {
    info = info || {};
    ad.allowed = !!info.canRequestAds;
    ad.consentStatus = info.status || 'UNKNOWN';
    ad.privacyRequired = info.privacyOptionsRequirementStatus === 'REQUIRED';
    if (ad.allowed) prepareAds();
    return info;
  }

  function initialiseAds() {
    if (!AdMob) return;

    AdMob.addListener('onRewardedVideoAdLoaded', function () {
      ad.rewardedReady = true;
      ad.rewardedPreparing = false;
    });
    AdMob.addListener('onRewardedVideoAdFailedToLoad', function () {
      ad.rewardedReady = false;
      ad.rewardedPreparing = false;
      setTimeout(prepareRewarded, 30000);
    });
    AdMob.addListener('onRewardedVideoAdReward', function () {
      if (!ad.rewardedInFlight || ad.rewardedEarned) return;
      ad.rewardedEarned = true;
      settleRewarded(true);
    });
    AdMob.addListener('onRewardedVideoAdDismissed', function () {
      if (!ad.rewardedInFlight) return;
      finishRewardedShow();
    });
    AdMob.addListener('onRewardedVideoAdFailedToShow', function () {
      if (!ad.rewardedInFlight) return;
      finishRewardedShow();
    });

    AdMob.addListener('interstitialAdLoaded', function () {
      ad.interstitialReady = true;
      ad.interstitialPreparing = false;
    });
    AdMob.addListener('interstitialAdFailedToLoad', function () {
      ad.interstitialReady = false;
      ad.interstitialPreparing = false;
      setTimeout(prepareInterstitial, 45000);
    });
    AdMob.addListener('interstitialAdDismissed', function () {
      var cb = ad.interstitialCb;
      ad.interstitialCb = null;
      ad.interstitialReady = false;
      prepareInterstitial();
      callback(cb, true);
    });
    AdMob.addListener('interstitialAdFailedToShow', function () {
      var cb = ad.interstitialCb;
      ad.interstitialCb = null;
      ad.interstitialReady = false;
      prepareInterstitial();
      callback(cb, false);
    });

    AdMob.initialize({
      initializeForTesting: AD_TESTING,
      tagForChildDirectedTreatment: false,
      tagForUnderAgeOfConsent: false,
      maxAdContentRating: 'Teen'
    }).then(function () {
      return AdMob.requestConsentInfo();
    }).then(function (info) {
      if (!info.canRequestAds && info.isConsentFormAvailable && info.status === 'REQUIRED') {
        return AdMob.showConsentForm();
      }
      return info;
    }).then(applyConsentInfo).catch(function () {
      // Test builds remain usable when no AdMob message has been configured yet.
      ad.allowed = AD_TESTING;
      if (ad.allowed) prepareAds();
    });

    WN.showRewardedAd = function (cb) {
      if (!ad.allowed || !ad.rewardedReady || ad.rewardedInFlight) {
        prepareRewarded();
        callback(cb, false);
        return;
      }
      ad.rewardedEarned = false;
      ad.rewardedInFlight = true;
      ad.rewardedCb = cb;
      AdMob.showRewardVideoAd().catch(function () {
        if (!ad.rewardedInFlight) return;
        finishRewardedShow();
      });
    };

    WN.showInterstitial = function (cb) {
      if (!ad.allowed || !ad.interstitialReady || ad.interstitialCb) {
        prepareInterstitial();
        callback(cb, false);
        return;
      }
      ad.interstitialCb = cb;
      AdMob.showInterstitial().catch(function () {
        var failed = ad.interstitialCb;
        ad.interstitialCb = null;
        ad.interstitialReady = false;
        prepareInterstitial();
        callback(failed, false);
      });
    };

    WN.showPrivacyOptions = function (cb) {
      AdMob.showPrivacyOptionsForm()
        .then(function () { return AdMob.requestConsentInfo(); })
        .then(function (info) { applyConsentInfo(info); callback(cb, true); })
        .catch(function () { callback(cb, false); });
    };

    WN.setAdMuted = function (muted) {
      AdMob.setApplicationMuted({ muted: !!muted }).catch(function () {});
    };
  }

  initialiseAds();

  /* ============================ BILLING ============================ */
  var PRODUCTS = [
    { id: 'coins_250', consumable: true },
    { id: 'coins_600', consumable: true },
    { id: 'coins_1600', consumable: true },
    { id: 'coins_3600', consumable: true },
    { id: 'coins_8500', consumable: true },
    { id: 'remove_ads', consumable: false }
  ];
  var billing = { ready: false, waiting: {}, activeProductId: null };

  // Fail-closed defaults prevent native builds from granting demo purchases.
  WN.purchase = function (productId, cb) { callback(cb, false); };
  WN.restorePurchases = function (cb) { callback(cb, []); };

  function verifiedProductIds(receipt) {
    var ids = [];
    function add(id) {
      if (typeof id !== 'string' || !id || ids.indexOf(id) !== -1) return;
      ids.push(id);
    }
    function addTransactions(transactions) {
      (Array.isArray(transactions) ? transactions : []).forEach(function (transaction) {
        (transaction && Array.isArray(transaction.products) ? transaction.products : [])
          .forEach(function (product) { add(product && product.id); });
      });
    }

    // cordova-plugin-purchase v13 VerifiedReceipt shape.
    (receipt && Array.isArray(receipt.collection) ? receipt.collection : [])
      .forEach(function (purchase) { add(purchase && purchase.id); });
    addTransactions(receipt && receipt.sourceReceipt && receipt.sourceReceipt.transactions);

    // Retain compatibility with receipt shapes used by older plugin releases.
    addTransactions(receipt && receipt.transactions);
    if (receipt && receipt.transaction) addTransactions([receipt.transaction]);
    return ids;
  }

  function settlePurchase(productId, success) {
    var cb = billing.waiting[productId];
    if (!cb) return false;
    delete billing.waiting[productId];
    if (billing.activeProductId === productId) billing.activeProductId = null;
    callback(cb, !!success);
    return true;
  }

  function finishDeliveredReceipt(receipt) {
    try {
      Promise.resolve(receipt.finish()).catch(function () {});
    } catch (e) {}
  }

  function initBilling() {
    var Purchase = window.CdvPurchase;
    if (!Purchase || !Purchase.store || billing.ready) return;
    var store = Purchase.store;

    try {
      store.register(PRODUCTS.map(function (product) {
        return {
          id: product.id,
          type: product.consumable ? Purchase.ProductType.CONSUMABLE : Purchase.ProductType.NON_CONSUMABLE,
          platform: Purchase.Platform.GOOGLE_PLAY
        };
      }));

      store.when()
        .approved(function (transaction) { transaction.verify(); })
        .verified(function (receipt) {
          var productId = billing.activeProductId;
          if (!productId || verifiedProductIds(receipt).indexOf(productId) === -1) return;

          // Delivery must happen before acknowledgement/consumption. Deleting the
          // waiting callback first also makes duplicate verified events idempotent
          // for the lifetime of this bridge instance.
          if (settlePurchase(productId, true)) finishDeliveredReceipt(receipt);
        });

      store.initialize([Purchase.Platform.GOOGLE_PLAY]).then(function () {
        billing.ready = true;
      }).catch(function () {});

      WN.purchase = function (productId, cb) {
        if (!billing.ready || billing.activeProductId) { callback(cb, false); return; }
        var product = store.get(productId, Purchase.Platform.GOOGLE_PLAY);
        var offer = product && product.getOffer && product.getOffer();
        if (!offer) { callback(cb, false); return; }
        billing.activeProductId = productId;
        billing.waiting[productId] = cb;
        store.order(offer).then(function (err) {
          if (err) {
            settlePurchase(productId, false);
          }
        }).catch(function () { settlePurchase(productId, false); });
      };

      WN.restorePurchases = function (cb) {
        var report = function () {
          var owned = [];
          try {
            PRODUCTS.forEach(function (product) {
              var item = store.get(product.id, Purchase.Platform.GOOGLE_PLAY);
              if (item && item.owned) owned.push(product.id);
            });
          } catch (e) {}
          callback(cb, owned);
        };
        if (billing.ready) store.restorePurchases().then(report).catch(report);
        else setTimeout(function () { WN.restorePurchases(cb); }, 2000);
      };
    } catch (e) {}
  }

  document.addEventListener('deviceready', initBilling, false);
  setTimeout(initBilling, 2500);
})();

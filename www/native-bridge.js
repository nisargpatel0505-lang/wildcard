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
  var currentCloudUid = '';
  WN.cloudAvailable = !!Cloud;
  function rememberCloudAuth(state) {
    currentCloudUid = state && state.signedIn && state.uid ? String(state.uid) : '';
    return state;
  }
  if (Cloud) {
    WN.cloudAuthState = function () { return Cloud.authState().then(rememberCloudAuth); };
    WN.cloudSignInGoogle = function () { return Cloud.signInWithGoogle().then(rememberCloudAuth); };
    WN.cloudSignOut = function () {
      return Cloud.signOut().then(function (state) {
        currentCloudUid = '';
        return state;
      });
    };
    WN.cloudReadSave = function () { return Cloud.readCloudSave(); };
    WN.cloudWriteSave = function (accountJson, runJson, clientSavedAt) {
      return Cloud.writeCloudSave({
        accountJson: accountJson || '',
        runJson: runJson || '',
        clientSavedAt: Math.max(0, Number(clientSavedAt) || Date.now())
      });
    };
    if (typeof Cloud.deleteAccount === 'function') {
      WN.cloudDeleteAccount = function () {
        return Cloud.deleteAccount().then(function (result) {
          currentCloudUid = '';
          return result;
        });
      };
    }
    WN.playGamesState = function () { return Cloud.playGamesState(); };
    WN.playGamesSignIn = function () { return Cloud.signInPlayGames(); };
    WN.submitPlayGamesScore = function (score) {
      return Cloud.submitScore({ score: Math.max(0, Math.floor(Number(score) || 0)) });
    };
    WN.loadPlayGamesLeaderboard = function (span) {
      return Cloud.loadLeaderboardScores({ span: span || 'all' });
    };
    WN.showPlayGamesLeaderboard = function () { return Cloud.showLeaderboard(); };
    if (typeof Cloud.submitDailyScore === 'function') {
      WN.cloudSubmitDailyScore = function (submission) {
        submission = submission || {};
        return Cloud.submitDailyScore({
          name: String(submission.name || '').trim().toUpperCase(),
          score: Math.max(0, Math.floor(Number(submission.score) || 0)),
          idempotencyKey: String(submission.idempotencyKey || '')
        });
      };
    }
  }

  /* ======================= PHONE PERSISTENCE ======================= */
  var Preferences = P.Preferences;
  var SAVE_KEYS = ['wildcard_save_v1', 'wildcard_run_v1', 'wildcard_privacy_accept_v1', 'wildcard_cloud_owner_v2'];
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
  var REWARDED_AD_ID = '';
  var INTERSTITIAL_AD_ID = '';
  var AD_TESTING = false;
  var serviceConfigReady = Cloud && typeof Cloud.serviceConfig === 'function'
    ? Cloud.serviceConfig().catch(function () { return {}; })
    : Promise.resolve({});
  var ad = {
    configured: false,
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
      configured: ad.configured,
      allowed: ad.allowed,
      status: ad.consentStatus,
      privacyRequired: ad.privacyRequired,
      testing: AD_TESTING
    };
  };

  function prepareRewarded() {
    if (!AdMob || !ad.configured || !ad.allowed || ad.rewardedPreparing || ad.rewardedReady) return;
    ad.rewardedPreparing = true;
    AdMob.prepareRewardVideoAd({ adId: REWARDED_AD_ID, isTesting: AD_TESTING, immersiveMode: true })
      .catch(function () { ad.rewardedPreparing = false; });
  }

  function prepareInterstitial() {
    if (!AdMob || !ad.configured || !ad.allowed || ad.interstitialPreparing || ad.interstitialReady) return;
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

  var adsInitialised = false;
  function initialiseAds(config) {
    config = config || {};
    REWARDED_AD_ID = typeof config.rewardedAdId === 'string' ? config.rewardedAdId : '';
    INTERSTITIAL_AD_ID = typeof config.interstitialAdId === 'string' ? config.interstitialAdId : '';
    AD_TESTING = !!config.adTesting;
    ad.configured = !!config.adsEnabled
      && /^ca-app-pub-\d{16}\/\d{10}$/.test(REWARDED_AD_ID)
      && /^ca-app-pub-\d{16}\/\d{10}$/.test(INTERSTITIAL_AD_ID);
    if (!AdMob || !ad.configured || adsInitialised) return false;
    adsInitialised = true;

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
      // Developer builds may continue with Google's demonstration ads. A
      // release build always remains disabled after any consent/config error.
      ad.allowed = AD_TESTING;
      if (ad.allowed) prepareAds();
    });

    WN.showRewardedAd = function (cb) {
      if (!ad.configured || !ad.allowed || !ad.rewardedReady || ad.rewardedInFlight) {
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
    return true;
  }

  // Fail-closed methods exist before configuration so the Android shell never
  // falls through to browser-preview rewards.
  WN.showRewardedAd = function (cb) { callback(cb, false); };
  WN.showInterstitial = function (cb) { callback(cb, false); };
  WN.showPrivacyOptions = function (cb) { callback(cb, false); };
  WN.setAdMuted = function () {};

  // The game calls this only after the player has explicitly accepted the
  // current privacy policy. No SDK initialization, consent request or ad load
  // happens behind the mandatory first-launch policy gate.
  WN.enableAdsAfterPolicyAcceptance = function () {
    return serviceConfigReady.then(initialiseAds);
  };

  /* ============================ BILLING ============================ */
  var PRODUCTS = [
    { id: 'coins_250', consumable: true },
    { id: 'coins_600', consumable: true },
    { id: 'coins_1600', consumable: true },
    { id: 'coins_3600', consumable: true },
    { id: 'coins_8500', consumable: true },
    { id: 'remove_ads', consumable: false }
  ];
  var billing = {
    enabled: false,
    ready: false,
    initialising: false,
    initialization: null,
    orderStarting: false,
    waiting: {},
    activeProductId: null,
    accountUid: '',
    receipts: {},
    deliveryQueue: [],
    deliveryHandler: null,
    store: null
  };

  // Fail-closed defaults prevent native builds from granting demo purchases.
  WN.purchase = function (productId, cb) {
    callback(cb, { ok: false, productId: productId || '', reason: 'billing_unavailable' });
  };
  WN.restorePurchases = function (cb) { callback(cb, { owned: [], entitlements: null }); };
  WN.getBillingProducts = function () { return Promise.resolve([]); };
  WN.completePurchase = function (tokenHash, cb) { callback(cb, false); };
  WN.refreshPurchases = function () {
    return Promise.resolve({ signedIn: false, owned: [], entitlements: null, products: [] });
  };
  WN.setPurchaseDeliveryHandler = function (handler) {
    billing.deliveryHandler = typeof handler === 'function' ? handler : null;
  };

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
    (receipt && Array.isArray(receipt.collection) ? receipt.collection : [])
      .forEach(function (purchase) { add(purchase && purchase.id); });
    addTransactions(receipt && receipt.sourceReceipt && receipt.sourceReceipt.transactions);
    addTransactions(receipt && receipt.transactions);
    if (receipt && receipt.transaction) addTransactions([receipt.transaction]);
    return ids;
  }
  function transactionProductIds(transaction) {
    return (transaction && Array.isArray(transaction.products) ? transaction.products : [])
      .map(function (product) { return product && product.id; })
      .filter(Boolean);
  }
  function settlePurchase(productId, result) {
    var cb = billing.waiting[productId];
    if (!cb) return false;
    delete billing.waiting[productId];
    if (billing.activeProductId === productId) billing.activeProductId = null;
    billing.orderStarting = false;
    callback(cb, result);
    return true;
  }
  function validationFailure(done, reason) {
    var Purchase = window.CdvPurchase;
    var code = Purchase && Purchase.ErrorCode && Purchase.ErrorCode.VERIFICATION_FAILED;
    done({
      ok: false,
      code: code || 6778003,
      message: reason || 'Google Play verification failed'
    });
  }
  function validatorResponse(body, result) {
    return {
      ok: true,
      data: {
        id: result.tokenHash,
        latest_receipt: true,
        transaction: {
          type: body.transaction.type,
          kind: 'androidpublisher#productPurchase',
          purchaseToken: body.transaction.purchaseToken,
          tokenHash: result.tokenHash,
          delivered: !!result.delivered
        },
        collection: [{
          id: result.productId,
          // Match the native transaction so the plugin can safely skip a
          // redundant consume/acknowledge after Play reports it finished.
          transactionId: body.transaction.id,
          isConsumed: !!result.consumed
        }]
      }
    };
  }
  function receiptDelivery(receipt) {
    var ids = verifiedProductIds(receipt);
    var productId = ids.length === 1 ? ids[0] : '';
    var source = receipt && receipt.sourceReceipt;
    var transaction = source && Array.isArray(source.transactions) ? source.transactions[0] : null;
    var raw = receipt && receipt.raw || {};
    var rawTransaction = raw.transaction || {};
    var purchaseToken = source && source.purchaseToken
      || transaction && transaction.purchaseId
      || rawTransaction.purchaseToken
      || '';
    var tokenHash = typeof raw.id === 'string' ? raw.id : rawTransaction.tokenHash || '';
    if (!PRODUCTS.some(function (item) { return item.id === productId; })
      || typeof purchaseToken !== 'string' || purchaseToken.length < 16
      || !/^[a-f0-9]{64}$/.test(tokenHash)) return null;
    return {
      ok: true,
      verified: true,
      productId: productId,
      purchaseToken: purchaseToken,
      tokenHash: tokenHash,
      delivered: !!rawTransaction.delivered,
      recovered: billing.activeProductId !== productId
    };
  }
  function flushPurchaseDeliveries() {
    if (!billing.deliveryHandler) return;
    billing.deliveryQueue.forEach(function (delivery) {
      if (delivery.sentToHandler) return;
      delivery.sentToHandler = true;
      callback(billing.deliveryHandler, delivery);
    });
  }
  function queueVerifiedReceipt(receipt) {
    var delivery = receiptDelivery(receipt);
    if (!delivery) return;
    if (billing.receipts[delivery.tokenHash]) return;
    billing.receipts[delivery.tokenHash] = {
      receipt: receipt,
      delivery: delivery,
      completing: false
    };
    billing.deliveryQueue.push(delivery);
    flushPurchaseDeliveries();
    settlePurchase(delivery.productId, {
      ok: true,
      verified: true,
      productId: delivery.productId,
      tokenHash: delivery.tokenHash
    });
  }
  function priceRows() {
    if (!billing.store) return [];
    var Purchase = window.CdvPurchase;
    return PRODUCTS.map(function (registered) {
      var item = billing.store.get(registered.id, Purchase.Platform.GOOGLE_PLAY);
      var pricing = item && item.pricing;
      return {
        id: registered.id,
        available: !!(item && item.getOffer && item.getOffer() && pricing && pricing.price),
        price: pricing && pricing.price || '',
        currency: pricing && pricing.currency || '',
        priceMicros: pricing && Number(pricing.priceMicros) || 0,
        title: item && item.title || '',
        description: item && item.description || ''
      };
    });
  }

  function notifyBillingProducts() {
    try {
      if (typeof window.CustomEvent === 'function' && typeof window.dispatchEvent === 'function') {
        window.dispatchEvent(new window.CustomEvent('wildcardbillingproducts'));
      }
    } catch (e) {}
  }

  function waitForBillingReady(attempt) {
    attempt = Number(attempt) || 0;
    if (billing.ready) return Promise.resolve(true);
    if (!billing.enabled || attempt >= 24) return Promise.resolve(false);
    return new Promise(function (resolve) {
      setTimeout(function () {
        waitForBillingReady(attempt + 1).then(resolve);
      }, 250);
    });
  }

  function ownedProductIds() {
    var owned = [];
    var Purchase = window.CdvPurchase;
    if (!billing.store || !Purchase) return owned;
    try {
      PRODUCTS.forEach(function (product) {
        var item = billing.store.get(product.id, Purchase.Platform.GOOGLE_PLAY);
        if (item && item.owned) owned.push(product.id);
      });
    } catch (e) {}
    return owned;
  }

  function recoverPurchases() {
    if (!billing.enabled || !Cloud || typeof Cloud.authState !== 'function') {
      return Promise.resolve({
        signedIn: false,
        owned: ownedProductIds(),
        entitlements: null,
        products: priceRows()
      });
    }
    return Cloud.authState().then(rememberCloudAuth).then(function (state) {
      if (!state || !state.signedIn || !state.uid) {
        billing.accountUid = '';
        return {
          signedIn: false,
          owned: ownedProductIds(),
          entitlements: null,
          products: priceRows()
        };
      }
      billing.accountUid = String(state.uid);
      return waitForBillingReady(0).then(function (ready) {
        var restored = ready && billing.store && typeof billing.store.restorePurchases === 'function'
          ? billing.store.restorePurchases().catch(function () {})
          : Promise.resolve();
        return restored.then(function () {
          // Approved receipts are verified asynchronously. Re-open the
          // delivery queue whenever recovery is requested so a previous
          // transient save/backend failure can be retried.
          billing.deliveryQueue.forEach(function (delivery) {
            delivery.sentToHandler = false;
          });
          flushPurchaseDeliveries();
          if (typeof Cloud.getPlayEntitlements !== 'function') return null;
          return Cloud.getPlayEntitlements().catch(function () { return null; });
        }).then(function (entitlements) {
          return {
            signedIn: true,
            owned: ownedProductIds(),
            entitlements: entitlements,
            products: priceRows()
          };
        });
      });
    }).catch(function () {
      return {
        signedIn: false,
        owned: ownedProductIds(),
        entitlements: null,
        products: priceRows()
      };
    });
  }

  function initBilling() {
    var Purchase = window.CdvPurchase;
    billing.enabled = true;
    if (!Purchase || !Purchase.store || billing.ready || billing.initialising) {
      return billing.initialization || Promise.resolve(billing.ready);
    }
    var store = Purchase.store;
    billing.initialising = true;
    billing.store = store;

    try {
      store.register(PRODUCTS.map(function (product) {
        return {
          id: product.id,
          type: product.consumable ? Purchase.ProductType.CONSUMABLE : Purchase.ProductType.NON_CONSUMABLE,
          platform: Purchase.Platform.GOOGLE_PLAY
        };
      }));

      // Attach every order to the signed-in Firebase UID. The plugin's UUID
      // obfuscator passes a deterministic hash to setObfuscatedAccountId.
      store.applicationUsername = function () { return billing.accountUid || currentCloudUid || undefined; };
      store.obfuscator = 'uuid';
      store.validator_privacy_policy = ['fraud'];
      store.validator = function (body, done) {
        var productId = body && body.id;
        var purchaseToken = body && body.transaction && body.transaction.purchaseToken;
        if (!Cloud || typeof Cloud.verifyPlayPurchase !== 'function'
          || !PRODUCTS.some(function (item) { return item.id === productId; })
          || typeof purchaseToken !== 'string' || purchaseToken.length < 16) {
          validationFailure(done, 'Secure purchase verification is unavailable');
          return;
        }
        Cloud.verifyPlayPurchase({
          packageName: 'com.nisarg.wildcard',
          productId: productId,
          purchaseToken: purchaseToken
        }).then(function (result) {
          if (!result || !result.valid || result.productId !== productId
            || !/^[a-f0-9]{64}$/.test(String(result.tokenHash || ''))) {
            validationFailure(done, 'Google Play did not verify this purchase');
            return;
          }
          done(validatorResponse(body, result));
        }).catch(function () {
          validationFailure(done, 'Google Play verification is unavailable');
        });
      };

      store.when()
        .productUpdated(notifyBillingProducts)
        .approved(function (transaction) { transaction.verify(); })
        .pending(function (transaction) {
          var ids = transactionProductIds(transaction);
          var productId = billing.activeProductId;
          if (productId && ids.indexOf(productId) !== -1) {
            settlePurchase(productId, {
              ok: false,
              pending: true,
              productId: productId,
              reason: 'pending'
            });
          }
        })
        .verified(queueVerifiedReceipt)
        .unverified(function (failure) {
          var ids = verifiedProductIds(failure && failure.receipt);
          var productId = billing.activeProductId;
          if (productId && ids.indexOf(productId) !== -1) {
            settlePurchase(productId, {
              ok: false,
              productId: productId,
              reason: 'verification_failed'
            });
          }
        })
        .receiptsVerified(function () {
          flushPurchaseDeliveries();
        });

      billing.initialization = store.initialize([Purchase.Platform.GOOGLE_PLAY]).then(function () {
        billing.ready = true;
        billing.initialising = false;
        notifyBillingProducts();
        return true;
      }).catch(function () {
        billing.initialising = false;
        return false;
      });

      WN.purchase = function (productId, cb) {
        if (!billing.ready || billing.activeProductId || billing.orderStarting) {
          callback(cb, { ok: false, productId: productId || '', reason: 'billing_busy' });
          return;
        }
        var product = store.get(productId, Purchase.Platform.GOOGLE_PLAY);
        var offer = product && product.getOffer && product.getOffer();
        if (!offer || !Cloud || typeof Cloud.authState !== 'function') {
          callback(cb, { ok: false, productId: productId || '', reason: 'product_unavailable' });
          return;
        }
        billing.orderStarting = true;
        Cloud.authState().then(rememberCloudAuth).then(function (state) {
          if (!state || !state.signedIn || !state.uid) {
            billing.orderStarting = false;
            callback(cb, { ok: false, productId: productId, reason: 'sign_in_required' });
            return;
          }
          billing.accountUid = String(state.uid);
          billing.activeProductId = productId;
          billing.waiting[productId] = cb;
          return store.order(offer).then(function (err) {
            if (err) {
              settlePurchase(productId, {
                ok: false,
                productId: productId,
                reason: 'cancelled_or_unavailable'
              });
            }
          }).catch(function () {
            settlePurchase(productId, {
              ok: false,
              productId: productId,
              reason: 'cancelled_or_unavailable'
            });
          });
        }).catch(function () {
          billing.orderStarting = false;
          callback(cb, { ok: false, productId: productId, reason: 'sign_in_required' });
        });
      };

      WN.getBillingProducts = function () { return Promise.resolve(priceRows()); };

      WN.setPurchaseDeliveryHandler = function (handler) {
        billing.deliveryHandler = typeof handler === 'function' ? handler : null;
        flushPurchaseDeliveries();
      };

      WN.completePurchase = function (tokenHash, cb) {
        var entry = billing.receipts[tokenHash];
        if (!entry || entry.completing || !Cloud
          || typeof Cloud.markPlayPurchaseDelivered !== 'function') {
          callback(cb, false);
          return;
        }
        entry.completing = true;
        Cloud.markPlayPurchaseDelivered({
          packageName: 'com.nisarg.wildcard',
          productId: entry.delivery.productId,
          purchaseToken: entry.delivery.purchaseToken
        }).then(function (result) {
          if (!result || !result.delivered) throw new Error('Delivery was not recorded');
          return entry.receipt.finish();
        }).then(function () {
          delete billing.receipts[tokenHash];
          billing.deliveryQueue = billing.deliveryQueue.filter(function (item) {
            return item.tokenHash !== tokenHash;
          });
          callback(cb, true);
        }).catch(function () {
          entry.completing = false;
          callback(cb, false);
        });
      };

      WN.restorePurchases = function (cb) {
        recoverPurchases().then(function (report) { callback(cb, report); });
      };
      WN.refreshPurchases = recoverPurchases;
    } catch (e) {
      billing.initialising = false;
      billing.initialization = Promise.resolve(false);
    }
    return billing.initialization || Promise.resolve(false);
  }

  // Billing can query Play and Firebase, so it starts only after the mandatory
  // first-launch privacy gate has been accepted.
  WN.enableBillingAfterPolicyAcceptance = function () {
    return initBilling();
  };
})();

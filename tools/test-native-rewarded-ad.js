'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const bridgeSource = fs.readFileSync(
  path.join(__dirname, '..', 'www', 'native-bridge.js'),
  'utf8'
);
const indexSource = fs.readFileSync(
  path.join(__dirname, '..', 'www', 'index.html'),
  'utf8'
);
const androidBuildSource = fs.readFileSync(
  path.join(__dirname, '..', 'android', 'app', 'build.gradle'),
  'utf8'
);

async function flushPromises(rounds = 12) {
  for (let i = 0; i < rounds; i += 1) await Promise.resolve();
}

function baseContext(window) {
  return {
    window,
    document: { addEventListener() {} },
    console,
    Promise,
    setTimeout(fn) { fn(); return 0; },
    clearTimeout() {}
  };
}

async function createAdHarness(options = {}) {
  const listeners = Object.create(null);
  const calls = {
    prepareRewarded: 0,
    prepareInterstitial: 0,
    showRewarded: 0,
    showInterstitial: 0
  };
  const AdMob = {
    addListener(name, handler) {
      listeners[name] = handler;
      return Promise.resolve({ remove() {} });
    },
    initialize() { return Promise.resolve(); },
    requestConsentInfo() {
      return Promise.resolve({
        canRequestAds: true,
        status: 'OBTAINED',
        privacyOptionsRequirementStatus: 'NOT_REQUIRED'
      });
    },
    prepareRewardVideoAd() {
      calls.prepareRewarded += 1;
      return Promise.resolve();
    },
    prepareInterstitial() {
      calls.prepareInterstitial += 1;
      return Promise.resolve();
    },
    showRewardVideoAd() {
      calls.showRewarded += 1;
      return options.rejectShow
        ? Promise.reject(new Error('show rejected'))
        : Promise.resolve();
    },
    showInterstitial() {
      calls.showInterstitial += 1;
      return options.rejectInterstitialShow
        ? Promise.reject(new Error('interstitial show rejected'))
        : Promise.resolve();
    },
    showPrivacyOptionsForm() { return Promise.resolve(); },
    setApplicationMuted() { return Promise.resolve(); }
  };
  const Cloud = {
    serviceConfig() {
      return Promise.resolve({
        adsEnabled: true,
        adTesting: true,
        rewardedAdId: 'ca-app-pub-3940256099942544/5224354917',
        interstitialAdId: 'ca-app-pub-3940256099942544/1033173712'
      });
    }
  };
  const window = {
    Capacitor: {
      isNativePlatform() { return true; },
      Plugins: { AdMob, WildcardCloud: Cloud }
    }
  };
  vm.runInNewContext(bridgeSource, baseContext(window), {
    filename: 'www/native-bridge.js'
  });
  await window.WildcardNative.enableAdsAfterPolicyAcceptance();
  await flushPromises();
  assert.equal(calls.prepareRewarded, 1, 'consent should prepare rewarded');
  assert.equal(calls.prepareInterstitial, 1, 'consent should prepare interstitial');
  listeners.onRewardedVideoAdLoaded();
  return {
    WN: window.WildcardNative,
    calls,
    emit(name) {
      assert.equal(typeof listeners[name], 'function', `missing listener: ${name}`);
      listeners[name]();
    }
  };
}

async function createBillingHarness(options = {}) {
  const handlers = Object.create(null);
  const calls = {
    registered: [],
    ordered: [],
    restored: 0,
    verified: [],
    delivered: []
  };
  const chain = {};
  [
    'productUpdated',
    'approved',
    'pending',
    'verified',
    'unverified',
    'receiptsVerified'
  ].forEach(name => {
    chain[name] = handler => {
      handlers[name] = handler;
      return chain;
    };
  });
  const products = Object.create(null);
  const store = {
    register(rows) {
      calls.registered = rows;
      rows.forEach((row, index) => {
        products[row.id] = {
          id: row.id,
          title: `Title ${row.id}`,
          description: `Description ${row.id}`,
          pricing: {
            price: index === 0 ? '$0.99' : `$${index + 1}.99`,
            currency: 'USD',
            priceMicros: (index + 1) * 1000000
          },
          getOffer() { return options.missingOffer ? null : { productId: row.id }; },
          owned: row.id === 'remove_ads' && !!options.removeAdsOwned
        };
      });
    },
    when() { return chain; },
    initialize() { return Promise.resolve(); },
    get(productId) { return products[productId] || null; },
    order(offer) {
      calls.ordered.push(offer.productId);
      if (options.rejectOrder) return Promise.reject(new Error('order rejected'));
      return Promise.resolve(options.orderError);
    },
    restorePurchases() {
      calls.restored += 1;
      return Promise.resolve();
    }
  };
  const Cloud = {
    serviceConfig() { return Promise.resolve({ adsEnabled: false }); },
    authState() {
      return Promise.resolve(options.signedOut
        ? { signedIn: false }
        : { signedIn: true, uid: 'firebase-user-123' });
    },
    verifyPlayPurchase(input) {
      calls.verified.push(input);
      return Promise.resolve({
        valid: true,
        productId: input.productId,
        tokenHash: options.tokenHash || 'a'.repeat(64),
        delivered: !!options.alreadyDelivered,
        consumed: false
      });
    },
    markPlayPurchaseDelivered(input) {
      calls.delivered.push(input);
      return Promise.resolve({ delivered: true });
    },
    getPlayEntitlements() {
      return Promise.resolve(options.entitlements || {
        authoritative: true,
        noAds: false,
        purchases: [],
        unresolved: []
      });
    }
  };
  const Purchase = {
    store,
    ProductType: {
      CONSUMABLE: 'consumable',
      NON_CONSUMABLE: 'non-consumable'
    },
    Platform: { GOOGLE_PLAY: 'google-play' },
    ErrorCode: { VERIFICATION_FAILED: 6778003 }
  };
  const dispatched = [];
  const window = {
    Capacitor: {
      isNativePlatform() { return true; },
      Plugins: { WildcardCloud: Cloud }
    },
    CdvPurchase: Purchase,
    CustomEvent: function CustomEvent(type) { this.type = type; },
    dispatchEvent(event) { dispatched.push(event.type); }
  };
  vm.runInNewContext(bridgeSource, baseContext(window), {
    filename: 'www/native-bridge.js'
  });
  await window.WildcardNative.enableBillingAfterPolicyAcceptance();
  await flushPromises();
  return {
    WN: window.WildcardNative,
    calls,
    handlers,
    store,
    dispatched,
    emit(name, value) {
      assert.equal(typeof handlers[name], 'function', `missing handler: ${name}`);
      handlers[name](value);
    }
  };
}

function verifiedReceipt(productId, events = [], options = {}) {
  const tokenHash = options.tokenHash || 'a'.repeat(64);
  const purchaseToken = options.purchaseToken || 'play-purchase-token-1234567890';
  return {
    collection: [{ id: productId }],
    sourceReceipt: {
      purchaseToken,
      transactions: [{
        purchaseId: purchaseToken,
        products: [{ id: productId }]
      }]
    },
    raw: {
      id: tokenHash,
      transaction: {
        tokenHash,
        purchaseToken,
        delivered: !!options.delivered
      }
    },
    finish() {
      events.push('finish');
      return Promise.resolve();
    }
  };
}

function createUnavailableBillingHarness() {
  const window = {
    Capacitor: {
      isNativePlatform() { return true; },
      Plugins: {}
    }
  };
  vm.runInNewContext(bridgeSource, baseContext(window), {
    filename: 'www/native-bridge.js'
  });
  return window.WildcardNative;
}

async function testRewardedAndInterstitialSettleOnce() {
  const h = await createAdHarness();
  const rewarded = [];
  h.WN.showRewardedAd(value => rewarded.push(value));
  h.emit('onRewardedVideoAdReward');
  h.emit('onRewardedVideoAdReward');
  h.emit('onRewardedVideoAdDismissed');
  assert.deepEqual(rewarded, [true]);
  assert.equal(h.calls.showRewarded, 1);
  assert.equal(h.calls.prepareRewarded, 2);

  const interstitial = [];
  h.emit('interstitialAdLoaded');
  h.WN.showInterstitial(value => interstitial.push(value));
  h.emit('interstitialAdDismissed');
  h.emit('interstitialAdDismissed');
  assert.deepEqual(interstitial, [true]);
  assert.equal(h.calls.showInterstitial, 1);
  assert.equal(h.calls.prepareInterstitial, 2);
}

async function testAdFailuresRemainFailClosed() {
  const h = await createAdHarness({
    rejectShow: true,
    rejectInterstitialShow: true
  });
  const rewarded = [];
  h.WN.showRewardedAd(value => rewarded.push(value));
  await flushPromises();
  assert.deepEqual(rewarded, [false]);

  const interstitial = [];
  h.emit('interstitialAdLoaded');
  h.WN.showInterstitial(value => interstitial.push(value));
  await flushPromises();
  assert.deepEqual(interstitial, [false]);
}

async function testBillingUsesLocalizedPlayMetadata() {
  const h = await createBillingHarness();
  const rows = await h.WN.getBillingProducts();
  assert.equal(rows.length, 6);
  assert.equal(rows[0].id, 'coins_250');
  assert.equal(rows[0].price, '$0.99');
  assert.equal(rows[0].currency, 'USD');
  assert.equal(rows.every(row => row.available), true);
}

async function testVerifiedDeliveryMustBePersistedBeforeFinish() {
  const h = await createBillingHarness();
  const events = [];
  const checkout = [];
  h.WN.setPurchaseDeliveryHandler(delivery => {
    events.push(`delivery:${delivery.productId}`);
    // Deliberately do not complete here: verification alone must not consume,
    // acknowledge or grant anything.
  });
  h.WN.purchase('coins_250', result => checkout.push(result));
  await flushPromises();
  assert.deepEqual(h.calls.ordered, ['coins_250']);

  const receipt = verifiedReceipt('coins_250', events);
  h.emit('verified', receipt);
  h.emit('verified', receipt);
  await flushPromises();

  assert.equal(events.filter(value => value === 'delivery:coins_250').length, 1);
  assert.equal(events.includes('finish'), false);
  assert.equal(checkout.length, 1);
  assert.equal(checkout[0].ok, true);

  const completed = [];
  h.WN.completePurchase('a'.repeat(64), value => completed.push(value));
  await flushPromises();
  assert.deepEqual(completed, [true]);
  assert.deepEqual(h.calls.delivered.map(row => row.productId), ['coins_250']);
  assert.equal(events.at(-1), 'finish');
}

async function testRecoveredReceiptAndBackendEntitlementsAreReported() {
  const entitlements = {
    authoritative: true,
    noAds: true,
    purchases: [{
      productId: 'remove_ads',
      tokenHash: 'b'.repeat(64),
      delivered: true
    }],
    unresolved: []
  };
  const h = await createBillingHarness({ entitlements, removeAdsOwned: true });
  const deliveries = [];
  h.WN.setPurchaseDeliveryHandler(row => deliveries.push(row));
  h.emit('verified', verifiedReceipt('remove_ads', [], {
    tokenHash: 'b'.repeat(64),
    delivered: true
  }));
  const report = await h.WN.refreshPurchases();
  await flushPromises();
  assert.equal(deliveries.length >= 1, true);
  assert.equal(deliveries.every(row => row.recovered === true), true);
  assert.equal(
    new Set(deliveries.map(row => row.tokenHash)).size,
    1,
    'recovery retries must retain one stable idempotency token'
  );
  assert.equal(Array.from(report.owned).join(','), 'remove_ads');
  assert.equal(report.entitlements.noAds, true);
  assert.equal(h.calls.restored, 1);
}

async function testPendingAndOverlappingOrdersFailClosed() {
  const h = await createBillingHarness();
  const first = [];
  const second = [];
  h.WN.purchase('coins_1600', value => first.push(value));
  h.WN.purchase('coins_3600', value => second.push(value));
  await flushPromises();
  assert.equal(second.length, 1);
  assert.equal(second[0].reason, 'billing_busy');
  assert.deepEqual(h.calls.ordered, ['coins_1600']);

  h.emit('pending', { products: [{ id: 'coins_1600' }] });
  assert.equal(first.length, 1);
  assert.equal(first[0].pending, true);

  const unavailable = createUnavailableBillingHarness();
  const unavailableResult = [];
  unavailable.purchase('coins_250', value => unavailableResult.push(value));
  assert.equal(unavailableResult[0].reason, 'billing_unavailable');
}

async function testValidatorCallsTrustedBackend() {
  const h = await createBillingHarness();
  const responses = [];
  h.store.validator({
    id: 'coins_250',
    transaction: {
      type: 'android-playstore',
      id: 'GPA.1234',
      purchaseToken: 'play-purchase-token-1234567890'
    }
  }, response => responses.push(response));
  await flushPromises();
  assert.equal(h.calls.verified.length, 1);
  assert.equal(responses.length, 1);
  assert.equal(responses[0].ok, true);
  assert.equal(
    responses[0].data.collection[0].transactionId,
    'GPA.1234',
    'verified purchase must match the native transaction'
  );
}

function testShippedGameUsesOnlyDurablePaidGrantPath() {
  assert.doesNotMatch(
    indexSource,
    /fetchDailyRequest\('\/api\/daily',\s*\{method:'POST'/,
    'the public Pi Daily endpoint must remain read-only to the app'
  );
  assert.match(
    indexSource,
    /WN\.cloudSubmitDailyScore\(\{/,
    'Daily writes must use the authenticated callable bridge'
  );
  assert.match(
    indexSource,
    /const retainedPurchaseClaims=validPurchaseClaims\(account\.purchaseClaims\)/,
    'Reset Progress must retain durable purchase claims'
  );
  assert.match(
    indexSource,
    /btn\.textContent=isNativeShell\(\)\?\(playProduct&&playProduct\.available\?playProduct\.price:'Unavailable'\):'£'/,
    'native checkout must render Google Play localized prices'
  );
  assert.doesNotMatch(
    indexSource,
    /WN\.purchase\('coins_'\+b\.coins,[^}]*grantCoins/,
    'a checkout callback must never grant coins directly'
  );
  assert.match(
    androidBuildSource,
    /ownedAdmobAppId = 'ca-app-pub-3855192091371080~7622357185'/,
    'public Android variants must carry the owner-created AdMob app ID'
  );
  assert.match(
    androidBuildSource,
    /ownedRewardedAdId = 'ca-app-pub-3855192091371080\/3551964243'/,
    'public Android variants must carry the owner-created rewarded unit'
  );
  assert.match(
    androidBuildSource,
    /ownedInterstitialAdId = 'ca-app-pub-3855192091371080\/2034300223'/,
    'public Android variants must carry the owner-created interstitial unit'
  );
  assert.match(
    androidBuildSource,
    /buildConfigField "boolean", "WILDCARD_ADS_ENABLED", productionAdsReady\.toString\(\)/,
    'release ads must be enabled only when the owner app and both unit IDs validate'
  );
  assert.doesNotMatch(
    androidBuildSource,
    /wildcardAdmobAppId: productionAdsReady \? productionAdmobAppId : googleDemoAdmobAppId/,
    'public release must never fall back to Google’s demonstration app ID'
  );
}

async function main() {
  await testRewardedAndInterstitialSettleOnce();
  await testAdFailuresRemainFailClosed();
  await testBillingUsesLocalizedPlayMetadata();
  await testVerifiedDeliveryMustBePersistedBeforeFinish();
  await testRecoveredReceiptAndBackendEntitlementsAreReported();
  await testPendingAndOverlappingOrdersFailClosed();
  await testValidatorCallsTrustedBackend();
  testShippedGameUsesOnlyDurablePaidGrantPath();
  console.log('Native ads and trusted Play Billing tests passed.');
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});

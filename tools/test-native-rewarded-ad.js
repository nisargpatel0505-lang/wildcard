'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const bridgeSource = fs.readFileSync(
  path.join(__dirname, '..', 'www', 'native-bridge.js'),
  'utf8'
);

async function flushPromises() {
  for (let i = 0; i < 6; i += 1) await Promise.resolve();
}

async function createHarness(options) {
  options = options || {};
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
      if (options.rejectShow) return Promise.reject(new Error('show rejected'));
      return Promise.resolve();
    },
    showInterstitial() {
      calls.showInterstitial += 1;
      if (options.rejectInterstitialShow) {
        return Promise.reject(new Error('interstitial show rejected'));
      }
      return Promise.resolve();
    },
    showPrivacyOptionsForm() { return Promise.resolve(); },
    setApplicationMuted() { return Promise.resolve(); }
  };

  const window = {
    Capacitor: {
      isNativePlatform() { return true; },
      Plugins: { AdMob }
    }
  };
  const context = {
    window,
    document: { addEventListener() {} },
    console,
    Promise,
    setTimeout() { return 0; },
    clearTimeout() {}
  };

  vm.runInNewContext(bridgeSource, context, { filename: 'www/native-bridge.js' });
  await flushPromises();
  assert.equal(calls.prepareRewarded, 1, 'consent should prepare the first rewarded ad');
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

async function createBillingHarness(options) {
  options = options || {};
  const documentListeners = Object.create(null);
  const purchaseHandlers = Object.create(null);
  const calls = {
    registered: [],
    ordered: []
  };
  const chain = {
    approved(handler) {
      purchaseHandlers.approved = handler;
      return chain;
    },
    verified(handler) {
      purchaseHandlers.verified = handler;
      return chain;
    }
  };
  const store = {
    register(products) { calls.registered = products; },
    when() { return chain; },
    initialize() { return Promise.resolve(); },
    get(productId) {
      if (options.missingOffer) return null;
      return {
        id: productId,
        getOffer() { return { productId }; },
        owned: false
      };
    },
    order(offer) {
      calls.ordered.push(offer.productId);
      if (options.rejectOrder) return Promise.reject(new Error('order rejected'));
      return Promise.resolve(options.orderError || undefined);
    },
    restorePurchases() { return Promise.resolve(); }
  };
  const Purchase = {
    store,
    ProductType: {
      CONSUMABLE: 'consumable',
      NON_CONSUMABLE: 'non-consumable'
    },
    Platform: { GOOGLE_PLAY: 'google-play' }
  };
  const window = {
    Capacitor: {
      isNativePlatform() { return true; },
      Plugins: {}
    },
    CdvPurchase: Purchase
  };
  const context = {
    window,
    document: {
      addEventListener(name, handler) { documentListeners[name] = handler; }
    },
    console,
    Promise,
    setTimeout() { return 0; },
    clearTimeout() {}
  };

  vm.runInNewContext(bridgeSource, context, { filename: 'www/native-bridge.js' });
  assert.equal(typeof documentListeners.deviceready, 'function', 'billing should wait for deviceready');
  documentListeners.deviceready();
  await flushPromises();

  return {
    WN: window.WildcardNative,
    calls,
    emitVerified(receipt) {
      assert.equal(typeof purchaseHandlers.verified, 'function', 'missing verified handler');
      purchaseHandlers.verified(receipt);
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
  const context = {
    window,
    document: { addEventListener() {} },
    console,
    Promise,
    setTimeout() { return 0; },
    clearTimeout() {}
  };
  vm.runInNewContext(bridgeSource, context, { filename: 'www/native-bridge.js' });
  return window.WildcardNative;
}

async function testRewardSettlesImmediatelyAndOnlyOnce() {
  const h = await createHarness();
  const results = [];

  h.WN.showRewardedAd((value) => results.push(value));
  assert.deepEqual(results, [], 'showing an ad must not resolve before an SDK event');

  h.emit('onRewardedVideoAdReward');
  assert.deepEqual(results, [true], 'reward event must settle success immediately');

  const overlappingResult = [];
  h.WN.showRewardedAd((value) => overlappingResult.push(value));
  assert.deepEqual(overlappingResult, [false], 'reward settlement must not reopen the ad before dismissal');
  assert.equal(h.calls.showRewarded, 1, 'only one rewarded ad may be in flight');

  h.emit('onRewardedVideoAdReward');
  h.emit('onRewardedVideoAdDismissed');
  h.emit('onRewardedVideoAdDismissed');
  h.emit('onRewardedVideoAdFailedToShow');
  assert.deepEqual(results, [true], 'duplicate/late events must not settle again');
  assert.equal(h.calls.prepareRewarded, 2, 'dismissal should prepare exactly one replacement ad');
}

async function testDismissWithoutRewardSettlesFalseOnce() {
  const h = await createHarness();
  const results = [];

  h.WN.showRewardedAd((value) => results.push(value));
  h.emit('onRewardedVideoAdDismissed');
  h.emit('onRewardedVideoAdFailedToShow');

  assert.deepEqual(results, [false], 'dismissal without a reward must fail once');
  assert.equal(h.calls.prepareRewarded, 2, 'dismissal should prepare the next ad');
}

async function testFailedToShowSettlesFalseOnce() {
  const h = await createHarness();
  const results = [];

  h.WN.showRewardedAd((value) => results.push(value));
  h.emit('onRewardedVideoAdFailedToShow');
  h.emit('onRewardedVideoAdDismissed');

  assert.deepEqual(results, [false], 'failed-to-show must fail once');
  assert.equal(h.calls.prepareRewarded, 2, 'failed-to-show should prepare the next ad');
}

async function testShowPromiseRejectionSettlesFalseOnce() {
  const h = await createHarness({ rejectShow: true });
  const results = [];

  h.WN.showRewardedAd((value) => results.push(value));
  await flushPromises();
  h.emit('onRewardedVideoAdFailedToShow');

  assert.deepEqual(results, [false], 'show promise rejection must fail once');
  assert.equal(h.calls.prepareRewarded, 2, 'show rejection should prepare the next ad');
}

async function testInterstitialDismissSettlesTrueOnce() {
  const h = await createHarness();
  const results = [];

  assert.equal(h.calls.prepareInterstitial, 1, 'consent should prepare the first interstitial');
  h.emit('interstitialAdLoaded');
  h.WN.showInterstitial((value) => results.push(value));

  assert.equal(h.calls.showInterstitial, 1, 'a loaded interstitial should be shown once');
  assert.deepEqual(results, [], 'showing an interstitial must wait for an SDK event');

  h.emit('interstitialAdDismissed');
  h.emit('interstitialAdDismissed');
  h.emit('interstitialAdFailedToShow');

  assert.deepEqual(results, [true], 'dismissal must settle success exactly once');
  assert.equal(h.calls.prepareInterstitial, 2, 'dismissal should prepare exactly one replacement');
}

async function testUnavailableInterstitialSettlesFalseWithoutShowing() {
  const h = await createHarness();
  const results = [];

  h.WN.showInterstitial((value) => results.push(value));

  assert.deepEqual(results, [false], 'an unavailable interstitial must fail immediately');
  assert.equal(h.calls.showInterstitial, 0, 'an unavailable interstitial must not call show');
  assert.equal(
    h.calls.prepareInterstitial,
    1,
    'an unavailable request must not duplicate an in-progress prepare'
  );
}

async function testInterstitialFailedToShowSettlesFalseOnce() {
  const h = await createHarness();
  const results = [];

  h.emit('interstitialAdLoaded');
  h.WN.showInterstitial((value) => results.push(value));
  h.emit('interstitialAdFailedToShow');
  h.emit('interstitialAdFailedToShow');
  h.emit('interstitialAdDismissed');

  assert.deepEqual(results, [false], 'interstitial failed-to-show must fail exactly once');
  assert.equal(h.calls.showInterstitial, 1, 'failed-to-show must have only one show request');
  assert.equal(h.calls.prepareInterstitial, 2, 'failed-to-show should prepare one replacement');
}

async function testInterstitialShowRejectionSettlesFalseOnce() {
  const h = await createHarness({ rejectInterstitialShow: true });
  const results = [];

  h.emit('interstitialAdLoaded');
  h.WN.showInterstitial((value) => results.push(value));
  await flushPromises();
  h.emit('interstitialAdFailedToShow');
  h.emit('interstitialAdDismissed');

  assert.deepEqual(results, [false], 'interstitial show rejection must fail exactly once');
  assert.equal(h.calls.showInterstitial, 1, 'a rejected show promise must not retry show');
  assert.equal(h.calls.prepareInterstitial, 2, 'show rejection should prepare one replacement');
}

async function testOverlappingInterstitialRequestsDoNotShowTwice() {
  const h = await createHarness();
  const first = [];
  const second = [];

  h.emit('interstitialAdLoaded');
  h.WN.showInterstitial((value) => first.push(value));
  h.WN.showInterstitial((value) => second.push(value));

  assert.deepEqual(first, [], 'the first interstitial request should remain in flight');
  assert.deepEqual(second, [false], 'an overlapping interstitial request must fail closed');
  assert.equal(h.calls.showInterstitial, 1, 'overlapping requests must not trigger a second show');

  h.emit('interstitialAdDismissed');
  h.emit('interstitialAdDismissed');

  assert.deepEqual(first, [true], 'the original request should settle once when dismissed');
  assert.equal(h.calls.prepareInterstitial, 2, 'completion should prepare one replacement');
}

async function testVerifiedCollectionDeliversBeforeFinishOnce() {
  const h = await createBillingHarness();
  const events = [];

  h.WN.purchase('coins_250', (value) => events.push(`callback:${value}`));
  await flushPromises();
  assert.deepEqual(h.calls.ordered, ['coins_250'], 'purchase should order the selected Play product');

  const receipt = {
    collection: [{ id: 'coins_250' }],
    sourceReceipt: { transactions: [] },
    finish() {
      events.push('finish');
      return Promise.resolve();
    }
  };
  h.emitVerified(receipt);
  h.emitVerified(receipt);
  await flushPromises();

  assert.deepEqual(
    events,
    ['callback:true', 'finish'],
    'v13 collection delivery must precede finish and repeated verified events must not re-grant'
  );
}

async function testVerifiedSourceTransactionsFallback() {
  const h = await createBillingHarness();
  const events = [];

  h.WN.purchase('remove_ads', (value) => events.push(`callback:${value}`));
  await flushPromises();
  h.emitVerified({
    collection: [],
    sourceReceipt: {
      transactions: [{ products: [{ id: 'remove_ads' }] }]
    },
    finish() {
      events.push('finish');
      return Promise.resolve();
    }
  });
  await flushPromises();

  assert.deepEqual(
    events,
    ['callback:true', 'finish'],
    'v13 sourceReceipt transactions should deliver the matching product before finish'
  );
}

async function testVerifiedUnrelatedReceiptDoesNotGrantOrFinish() {
  const h = await createBillingHarness();
  const results = [];
  let finishCount = 0;

  h.WN.purchase('coins_600', (value) => results.push(value));
  await flushPromises();
  h.emitVerified({
    collection: [{ id: 'coins_250' }],
    sourceReceipt: { transactions: [] },
    finish() {
      finishCount += 1;
      return Promise.resolve();
    }
  });

  assert.deepEqual(results, [], 'an unrelated receipt must not grant the active purchase');
  assert.equal(finishCount, 0, 'an undelivered receipt must not be finished by this bridge');
}

async function testBillingSerializesOrdersAndFailsClosedWhenUnavailable() {
  const h = await createBillingHarness();
  const first = [];
  const second = [];

  h.WN.purchase('coins_1600', (value) => first.push(value));
  h.WN.purchase('coins_3600', (value) => second.push(value));
  await flushPromises();

  assert.deepEqual(first, [], 'the active order should remain pending verification');
  assert.deepEqual(second, [false], 'a second simultaneous order must fail closed');
  assert.deepEqual(h.calls.ordered, ['coins_1600'], 'only one Play order may be active');

  const unavailable = createUnavailableBillingHarness();
  const unavailableResult = [];
  unavailable.purchase('coins_250', (value) => unavailableResult.push(value));
  assert.deepEqual(unavailableResult, [false], 'native billing without the Play plugin must never grant');
}

async function main() {
  await testRewardSettlesImmediatelyAndOnlyOnce();
  await testDismissWithoutRewardSettlesFalseOnce();
  await testFailedToShowSettlesFalseOnce();
  await testShowPromiseRejectionSettlesFalseOnce();
  await testInterstitialDismissSettlesTrueOnce();
  await testUnavailableInterstitialSettlesFalseWithoutShowing();
  await testInterstitialFailedToShowSettlesFalseOnce();
  await testInterstitialShowRejectionSettlesFalseOnce();
  await testOverlappingInterstitialRequestsDoNotShowTwice();
  await testVerifiedCollectionDeliversBeforeFinishOnce();
  await testVerifiedSourceTransactionsFallback();
  await testVerifiedUnrelatedReceiptDoesNotGrantOrFinish();
  await testBillingSerializesOrdersAndFailsClosedWhenUnavailable();
  console.log('Native rewarded/interstitial-ad and billing callback tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

"use strict";
const assert = require("node:assert/strict");
const test = require("node:test");
const {__test: b} = require("../billing.js");
const token = "test-only-token-never-a-real-purchase";

function fixture(productId = "coins_250", protocol = 2) {
  const input = {productId, purchaseToken: token, deliveryProtocol: 2};
  const playPurchase = {purchaseStateContext: {purchaseState: "PURCHASED"},
    obfuscatedExternalAccountId: b.obfuscatedAccountId("player"),
    productLineItem: [{productId, productOfferDetails: {}}]};
  const records = new Map([
    ["receipt", {uid: "player", productId, status: "verified", deliveryProtocol: protocol}],
    ["save", {accountJson: JSON.stringify({coins: 100, best: 88}), runJson: "saved-run",
      saveVersion: 8, progressVersion: 7, billingAdjustmentApplied: 0}],
    ["account", {coinAdjustmentTotal: 0}],
  ]);
  async function fulfill(overrides = {}) {
    const staged = [];
    const result = await b.applyFulfillment({
      get: async (ref) => ({exists: records.has(ref), data: () => records.get(ref)}),
      set: (ref, value, options) => staged.push([ref, value, options]),
    }, {uid: "player", input, playPurchase, expectedProgressVersion: 7,
      purchaseRef: "receipt", saveRef: "save", accountRef: "account", ...overrides});
    // Firestore commits the staged operations together, never before callback success.
    for (const [ref, value, options] of staged) {
      records.set(ref, options?.merge ? {...records.get(ref), ...value} : value);
    }
    return result;
  }
  return {records, input, playPurchase, fulfill};
}

test("grant and delivered ledger commit together, advancing both CAS versions", async () => {
  const f = fixture();
  const result = await f.fulfill();
  assert.equal(result.coinDelta, 250);
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 350);
  assert.equal(JSON.parse(f.records.get("save").accountJson).best, 88);
  assert.equal(f.records.get("save").runJson, "saved-run");
  assert.equal(f.records.get("save").progressVersion, 8);
  assert.equal(f.records.get("save").saveVersion, 9);
  assert.equal(f.records.get("receipt").status, "delivered");
  assert.equal(result.lastBillingTokenHash, b.hashToken(token));
  assert.equal(result.lastBillingBaseProgressVersion, 7);
  assert.equal(result.lastBillingCoinDelta, 250);
  assert.equal("noAds" in result, false);
});

test("lost response/replay credits exactly once", async () => {
  const f = fixture();
  await f.fulfill(); // First response is lost to the device.
  const replay = await f.fulfill({expectedProgressVersion: 8});
  assert.equal(replay.alreadyDelivered, true);
  assert.equal(replay.coinDelta, 0);
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 350);
  assert.equal(f.records.get("save").progressVersion, 8);
});

test("stale/concurrent device cannot overwrite or double-grant a paid revision", async () => {
  const f = fixture();
  await f.fulfill();
  await assert.rejects(f.fulfill(), {code: "aborted"});
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 350);
});

test("legacy delivered purchases never receive another grant", async () => {
  const f = fixture("coins_250", 1);
  f.records.get("receipt").status = "delivered";
  const result = await f.fulfill();
  assert.equal(result.coinDelta, 0);
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 100);
});

test("ambiguous legacy pending delivery is held for support, not re-credited", async () => {
  const f = fixture("coins_250", 1);
  await assert.rejects(f.fulfill(), {code: "failed-precondition"});
  assert.equal(f.records.get("receipt").status, "verified");
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 100);
});

for (const state of ["PENDING", "CANCELLED", "UNKNOWN"]) {
  test(`Play ${state} never grants or writes a receipt`, async () => {
    const f = fixture();
    f.playPurchase.purchaseStateContext.purchaseState = state;
    await assert.rejects(f.fulfill(), {code: "failed-precondition"});
    assert.equal(f.records.get("receipt").status, "verified");
    assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 100);
  });
}

test("Play owner, token ledger owner and product must all match", async () => {
  const f = fixture();
  await assert.rejects(f.fulfill({uid: "other"}), {code: "permission-denied"});
  f.records.get("receipt").uid = "other";
  await assert.rejects(f.fulfill(), {code: "permission-denied"});
  f.records.get("receipt").uid = "player";
  f.playPurchase.productLineItem[0].productId = "coins_600";
  await assert.rejects(f.fulfill(), {code: "failed-precondition"});
});

test("refund arriving after verification prevents atomic delivery", async () => {
  const f = fixture();
  f.records.get("receipt").status = "revoked";
  await assert.rejects(f.fulfill(), {code: "failed-precondition"});
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 100);
});

test("a protocol2 reservation refund cannot confiscate earned coins", () => {
  assert.equal(b.shouldCreateCoinAdjustment({uid: "player", productId: "coins_250",
    status: "verified", deliveryProtocol: 2}), false);
  assert.equal(b.shouldCreateCoinAdjustment({uid: "player", productId: "coins_250",
    status: "delivered", deliveryProtocol: 2}), true);
});

test("grant applies existing refund debt in the same transaction", async () => {
  const f = fixture();
  f.records.get("account").coinAdjustmentTotal = 200;
  const result = await f.fulfill();
  assert.equal(result.coinDelta, 50);
  assert.equal(JSON.parse(f.records.get("save").accountJson).coins, 150);
  assert.equal(f.records.get("save").billingAdjustmentApplied, 200);
});

test("Remove Ads grants the entitlement without inventing currency", async () => {
  const f = fixture("remove_ads");
  const result = await f.fulfill();
  assert.equal(result.noAds, true);
  assert.equal(result.coinDelta, 0);
  assert.equal(f.records.get("receipt").status, "delivered");
});

test("legacy delivery APIs cannot bypass protocol2 atomic fulfillment", () => {
  assert.throws(() => b.assertDeliveryProtocol({deliveryProtocol: 2}, {deliveryProtocol: 1}),
      {code: "failed-precondition"});
  assert.doesNotThrow(() => b.assertDeliveryProtocol({deliveryProtocol: 1}, {deliveryProtocol: 1}));
});

test("already-consumed undelivered or full-wallet purchases fail without losses", async () => {
  const f = fixture();
  f.playPurchase.productLineItem[0].productOfferDetails.consumptionState = "CONSUMPTION_STATE_CONSUMED";
  await assert.rejects(f.fulfill(), {code: "failed-precondition"});
  f.playPurchase.productLineItem[0].productOfferDetails = {};
  f.records.get("save").accountJson = '{"coins":9999999}';
  await assert.rejects(f.fulfill(), {code: "resource-exhausted"});
  assert.equal(f.records.get("receipt").status, "verified");
});

for (const productId of ["remove_ads", "coins_250"]) {
test(`entitlement/RTDN refresh cannot regress a concurrently fulfilled or revoked ${productId}`, async () => {
  const f = fixture(productId);
  await f.fulfill(); // The earlier entitlement query had seen 'verified'.
  let writes = 0;
  const transaction = {
    get: async (ref) => ({data: () => f.records.get(ref)}),
    set: (ref, value) => {
      writes++;
      f.records.set(ref, {...f.records.get(ref), ...value});
    },
  };
  const args = {ref: "receipt", uid: "player", productId,
    playPurchase: f.playPurchase};
  const refreshed = await b.applyEntitlementRefresh(transaction, args);
  assert.equal(refreshed.status, "delivered");
  assert.equal(f.records.get("receipt").status, "delivered");
  assert.equal(writes, 1);
  f.records.get("receipt").status = "revoked";
  const revoked = await b.applyEntitlementRefresh(transaction, args);
  assert.equal(revoked.status, "revoked");
  assert.equal(writes, 1);
});
}

test("every server wallet change advances both revisions, including refunds", () => {
  assert.deepEqual(b.nextCloudRevision({saveVersion: 8, progressVersion: 7}),
      {saveVersion: 9, progressVersion: 8});
  assert.deepEqual(b.nextCloudRevision({}), {saveVersion: 1, progressVersion: 1});
});

test("entitlement refresh respects deletion and fresh ownership, including NOT_FOUND", async () => {
  const f = fixture("remove_ads");
  let writes = 0;
  const transaction = {
    get: async (ref) => ({data: () => f.records.get(ref)}),
    set: (ref, value) => {
      writes++;
      f.records.set(ref, {...f.records.get(ref), ...value});
    },
  };
  const args = {ref: "receipt", uid: "player", productId: "remove_ads", notFound: true};
  f.records.get("receipt").uid = "deleted-owner";
  assert.equal(await b.applyEntitlementRefresh(transaction, args), null);
  f.records.delete("receipt");
  assert.equal(await b.applyEntitlementRefresh(transaction, args), null);
  assert.equal(writes, 0);
  f.records.set("receipt", {uid: "player", productId: "remove_ads", status: "delivered"});
  assert.equal((await b.applyEntitlementRefresh(transaction, args)).status, "revoked");
  assert.equal(writes, 1);
});

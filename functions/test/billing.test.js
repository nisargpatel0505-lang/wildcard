"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {__test} = require("../billing.js");

test("the public Play catalogue maps to explicit server grants", () => {
  assert.deepEqual(Object.keys(__test.PRODUCTS), [
    "coins_250",
    "coins_600",
    "coins_1600",
    "coins_3600",
    "coins_8500",
    "remove_ads",
  ]);
  assert.equal(__test.PRODUCTS.coins_8500.amount, 8500);
  assert.equal(__test.PRODUCTS.remove_ads.entitlement, "noAds");
});

test("purchase tokens use deterministic non-reversible ledger keys", () => {
  const token = "example-play-purchase-token";
  assert.equal(__test.hashToken(token), __test.hashToken(token));
  assert.notEqual(__test.hashToken(token), token);
  assert.match(__test.hashToken(token), /^[a-f0-9]{64}$/);
});

test("Firebase UIDs map to the plugin's deterministic Play account UUID", () => {
  const value = __test.obfuscatedAccountId("firebase-user-123");
  assert.match(
      value,
      /^[a-f0-9]{8}-[a-f0-9]{4}-3[a-f0-9]{3}-8[a-f0-9]{3}-[a-f0-9]{12}$/,
  );
  assert.equal(value, __test.obfuscatedAccountId("firebase-user-123"));
  assert.notEqual(value, __test.obfuscatedAccountId("another-user"));
});

test("v2 Play purchase state and line items are parsed fail closed", () => {
  const purchase = {
    purchaseStateContext: {purchaseState: "PURCHASED"},
    productLineItem: [{
      productId: "coins_250",
      productOfferDetails: {
        consumptionState: "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
      },
    }],
  };
  assert.equal(__test.playPurchaseState(purchase), "PURCHASED");
  assert.deepEqual(__test.purchasedProductIds(purchase), ["coins_250"]);
  assert.equal(__test.isConsumed(purchase, "coins_250"), false);
  assert.equal(__test.playPurchaseState({}), "UNKNOWN");
  assert.deepEqual(__test.purchasedProductIds({}), []);
});

test("durable entitlement state follows authoritative Play state", () => {
  const purchased = {
    purchaseStateContext: {purchaseState: "PURCHASED"},
    productLineItem: [{productId: "remove_ads"}],
  };
  assert.equal(
      __test.ledgerStatusAfterPlay(
          {status: "delivered"},
          "remove_ads",
          purchased,
      ),
      "delivered",
  );
  assert.equal(
      __test.ledgerStatusAfterPlay(
          {status: "verified"},
          "remove_ads",
          purchased,
      ),
      "verified",
  );
  assert.equal(
      __test.ledgerStatusAfterPlay(
          {status: "delivered"},
          "remove_ads",
          {
            purchaseStateContext: {purchaseState: "CANCELLED"},
            productLineItem: [{productId: "remove_ads"}],
          },
      ),
      "revoked",
  );
  assert.equal(
      __test.ledgerStatusAfterPlay(
          {status: "delivered"},
          "remove_ads",
          {
            purchaseStateContext: {purchaseState: "PURCHASED"},
            productLineItem: [{productId: "coins_250"}],
          },
      ),
      "revoked",
  );
});

test("cloud account blobs cannot assert paid-only state", () => {
  const sanitized = JSON.parse(__test.sanitizeCloudAccountJson(JSON.stringify({
    coins: 4321,
    noAds: true,
    purchaseClaims: {["a".repeat(64)]: {productId: "coins_250"}},
    paidCoins: 9999999,
    billingDebt: 0,
    billingAdjustmentApplied: 9999999,
    unlocked: ["pair_trainer"],
  })));
  assert.equal(sanitized.coins, 4321);
  assert.deepEqual(sanitized.unlocked, ["pair_trainer"]);
  __test.PROTECTED_CLOUD_ACCOUNT_FIELDS.forEach((field) => {
    assert.equal(
        Object.prototype.hasOwnProperty.call(sanitized, field),
        false,
        `${field} leaked into the user-writable cloud save`,
    );
  });
});

test("coin refund adjustments are cumulative, bounded and idempotent by cursor", () => {
  const first = __test.applyCoinAdjustment(
      JSON.stringify({coins: 300, unlocked: []}),
      250,
      0,
  );
  assert.equal(first.coinsAfter, 50);
  assert.equal(first.deducted, 250);
  assert.equal(first.applied, 250);
  assert.equal(first.outstanding, 0);

  const retry = __test.applyCoinAdjustment(
      first.accountJson,
      250,
      first.applied,
  );
  assert.equal(retry.coinsAfter, 50);
  assert.equal(retry.deducted, 0);
  assert.equal(retry.applied, 250);

  const partial = __test.applyCoinAdjustment(
      JSON.stringify({coins: 40}),
      250,
      0,
  );
  assert.equal(partial.coinsAfter, 0);
  assert.equal(partial.applied, 40);
  assert.equal(partial.outstanding, 210);

  const laterEarnings = __test.applyCoinAdjustment(
      JSON.stringify({coins: 100}),
      250,
      partial.applied,
  );
  assert.equal(laterEarnings.coinsAfter, 0);
  assert.equal(laterEarnings.applied, 140);
  assert.equal(laterEarnings.outstanding, 110);
});

test("only a server-authorised consumable revocation creates coin debt", () => {
  assert.equal(__test.shouldCreateCoinAdjustment({
    uid: "user-1",
    productId: "coins_600",
    status: "delivered",
  }), true);
  assert.equal(__test.shouldCreateCoinAdjustment({
    uid: "user-1",
    productId: "coins_600",
    status: "verified",
  }), true);
  assert.equal(__test.shouldCreateCoinAdjustment({
    uid: "user-1",
    productId: "coins_600",
    status: "pending",
  }), false);
  assert.equal(__test.shouldCreateCoinAdjustment({
    uid: "user-1",
    productId: "remove_ads",
    status: "delivered",
  }), false);
  assert.equal(__test.shouldCreateCoinAdjustment({
    productId: "coins_600",
    status: "delivered",
  }), false);
});

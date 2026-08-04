"use strict";

const crypto = require("node:crypto");
const {google} = require("googleapis");
const {getApp, getApps, initializeApp} = require("firebase-admin/app");
const {
  FieldValue,
  getFirestore,
} = require("firebase-admin/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {onMessagePublished} = require("firebase-functions/v2/pubsub");

const app = getApps().length ? getApp() : initializeApp();
const db = getFirestore(app);
const REGION = "europe-west2";
const PACKAGE_NAME = "com.nisarg.wildcard";
const RTDN_TOPIC = "wildcard-play-billing";
const MAX_SAVE_CHARS = 150000;
const MAX_COIN_BALANCE = 9999999;
const PROTECTED_CLOUD_ACCOUNT_FIELDS = Object.freeze([
  "noAds",
  "purchaseClaims",
  "paidCoins",
  "paidCoinBalance",
  "billingDebt",
  "billingAdjustments",
  "billingAdjustmentApplied",
  "billingAdjustmentTotal",
]);
const PRODUCTS = Object.freeze({
  coins_250: Object.freeze({kind: "coins", amount: 250}),
  coins_600: Object.freeze({kind: "coins", amount: 600}),
  coins_1600: Object.freeze({kind: "coins", amount: 1600}),
  coins_3600: Object.freeze({kind: "coins", amount: 3600}),
  coins_8500: Object.freeze({kind: "coins", amount: 8500}),
  remove_ads: Object.freeze({kind: "entitlement", entitlement: "noAds"}),
});

const publisherAuth = new google.auth.GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});
const publisher = google.androidpublisher({
  version: "v3",
  auth: publisherAuth,
});

function hashToken(token) {
  return crypto.createHash("sha256").update(token, "utf8").digest("hex");
}

function clampInteger(value, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) {
  const number = Math.floor(Number(value));
  if (!Number.isFinite(number)) return minimum;
  return Math.max(minimum, Math.min(maximum, number));
}

/**
 * Paid state is deliberately not part of the user-writable cloud-save blob.
 * The app may keep a local offline cache, but Google Play plus the protected
 * billing ledger are the only authority for grants and revocations.
 */
function sanitizeCloudAccountJson(accountJson) {
  if (typeof accountJson !== "string" ||
      accountJson.length > MAX_SAVE_CHARS) {
    throw new HttpsError("invalid-argument", "Cloud save is too large.");
  }
  let account;
  try {
    account = JSON.parse(accountJson || "{}");
  } catch {
    throw new HttpsError("invalid-argument", "Cloud account save is invalid.");
  }
  if (!account || typeof account !== "object" || Array.isArray(account)) {
    throw new HttpsError("invalid-argument", "Cloud account save is invalid.");
  }
  PROTECTED_CLOUD_ACCOUNT_FIELDS.forEach((field) => delete account[field]);
  account.coins = clampInteger(account.coins, 0, MAX_COIN_BALANCE);
  const sanitized = JSON.stringify(account);
  if (sanitized.length > MAX_SAVE_CHARS) {
    throw new HttpsError("invalid-argument", "Cloud save is too large.");
  }
  return sanitized;
}

function applyCoinAdjustment(accountJson, adjustmentTotal, alreadyApplied) {
  const sanitized = sanitizeCloudAccountJson(accountJson);
  const account = JSON.parse(sanitized);
  const total = clampInteger(adjustmentTotal);
  const appliedBefore = Math.min(total, clampInteger(alreadyApplied));
  const due = Math.max(0, total - appliedBefore);
  const coinsBefore = clampInteger(account.coins, 0, MAX_COIN_BALANCE);
  const deducted = Math.min(coinsBefore, due);
  account.coins = coinsBefore - deducted;
  return {
    accountJson: JSON.stringify(account),
    coinsBefore,
    coinsAfter: account.coins,
    deducted,
    applied: appliedBefore + deducted,
    outstanding: due - deducted,
  };
}

function cloudSaveRef(uid) {
  return db.collection("users").doc(uid).collection("saves").doc("main");
}

function billingAccountRef(uid) {
  return db.collection("billingAccounts").doc(uid);
}

function billingAdjustmentRef(tokenHash) {
  return db.collection("billingAdjustments").doc(tokenHash);
}

/**
 * cordova-plugin-purchase's recommended `uuid` obfuscator formats an MD5 hash
 * as a deterministic UUIDv3-like value before BillingClient receives it.
 */
function obfuscatedAccountId(uid) {
  const hash = crypto.createHash("md5").update(uid, "utf8").digest("hex");
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-3${hash.slice(13, 16)}` +
    `-8${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
}

function requireSignedIn(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
        "unauthenticated",
        "Sign in with Google before making or restoring a purchase.",
    );
  }
  return request.auth.uid;
}

function readPurchaseInput(data) {
  const productId = typeof data?.productId === "string" ?
    data.productId.trim() : "";
  const purchaseToken = typeof data?.purchaseToken === "string" ?
    data.purchaseToken.trim() : "";
  const packageName = typeof data?.packageName === "string" ?
    data.packageName.trim() : PACKAGE_NAME;

  if (packageName !== PACKAGE_NAME) {
    throw new HttpsError("invalid-argument", "Unexpected Android package.");
  }
  if (!PRODUCTS[productId]) {
    throw new HttpsError("invalid-argument", "Unknown Play product.");
  }
  if (purchaseToken.length < 16 || purchaseToken.length > 4096) {
    throw new HttpsError("invalid-argument", "Invalid Play purchase token.");
  }
  return {packageName, productId, purchaseToken};
}

function readCloudWriteInput(data) {
  const accountJson = typeof data?.accountJson === "string" ?
    data.accountJson : "";
  const runJson = typeof data?.runJson === "string" ? data.runJson : "";
  if (accountJson.length > MAX_SAVE_CHARS ||
      runJson.length > MAX_SAVE_CHARS) {
    throw new HttpsError("invalid-argument", "Cloud save is too large.");
  }
  // Parsing here prevents an invalid account blob from replacing a known-good
  // cloud save. The return value is also stripped of every paid-only field.
  const sanitizedAccountJson = sanitizeCloudAccountJson(accountJson);
  if (runJson) {
    try {
      const run = JSON.parse(runJson);
      if (!run || typeof run !== "object" || Array.isArray(run)) {
        throw new Error("invalid run");
      }
    } catch {
      throw new HttpsError("invalid-argument", "Cloud run save is invalid.");
    }
  }
  return {
    accountJson: sanitizedAccountJson,
    runJson,
    clientSavedAt: clampInteger(data?.clientSavedAt, 0, 9999999999999),
    expectedProgressVersion:
      clampInteger(data?.expectedProgressVersion, 0, 999999999),
    billingAdjustmentApplied:
      clampInteger(data?.billingAdjustmentApplied, 0),
    clientAppVersion: sanitizeClientAppVersion(data?.clientAppVersion),
  };
}

function sanitizeClientAppVersion(value) {
  const version = typeof value === "string" ? value.trim() : "";
  return /^[0-9A-Za-z][0-9A-Za-z._+-]{0,31}$/.test(version) ?
    version : "6.9.14";
}

function cloudSaveResponse(snapshot, data, extra = {}) {
  if (!snapshot && !data) {
    return {
      exists: false,
      fromCache: false,
      accountJson: "",
      runJson: "",
      clientSavedAt: 0,
      serverUpdatedAt: Date.now(),
      saveVersion: 0,
      progressVersion: 0,
      billingAdjustmentApplied: 0,
      ...extra,
    };
  }
  const record = data || snapshot.data();
  return {
    exists: true,
    fromCache: false,
    accountJson: sanitizeCloudAccountJson(record.accountJson || "{}"),
    runJson: typeof record.runJson === "string" ? record.runJson : "",
    clientSavedAt: clampInteger(
        record.clientSavedAt,
        0,
        9999999999999,
    ),
    serverUpdatedAt: record.updatedAt?.toMillis ?
      record.updatedAt.toMillis() : Date.now(),
    saveVersion: clampInteger(record.saveVersion),
    progressVersion: clampInteger(record.progressVersion),
    billingAdjustmentApplied:
      clampInteger(record.billingAdjustmentApplied),
    ...extra,
  };
}

/**
 * Server-owned cloud reads reconcile any newly-refunded coin grant before the
 * save reaches a device. Direct Firestore access is denied by rules.
 */
const readSecureCloudSave = onCall({
  region: REGION,
  enforceAppCheck: true,
}, async (request) => {
  const uid = requireSignedIn(request);
  return db.runTransaction(async (transaction) => {
    const saveRef = cloudSaveRef(uid);
    const accountRef = billingAccountRef(uid);
    const [saveSnapshot, accountSnapshot] = await Promise.all([
      transaction.get(saveRef),
      transaction.get(accountRef),
    ]);
    const adjustmentTotal = clampInteger(
        accountSnapshot.data()?.coinAdjustmentTotal,
    );
    if (!saveSnapshot.exists) {
      return cloudSaveResponse(null, null, {
        billingAdjustmentTotal: adjustmentTotal,
        billingAdjustmentOutstanding: adjustmentTotal,
      });
    }

    const current = saveSnapshot.data();
    const reconciled = applyCoinAdjustment(
        current.accountJson || "{}",
        adjustmentTotal,
        current.billingAdjustmentApplied,
    );
    const sanitizedChanged =
      reconciled.accountJson !== String(current.accountJson || "");
    let saveVersion = clampInteger(current.saveVersion);
    if (sanitizedChanged || reconciled.deducted > 0) {
      saveVersion += 1;
      transaction.set(saveRef, {
        accountJson: reconciled.accountJson,
        billingAdjustmentApplied: reconciled.applied,
        saveVersion,
        updatedAt: FieldValue.serverTimestamp(),
        billingAdjustedAt: reconciled.deducted > 0 ?
          FieldValue.serverTimestamp() :
          (current.billingAdjustedAt || FieldValue.delete()),
      }, {merge: true});
      transaction.set(accountRef, {
        coinAdjustmentAppliedToCloud: reconciled.applied,
        coinAdjustmentOutstanding: reconciled.outstanding,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return cloudSaveResponse(null, {
      ...current,
      accountJson: reconciled.accountJson,
      billingAdjustmentApplied: reconciled.applied,
      saveVersion,
    }, {
      serverUpdatedAt:
        (sanitizedChanged || reconciled.deducted > 0) ?
          Date.now() :
          (current.updatedAt?.toMillis ?
            current.updatedAt.toMillis() : Date.now()),
      billingAdjustmentTotal: adjustmentTotal,
      billingAdjustmentOutstanding: reconciled.outstanding,
      adjustedCoins: reconciled.deducted,
    });
  });
});

/**
 * Cloud writes are callable-only. A client can update ordinary progression,
 * but cannot write paid flags, purchase-token claims, or the protected refund
 * cursor. Refund adjustments are applied before the new save is committed.
 */
const writeSecureCloudSave = onCall({
  region: REGION,
  enforceAppCheck: true,
}, async (request) => {
  const uid = requireSignedIn(request);
  const input = readCloudWriteInput(request.data);
  return db.runTransaction(async (transaction) => {
    const saveRef = cloudSaveRef(uid);
    const accountRef = billingAccountRef(uid);
    const [saveSnapshot, accountSnapshot] = await Promise.all([
      transaction.get(saveRef),
      transaction.get(accountRef),
    ]);
    const current = saveSnapshot.exists ? saveSnapshot.data() : {};
    const progressVersion = clampInteger(current.progressVersion);
    if (input.expectedProgressVersion !== progressVersion) {
      throw new HttpsError(
          "aborted",
          "The cloud save changed on another device. Read it before retrying.",
          {
            progressVersion,
            saveVersion: clampInteger(current.saveVersion),
          },
      );
    }

    const adjustmentTotal = clampInteger(
        accountSnapshot.data()?.coinAdjustmentTotal,
    );
    if (input.billingAdjustmentApplied > adjustmentTotal) {
      throw new HttpsError(
          "failed-precondition",
          "Invalid billing reconciliation cursor.",
      );
    }
    const reconciled = applyCoinAdjustment(
        input.accountJson,
        adjustmentTotal,
        input.billingAdjustmentApplied,
    );
    const saveVersion = clampInteger(current.saveVersion) + 1;
    const nextProgressVersion = progressVersion + 1;
    const record = {
      uid,
      schemaVersion: 2,
      appVersion: input.clientAppVersion,
      accountJson: reconciled.accountJson,
      runJson: input.runJson,
      clientSavedAt: input.clientSavedAt,
      saveVersion,
      progressVersion: nextProgressVersion,
      billingAdjustmentApplied: reconciled.applied,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!saveSnapshot.exists) {
      record.createdAt = FieldValue.serverTimestamp();
    }
    transaction.set(saveRef, record, {merge: false});
    transaction.set(accountRef, {
      uid,
      coinAdjustmentTotal: adjustmentTotal,
      coinAdjustmentAppliedToCloud: reconciled.applied,
      coinAdjustmentOutstanding: reconciled.outstanding,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return cloudSaveResponse(null, record, {
      billingAdjustmentTotal: adjustmentTotal,
      billingAdjustmentOutstanding: reconciled.outstanding,
      adjustedCoins: reconciled.deducted,
    });
  });
});

function playPurchaseState(playPurchase) {
  return playPurchase?.purchaseStateContext?.purchaseState || "UNKNOWN";
}

function purchasedProductIds(playPurchase) {
  const lines = Array.isArray(playPurchase?.productLineItem) ?
    playPurchase.productLineItem : [];
  return lines.map((line) => line?.productId).filter(Boolean);
}

function isConsumed(playPurchase, productId) {
  const lines = Array.isArray(playPurchase?.productLineItem) ?
    playPurchase.productLineItem : [];
  const line = lines.find((item) => item?.productId === productId);
  return line?.productOfferDetails?.consumptionState ===
    "CONSUMPTION_STATE_CONSUMED";
}

function ledgerStatusAfterPlay(record, productId, playPurchase) {
  if (playPurchaseState(playPurchase) !== "PURCHASED") return "revoked";
  if (!purchasedProductIds(playPurchase).includes(productId)) return "revoked";
  return record?.status === "delivered" ? "delivered" : "verified";
}

async function readFromPlay(packageName, purchaseToken) {
  try {
    const response = await publisher.purchases.productsv2.getproductpurchasev2({
      packageName,
      token: purchaseToken,
    });
    return response.data;
  } catch (error) {
    const status = Number(error?.response?.status || error?.code || 0);
    if (status === 404) {
      throw new HttpsError(
          "not-found",
          "Google Play does not recognise this purchase.",
      );
    }
    if (status === 401 || status === 403) {
      throw new HttpsError(
          "failed-precondition",
          "The Play Developer API service identity is not authorised.",
      );
    }
    console.error("Google Play purchase verification failed", {
      status,
      message: error?.message,
    });
    throw new HttpsError(
        "unavailable",
        "Google Play verification is unavailable.",
    );
  }
}

function verifiedResponse(productId, tokenHash, record, playPurchase) {
  return {
    valid: true,
    productId,
    tokenHash,
    grant: PRODUCTS[productId],
    delivered: record?.status === "delivered",
    revoked: record?.status === "revoked",
    consumed: playPurchase ? isConsumed(playPurchase, productId) :
      Boolean(record?.consumed),
    testPurchase: Boolean(playPurchase?.testPurchaseContext),
  };
}

/**
 * Verify a Play one-time product with Google and reserve its globally unique
 * purchase token for exactly one Firebase account and one product.
 *
 * This deliberately does not consume/acknowledge. The app grants only from
 * this server-verified record and atomically saves the token hash beside the
 * entitlement before it finishes the Billing receipt.
 */
const verifyPlayPurchase = onCall({
  region: REGION,
  enforceAppCheck: true,
}, async (request) => {
  const uid = requireSignedIn(request);
  const input = readPurchaseInput(request.data);
  const tokenHash = hashToken(input.purchaseToken);
  const ref = db.collection("billingPurchases").doc(tokenHash);
  const existing = await ref.get();

  if (existing.exists) {
    const record = existing.data();
    if (record.uid !== uid || record.productId !== input.productId) {
      throw new HttpsError(
          "already-exists",
          "This Play purchase is already linked to another account.",
      );
    }
    if (record.status === "revoked") {
      throw new HttpsError("failed-precondition", "This purchase was revoked.");
    }
  }

  const playPurchase = await readFromPlay(input.packageName, input.purchaseToken);
  if (playPurchaseState(playPurchase) !== "PURCHASED") {
    throw new HttpsError(
        "failed-precondition",
        "The purchase is pending or was cancelled.",
    );
  }
  if (!purchasedProductIds(playPurchase).includes(input.productId)) {
    throw new HttpsError(
        "failed-precondition",
        "The purchase token does not contain this product.",
    );
  }
  if (playPurchase.obfuscatedExternalAccountId !== obfuscatedAccountId(uid)) {
    throw new HttpsError(
        "permission-denied",
        "The Play purchase is not attached to this WILDCARD account.",
    );
  }

  const record = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.exists ? snapshot.data() : null;
    if (current &&
        (current.uid !== uid || current.productId !== input.productId)) {
      throw new HttpsError(
          "already-exists",
          "This Play purchase is already linked to another account.",
      );
    }
    if (current?.status === "revoked") {
      throw new HttpsError("failed-precondition", "This purchase was revoked.");
    }

    const status = current?.status === "delivered" ? "delivered" : "verified";
    const update = {
      uid,
      packageName: input.packageName,
      productId: input.productId,
      // Server-only Firestore rules keep the token away from app clients. It
      // is retained so RTDN reconciliation can re-query Google Play.
      purchaseToken: input.purchaseToken,
      tokenHash,
      status,
      grant: PRODUCTS[input.productId],
      orderId: playPurchase.orderId || null,
      testPurchase: Boolean(playPurchase.testPurchaseContext),
      acknowledgementState: playPurchase.acknowledgementState || "UNKNOWN",
      consumed: isConsumed(playPurchase, input.productId),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!current) update.createdAt = FieldValue.serverTimestamp();
    transaction.set(ref, update, {merge: true});
    return {...current, ...update, status};
  });

  return verifiedResponse(input.productId, tokenHash, record, playPurchase);
});

/**
 * Record the client's delivery confirmation. This status is informational:
 * recovery remains driven by the authoritative verified ledger plus the
 * account's local/cloud purchaseClaims set, so a crash between either write
 * cannot lose or duplicate the grant. Repeated calls are idempotent.
 */
const markPlayPurchaseDelivered = onCall({
  region: REGION,
  enforceAppCheck: true,
}, async (request) => {
  const uid = requireSignedIn(request);
  const input = readPurchaseInput(request.data);
  const tokenHash = hashToken(input.purchaseToken);
  const ref = db.collection("billingPurchases").doc(tokenHash);

  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw new HttpsError("failed-precondition", "Verify the purchase first.");
    }
    const record = snapshot.data();
    if (record.uid !== uid || record.productId !== input.productId) {
      throw new HttpsError("permission-denied", "Purchase owner mismatch.");
    }
    if (record.status === "revoked") {
      throw new HttpsError("failed-precondition", "This purchase was revoked.");
    }
    if (record.status !== "delivered") {
      transaction.update(ref, {
        status: "delivered",
        deliveredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return {alreadyDelivered: record.status === "delivered"};
  });

  return {
    delivered: true,
    alreadyDelivered: result.alreadyDelivered,
    productId: input.productId,
    tokenHash,
  };
});

/**
 * Return every verified, non-revoked grant. The app compares these token hashes
 * with its bounded purchaseClaims set and reapplies only a missing grant. This
 * makes process-death and cross-device recovery safe without trusting
 * client-written accountJson as proof of payment. Raw purchase tokens are never
 * returned.
 */
const getPlayEntitlements = onCall({
  region: REGION,
  enforceAppCheck: true,
}, async (request) => {
  const uid = requireSignedIn(request);
  const snapshot = await db.collection("billingPurchases")
      .where("uid", "==", uid)
      .limit(400)
      .get();
  const records = await Promise.all(snapshot.docs.map(async (document) => {
    const record = document.data();
    if (record.productId !== "remove_ads" || record.status === "revoked") {
      return {id: document.id, ...record};
    }

    // A non-consumable must be reconciled with Google Play whenever the player
    // restores. RTDN remains the fast path, but this closes the gap when a
    // notification was delayed or Pub/Sub was temporarily unavailable.
    let playPurchase;
    try {
      playPurchase = await readFromPlay(
          record.packageName || PACKAGE_NAME,
          record.purchaseToken,
      );
    } catch (error) {
      if (error?.code !== "not-found") throw error;
      await document.ref.set({
        status: "revoked",
        revokedAt: FieldValue.serverTimestamp(),
        playState: "NOT_FOUND",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {...record, id: document.id, status: "revoked"};
    }

    const status = ledgerStatusAfterPlay(
        record,
        record.productId,
        playPurchase,
    );
    await document.ref.set({
      status,
      revokedAt: status === "revoked" ?
        FieldValue.serverTimestamp() : FieldValue.delete(),
      playState: playPurchaseState(playPurchase),
      acknowledgementState:
        playPurchase.acknowledgementState || "UNKNOWN",
      consumed: isConsumed(playPurchase, record.productId),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {...record, id: document.id, status};
  }));

  const [billingAccountSnapshot, cloudSaveSnapshot] = await Promise.all([
    billingAccountRef(uid).get(),
    cloudSaveRef(uid).get(),
  ]);
  const billingAccount = billingAccountSnapshot.data() || {};
  const cloudSave = cloudSaveSnapshot.data() || {};
  let noAds = false;
  const purchases = [];
  const unresolved = [];
  records.forEach((record) => {
    if (record.status === "revoked") return;
    purchases.push({
      productId: record.productId,
      tokenHash: record.id,
      delivered: record.status === "delivered",
      grant: record.grant || PRODUCTS[record.productId] || null,
    });
    if (record.productId === "remove_ads" &&
        (record.status === "verified" || record.status === "delivered")) {
      noAds = true;
    }
    if (record.status === "verified") {
      unresolved.push({
        productId: record.productId,
        tokenHash: record.id,
      });
    }
  });
  const coinAdjustmentTotal =
    clampInteger(billingAccount.coinAdjustmentTotal);
  const billingAdjustmentApplied =
    clampInteger(cloudSave.billingAdjustmentApplied);
  return {
    authoritative: true,
    noAds,
    purchases,
    unresolved,
    billing: {
      coinAdjustmentTotal,
      billingAdjustmentApplied,
      coinAdjustmentOutstanding:
        Math.max(0, coinAdjustmentTotal - billingAdjustmentApplied),
      cloudSaveVersion: clampInteger(cloudSave.saveVersion),
      progressVersion: clampInteger(cloudSave.progressVersion),
    },
  };
});

function shouldCreateCoinAdjustment(record) {
  const product = PRODUCTS[record?.productId];
  return Boolean(
      record?.uid &&
      product?.kind === "coins" &&
      // "verified" is already a server-authorised grant: the client applies it
      // immediately and then persists before marking delivered. Including that
      // short recovery window prevents a refund racing delivery and leaving
      // authorised coins behind. Pending/cancelled Play purchases never reach
      // verified state.
      (record.status === "verified" ||
       record.status === "delivered" ||
       record.deliveredAt),
  );
}

/**
 * Mark one Play ledger record revoked and create at most one monetary
 * adjustment. The adjustment total is monotonic; duplicate RTDN delivery,
 * retries, and repeated NOT_FOUND results cannot charge the player twice.
 */
async function reconcileRevokedPurchase({
  purchaseRef,
  tokenHash,
  current,
  playState,
  acknowledgementState,
  consumed,
  messageId,
}) {
  return db.runTransaction(async (transaction) => {
    const freshSnapshot = await transaction.get(purchaseRef);
    if (!freshSnapshot.exists) return {adjustmentCreated: false};
    const fresh = freshSnapshot.data();
    const createAdjustment = shouldCreateCoinAdjustment(fresh);
    const adjustmentRef = billingAdjustmentRef(tokenHash);
    const accountRef = fresh.uid ? billingAccountRef(fresh.uid) : null;
    const saveRef = fresh.uid ? cloudSaveRef(fresh.uid) : null;
    const reads = createAdjustment ? await Promise.all([
      transaction.get(adjustmentRef),
      transaction.get(accountRef),
      transaction.get(saveRef),
    ]) : [];
    const adjustmentSnapshot = reads[0];
    const accountSnapshot = reads[1];
    const saveSnapshot = reads[2];

    transaction.set(purchaseRef, {
      status: "revoked",
      revokedAt: fresh.revokedAt || FieldValue.serverTimestamp(),
      playState,
      acknowledgementState: acknowledgementState || "UNKNOWN",
      consumed: Boolean(consumed),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    if (!createAdjustment || adjustmentSnapshot.exists) {
      return {adjustmentCreated: false};
    }

    const amount = clampInteger(PRODUCTS[fresh.productId].amount);
    const oldTotal = clampInteger(
        accountSnapshot.data()?.coinAdjustmentTotal,
    );
    const newTotal = oldTotal + amount;
    let applied = clampInteger(
        saveSnapshot.data()?.billingAdjustmentApplied,
    );
    let outstanding = Math.max(0, newTotal - applied);
    let deducted = 0;

    if (saveSnapshot.exists) {
      const save = saveSnapshot.data();
      const reconciled = applyCoinAdjustment(
          save.accountJson || "{}",
          newTotal,
          applied,
      );
      applied = reconciled.applied;
      outstanding = reconciled.outstanding;
      deducted = reconciled.deducted;
      transaction.set(saveRef, {
        accountJson: reconciled.accountJson,
        billingAdjustmentApplied: applied,
        saveVersion: clampInteger(save.saveVersion) + 1,
        updatedAt: FieldValue.serverTimestamp(),
        billingAdjustedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    transaction.set(accountRef, {
      uid: fresh.uid,
      coinAdjustmentTotal: newTotal,
      coinAdjustmentAppliedToCloud: applied,
      coinAdjustmentOutstanding: outstanding,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.create(adjustmentRef, {
      uid: fresh.uid,
      tokenHash,
      productId: fresh.productId,
      amount,
      offsetStart: oldTotal,
      offsetEnd: newTotal,
      reason: "play-refund-or-revocation",
      sourceMessageId: String(messageId || ""),
      deductedAtCreation: deducted,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      adjustmentCreated: true,
      amount,
      deducted,
      outstanding,
    };
  });
}

/**
 * Real-time developer notifications are hints only. Always reread authoritative
 * state from the Play Developer API before changing the purchase ledger.
 */
const playBillingNotification = onMessagePublished({
  region: REGION,
  topic: RTDN_TOPIC,
  retry: true,
}, async (event) => {
  const messageId = event.data?.message?.messageId || event.id;
  const eventRef = db.collection("billingRtdnEvents")
      .doc(hashToken(String(messageId)));
  if ((await eventRef.get()).exists) return;

  const payload = event.data?.message?.json || {};
  const notice = payload.oneTimeProductNotification ||
    payload.voidedPurchaseNotification;
  const purchaseToken = notice?.purchaseToken;
  if (!purchaseToken || payload.packageName !== PACKAGE_NAME) {
    await eventRef.set({
      ignored: true,
      receivedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  const tokenHash = hashToken(purchaseToken);
  const purchaseRef = db.collection("billingPurchases").doc(tokenHash);
  const ledger = await purchaseRef.get();
  if (!ledger.exists) {
    await eventRef.set({
      ignored: true,
      reason: "unknown-token",
      tokenHash,
      receivedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  const current = ledger.data();
  let playPurchase;
  try {
    playPurchase = await readFromPlay(PACKAGE_NAME, purchaseToken);
  } catch (error) {
    if (error?.code !== "not-found") throw error;
  }
  const state = playPurchase ? playPurchaseState(playPurchase) : "NOT_FOUND";
  const revoked = !playPurchase ||
    ledgerStatusAfterPlay(current, current.productId, playPurchase) ===
      "revoked";
  let adjustment = {adjustmentCreated: false};
  if (revoked) {
    adjustment = await reconcileRevokedPurchase({
      purchaseRef,
      tokenHash,
      current,
      playState: state,
      acknowledgementState:
        playPurchase?.acknowledgementState || "UNKNOWN",
      consumed: playPurchase ?
        isConsumed(playPurchase, current.productId) :
        Boolean(current.consumed),
      messageId,
    });
  } else {
    await purchaseRef.set({
      status: current.status,
      revokedAt: FieldValue.delete(),
      playState: state,
      acknowledgementState:
        playPurchase?.acknowledgementState || "UNKNOWN",
      consumed: isConsumed(playPurchase, current.productId),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  await eventRef.set({
    tokenHash,
    playState: state,
    revoked,
    adjustmentCreated: Boolean(adjustment.adjustmentCreated),
    adjustmentAmount: clampInteger(adjustment.amount),
    receivedAt: FieldValue.serverTimestamp(),
  });
});

/**
 * Called by the central deleteMyAccount function. Financial/fraud records are
 * retained only in pseudonymised form: Firebase UID and raw purchase token are
 * removed, while product, order and token hash remain.
 */
async function deleteBillingData(uid) {
  let pseudonymised = 0;
  while (true) {
    const snapshots = await db.collection("billingPurchases")
        .where("uid", "==", uid)
        .limit(400)
        .get();
    if (snapshots.empty) break;
    const batch = db.batch();
    snapshots.forEach((snapshot) => {
      batch.update(snapshot.ref, {
        uid: FieldValue.delete(),
        purchaseToken: FieldValue.delete(),
        accountDeletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    pseudonymised += snapshots.size;
  }
  let adjustmentsPseudonymised = 0;
  while (true) {
    const snapshots = await db.collection("billingAdjustments")
        .where("uid", "==", uid)
        .limit(400)
        .get();
    if (snapshots.empty) break;
    const batch = db.batch();
    snapshots.forEach((snapshot) => {
      batch.update(snapshot.ref, {
        uid: FieldValue.delete(),
        accountDeletedAt: FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    adjustmentsPseudonymised += snapshots.size;
  }
  await billingAccountRef(uid).delete();
  return {
    billingRecordsPseudonymised: pseudonymised,
    billingAdjustmentsPseudonymised: adjustmentsPseudonymised,
  };
}

module.exports = {
  verifyPlayPurchase,
  markPlayPurchaseDelivered,
  getPlayEntitlements,
  playBillingNotification,
  readSecureCloudSave,
  writeSecureCloudSave,
  deleteBillingData,
  __test: {
    PACKAGE_NAME,
    PRODUCTS,
    hashToken,
    obfuscatedAccountId,
    isConsumed,
    ledgerStatusAfterPlay,
    playPurchaseState,
    purchasedProductIds,
    sanitizeCloudAccountJson,
    applyCoinAdjustment,
    shouldCreateCoinAdjustment,
    sanitizeClientAppVersion,
    PROTECTED_CLOUD_ACCOUNT_FIELDS,
  },
};

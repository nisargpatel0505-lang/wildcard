"use strict";

const crypto = require("node:crypto");
const {getApp, getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {defineSecret} = require("firebase-functions/params");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const billing = require("./billing.js");

const app = getApps().length ? getApp() : initializeApp();
const db = getFirestore(app);
const boardSecret = defineSecret("WILDCARD_BOARD_HMAC_SECRET");

const REGION = "europe-west2";
const BOARD_INTERNAL_URL = (
  process.env.WILDCARD_BOARD_INTERNAL_URL ||
  "https://raspberrypi.tail20f574.ts.net/api/internal"
).replace(/\/+$/, "");
const NAME_RE = /^[A-Z0-9]{1,8}$/;
const IDEMPOTENCY_RE = /^[A-Za-z0-9_-]{16,80}$/;
const SCORE_MAX = 10_000_000;
const RATE_LIMIT = 6;
const RATE_WINDOW_MS = 60_000;
const REQUEST_RETENTION_MS = 15 * 24 * 60 * 60 * 1000;

function utcDate(now = new Date()) {
  return now.toISOString().slice(0, 10);
}

function uidHash(uid) {
  return crypto.createHash("sha256").update(uid, "utf8").digest("hex");
}

function exactFields(value, expected) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return actual.length === wanted.length &&
    actual.every((field, index) => field === wanted[index]);
}

function validateSubmission(data, now = new Date()) {
  if (!exactFields(data, ["name", "score", "idempotencyKey"])) {
    throw new HttpsError("invalid-argument", "Unexpected score fields.");
  }
  const date = utcDate(now);
  const name = typeof data.name === "string" ? data.name.trim().toUpperCase() : "";
  const score = data.score;
  const idempotencyKey = data.idempotencyKey;
  if (!NAME_RE.test(name)) {
    throw new HttpsError("invalid-argument", "Board names use 1–8 letters or numbers.");
  }
  if (!Number.isSafeInteger(score) || score < 0 || score > SCORE_MAX) {
    throw new HttpsError("invalid-argument", "Score is outside the accepted range.");
  }
  if (typeof idempotencyKey !== "string" || !IDEMPOTENCY_RE.test(idempotencyKey)) {
    throw new HttpsError("invalid-argument", "Invalid idempotency key.");
  }
  return {date, name, score, idempotencyKey};
}

function signedPiRequest(path, payload, secretValue, fetchImpl = fetch) {
  if (typeof secretValue !== "string" || Buffer.byteLength(secretValue, "utf8") < 32) {
    throw new Error("WILDCARD_BOARD_HMAC_SECRET must be at least 32 bytes");
  }
  const issuedAtSeconds = Math.floor(Date.now() / 1000);
  const bodyPayload = {...payload, issuedAt: issuedAtSeconds * 1000};
  const body = JSON.stringify(bodyPayload);
  const signature = crypto
    .createHmac("sha256", secretValue)
    .update(`${issuedAtSeconds}.${body}`, "utf8")
    .digest("hex");
  return fetchImpl(`${BOARD_INTERNAL_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Wildcard-Timestamp": String(issuedAtSeconds),
      "X-Wildcard-Signature": signature,
    },
    body,
    signal: AbortSignal.timeout(8_000),
  }).then(async (response) => {
    let result = {};
    try {
      result = await response.json();
    } catch (_error) {
      // The status remains authoritative when an upstream returns no JSON.
    }
    if (!response.ok) {
      const error = new Error(`Pi board rejected request (${response.status})`);
      error.status = response.status;
      error.details = result;
      throw error;
    }
    return result;
  });
}

async function persistSubmission(uid, submission, now = new Date()) {
  const {date, name, score, idempotencyKey} = submission;
  const accountHash = uidHash(uid);
  const requestRef = db.doc(
    `dailyScoreSubmissions/${uid}/requests/${idempotencyKey}`,
  );
  const entryRef = db.doc(`dailyScores/${date}/entries/${uid}`);
  const profileRef = db.doc(`users/${uid}/private/board`);
  const nameRef = db.doc(`boardNames/${name}`);
  const rateRef = db.doc(`dailyScoreRate/${uid}`);
  const nowMs = now.getTime();

  return db.runTransaction(async (transaction) => {
    const requestSnapshot = await transaction.get(requestRef);
    const entrySnapshot = await transaction.get(entryRef);
    const profileSnapshot = await transaction.get(profileRef);
    const rateSnapshot = await transaction.get(rateRef);
    const nameSnapshot = await transaction.get(nameRef);
    const previousName = profileSnapshot.exists ?
      String(profileSnapshot.get("name") || "") : "";
    const previousNameRef = previousName && previousName !== name ?
      db.doc(`boardNames/${previousName}`) : null;
    const previousNameSnapshot = previousNameRef ?
      await transaction.get(previousNameRef) : null;

    if (requestSnapshot.exists) {
      const saved = requestSnapshot.data();
      if (
        saved.uid !== uid ||
        saved.name !== name ||
        saved.requestedScore !== score
      ) {
        throw new HttpsError(
          "already-exists",
          "That idempotency key was used for different score data.",
        );
      }
      return {
        // Preserve the original server-assigned UTC day across an outage or a
        // retry that crosses midnight.
        date: saved.date,
        name: saved.name,
        bestScore: Number(saved.bestScore),
        idempotencyKey,
        uidHash: accountHash,
        replayed: true,
      };
    }

    if (nameSnapshot.exists && nameSnapshot.get("uid") !== uid) {
      throw new HttpsError("already-exists", "That board name is already claimed.");
    }

    let windowStart = rateSnapshot.exists ?
      Number(rateSnapshot.get("windowStart")) : nowMs;
    let count = rateSnapshot.exists ? Number(rateSnapshot.get("count")) : 0;
    if (!Number.isFinite(windowStart) || nowMs - windowStart >= RATE_WINDOW_MS) {
      windowStart = nowMs;
      count = 0;
    }
    if (!Number.isSafeInteger(count) || count < 0) count = RATE_LIMIT;
    if (count >= RATE_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many score submissions. Wait one minute.",
      );
    }

    const previousScore = entrySnapshot.exists ?
      Number(entrySnapshot.get("score")) : 0;
    const bestScore = Math.max(
      Number.isSafeInteger(previousScore) ? previousScore : 0,
      score,
    );

    if (
      previousNameRef &&
      previousNameSnapshot.exists &&
      previousNameSnapshot.get("uid") === uid
    ) {
      transaction.delete(previousNameRef);
    }
    transaction.set(nameRef, {
      uid,
      uidHash: accountHash,
      name,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(profileRef, {
      uid,
      name,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(entryRef, {
      kind: "dailyScore",
      uid,
      uidHash: accountHash,
      date,
      name,
      score: bestScore,
      verification: "firebase-auth-app-check-client-score",
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(rateRef, {
      uid,
      windowStart,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(requestRef, {
      uid,
      date,
      name,
      requestedScore: score,
      bestScore,
      forwarded: false,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(nowMs + REQUEST_RETENTION_MS),
    });

    return {
      date,
      name,
      bestScore,
      idempotencyKey,
      uidHash: accountHash,
      replayed: false,
    };
  });
}

async function markForwarded(uid, idempotencyKey) {
  await db.doc(
    `dailyScoreSubmissions/${uid}/requests/${idempotencyKey}`,
  ).set({
    forwarded: true,
    forwardedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function deleteDailyScoreEntries(uid) {
  let deleted = 0;
  while (true) {
    const snapshot = await db.collectionGroup("entries")
      .where("uid", "==", uid)
      .limit(400)
      .get();
    const matching = snapshot.docs.filter((document) =>
      /^dailyScores\/[^/]+\/entries\/[^/]+$/.test(document.ref.path),
    );
    if (!matching.length) return deleted;
    const batch = db.batch();
    for (const document of matching) batch.delete(document.ref);
    await batch.commit();
    deleted += matching.length;
    if (matching.length < 400) return deleted;
  }
}

async function forwardOrQueueBoardDeletion(accountHash, secretValue) {
  const queueRef = db.doc(`boardDeletionQueue/${accountHash}`);
  const idempotencyKey = `delete_${accountHash}`;
  try {
    await signedPiRequest("/delete-user", {
      uidHash: accountHash,
      idempotencyKey,
    }, secretValue);
    await queueRef.delete();
    return false;
  } catch (error) {
    console.error("Pi board deletion queued", {
      uidHash: accountHash,
      status: error.status || null,
    });
    await queueRef.set({
      uidHash: accountHash,
      idempotencyKey,
      attempts: FieldValue.increment(1),
      pending: true,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  }
}

async function deleteAccountData(uid, secretValue) {
  const accountHash = uidHash(uid);
  // Account deletion must not be held hostage by a temporary Pi outage.
  // Failed board deletion is retained as a pseudonymous retry job.
  const boardDeletionQueued = await forwardOrQueueBoardDeletion(
    accountHash,
    secretValue,
  );

  const profileRef = db.doc(`users/${uid}/private/board`);
  const profileSnapshot = await profileRef.get();
  const name = profileSnapshot.exists ? String(profileSnapshot.get("name") || "") : "";
  if (NAME_RE.test(name)) {
    const nameRef = db.doc(`boardNames/${name}`);
    await db.runTransaction(async (transaction) => {
      const nameSnapshot = await transaction.get(nameRef);
      if (nameSnapshot.exists && nameSnapshot.get("uid") === uid) {
        transaction.delete(nameRef);
      }
    });
  }

  const scoreCount = await deleteDailyScoreEntries(uid);
  const billingDeletion = await billing.deleteBillingData(uid);
  await Promise.all([
    db.recursiveDelete(db.doc(`dailyScoreSubmissions/${uid}`)),
    db.recursiveDelete(db.doc(`users/${uid}`)),
    db.doc(`dailyScoreRate/${uid}`).delete(),
  ]);
  await getAuth(app).deleteUser(uid);
  return {
    deleted: true,
    scoreRecordsDeleted: scoreCount,
    boardDeletionQueued,
    ...billingDeletion,
  };
}

exports.submitDailyScore = onCall({
  region: REGION,
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  secrets: [boardSecret],
  timeoutSeconds: 20,
  memory: "256MiB",
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in with Google to post a score.");
  }
  const submission = validateSubmission(request.data);
  const stored = await persistSubmission(request.auth.uid, submission);
  try {
    const board = await signedPiRequest("/daily", {
      date: stored.date,
      name: stored.name,
      score: stored.bestScore,
      uidHash: stored.uidHash,
      idempotencyKey: stored.idempotencyKey,
    }, boardSecret.value());
    await markForwarded(request.auth.uid, stored.idempotencyKey);
    return {
      ok: true,
      date: board.date,
      top: board.top,
      you: board.you,
      rank: board.rank,
      replayed: stored.replayed || Boolean(board.replayed),
      rewards: null,
    };
  } catch (error) {
    console.error("Daily score forwarding failed", {
      status: error.status || null,
      uidHash: stored.uidHash,
      date: stored.date,
    });
    throw new HttpsError(
      "unavailable",
      "The board is temporarily unavailable; retry with the same request ID.",
    );
  }
});

exports.deleteMyAccount = onCall({
  region: REGION,
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  secrets: [boardSecret],
  timeoutSeconds: 120,
  memory: "256MiB",
  maxInstances: 5,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in again before deleting your account.");
  }
  if (!exactFields(request.data, ["confirm"]) || request.data.confirm !== "DELETE") {
    throw new HttpsError("failed-precondition", "Type DELETE to confirm.");
  }
  try {
    return await deleteAccountData(request.auth.uid, boardSecret.value());
  } catch (error) {
    console.error("Account deletion failed", {
      uidHash: uidHash(request.auth.uid),
      message: error && error.message ? error.message : "unknown",
    });
    throw new HttpsError(
      "unavailable",
      "Account deletion could not complete. No success was reported; please retry.",
    );
  }
});

exports.verifyPlayPurchase = billing.verifyPlayPurchase;
exports.markPlayPurchaseDelivered = billing.markPlayPurchaseDelivered;
exports.getPlayEntitlements = billing.getPlayEntitlements;
exports.playBillingNotification = billing.playBillingNotification;
exports.readSecureCloudSave = billing.readSecureCloudSave;
exports.writeSecureCloudSave = billing.writeSecureCloudSave;

exports.retryBoardDeletions = onSchedule({
  region: REGION,
  schedule: "every 15 minutes",
  secrets: [boardSecret],
  timeoutSeconds: 300,
  memory: "256MiB",
  maxInstances: 1,
}, async () => {
  const snapshot = await db.collection("boardDeletionQueue").limit(20).get();
  await Promise.all(snapshot.docs.map(async (document) => {
    const record = document.data();
    try {
      await signedPiRequest("/delete-user", {
        uidHash: record.uidHash,
        idempotencyKey: record.idempotencyKey,
      }, boardSecret.value());
      await document.ref.delete();
    } catch (error) {
      await document.ref.set({
        attempts: FieldValue.increment(1),
        lastErrorStatus: Number(error.status || 0),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }));
});

exports.__test = {
  exactFields,
  uidHash,
  utcDate,
  validateSubmission,
  signedPiRequest,
};

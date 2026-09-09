# WILDCARD v9.1.2 billing verification

Date: 2026-09-09. Branch: `release/v9.1.2-play-billing`.

## Outcome and limits

The release candidate now credits a paid purchase into the server wallet and marks its receipt delivered in one Firestore transaction. It no longer treats client purchase-claim history as authority for currency. Focused tests pass, but this is **not evidence of a completed real-money purchase**. A Play-installed license-tester purchase, restore, consumption/acknowledgment and refund test remains necessary before describing live IAP as verified.

No prices, reward amounts, gameplay mathematics, signing identity, privacy rules or ad-unit IDs were changed by this billing repair.

## Products retained

| Product ID | Server grant | Storefront |
| --- | ---: | --- |
| `coins_250` | 250 coins | Visible |
| `coins_600` | 600 coins | Visible |
| `coins_1600` | 1,600 coins | Visible |
| `coins_3600` | 3,600 coins | Legacy recovery only |
| `coins_8500` | 8,500 coins | Legacy recovery only |
| `remove_ads` | Remove forced ads | Visible |

The client uses Google Play product metadata for displayed prices. This review did not independently read fresh regional prices from a Play-installed device. Remove Ads leaves voluntary rewarded ads available; it is not a free-coin entitlement.

## Protocol and recovery

1. The app must reconcile the signed-in cloud owner and save current progress before opening a purchase.
2. Existing `verifyPlayPurchase` verifies the product, Play purchase state and obfuscated Firebase owner; it reserves the unique token with `deliveryProtocol: 2`.
3. The client saves a checked local recovery journal before calling the new `fulfillPlayPurchase` endpoint.
4. The endpoint rechecks Play and atomically updates the wallet, refund cursor, receipt delivery status and both save/progress revisions. Duplicate delivered receipts return zero new currency. Pending, canceled, revoked, foreign-account, consumed-but-undelivered and stale-version requests fail closed.
5. The client adds only the server-confirmed delta to its latest local balance, preserving local earnings made during the request. It durably stores the claim and revision/dirty checkpoint before clearing the journal. A locally persisted Remove Ads entitlement suppresses forced ads immediately, independently of later network completion.
6. Only then does the client finish delivery confirmation and Play consumption/acknowledgment. A failed Play consumption response is surfaced for retry rather than ignored.

Receipt callbacks and ordinary cloud writes are serialized during fulfillment. Sign-out/deletion wait for an active delivery and block newly arriving grants during the account transition.

A lost response is recovered only when the server revision proves the exact pending billing update. The client preserves earned/spent progress and does not add coins twice after a local disk/cursor failure. If another device or refund has also changed that revision, it preserves the phone save and journal and reports a conflict; it does not guess or silently overwrite progress.

Refunds of protocol-2 reservations that were never fulfilled do not create coin debt. Delivered purchase refunds remain idempotent adjustments. Server wallet changes, including refunds and read-time adjustments, advance both revisions so stale saves cannot undo them. Entitlement and RTDN refreshes read the latest receipt inside a transaction and cannot regress a concurrent delivery or resurrect a revoked receipt.

Remove Ads restore now applies authoritative revocation as well as activation. Its lookup is separate from the capped consumable history, so a player with over 400 coin purchases does not lose the paid entitlement through pagination.

## Backward compatibility and rollback

- Old protocol-1 clients retain their existing endpoints and protocol-1 receipt behavior.
- Already-delivered legacy receipts are never credited again.
- An older verified-but-undelivered receipt is ambiguous: the old client may already have included its coins in a save. The new client requires a support check rather than blindly adding those coins again.
- Protocol-1 verification/delivery calls cannot bypass protocol-2 atomic fulfillment, and protocol-2 reservations are hidden from old entitlement-list currency recovery.
- Do **not** roll the server back to pre-protocol-2 code after protocol-2 receipts exist. Keep the new endpoint and guards deployed; pause/roll forward the client release if a problem appears. Do not delete the receipt ledger or journals as a rollback method.

Read-only production counts at review time: `billingPurchases` total **0**, verified **0**, delivered **0**, revoked **0**. Thus no existing ambiguous legacy receipt was observed, but these are point-in-time counts, not a lifetime guarantee.

## Verification evidence

- Backend `npm test`: **31 passed**, zero failures. Includes transaction-helper tests for atomic grant/receipt, replay, stale versions, foreign owners, pending/canceled state, refund distinctions, entitlement/RTDN races and both revision counters. These are mocked transaction tests, not a Firestore emulator or live purchase run.
- Final focused Flutter billing suite: **11 passed**, including lost responses, concurrent local earnings, duplicate receipts, local account/cursor failures, Remove Ads recovery and sign-out/new-receipt serialization.
- Earlier billing + cloud-startup + upgrade suite: **25 passed**.
- Coordinator-reported full public Flutter suite before the final narrow account-transition guard: **520 passed, 2 skipped**. The guard was subsequently covered by the focused 11-test rerun.
- Targeted Dart analysis on the four changed client source files and billing tests: **No issues found**.
- Read-only deployed-function inventory: existing billing/cloud/RTDN functions ACTIVE in `europe-west2`, Node.js 22. RTDN topic: `projects/wildcard-31d50/topics/wildcard-play-billing`, retry enabled. The new endpoint was not deployed at the initial inventory check.
- Read-only Firestore `uid == ...` plus `productId == remove_ads` query succeeded against `wildcard-31d50`; no missing-index error. No documents, tokens or user identities were printed.

## Deployment handoff

Run from the current `wildcard-astra-6` repository, not the older `wildcard-app` Firebase MCP directory:

```powershell
firebase deploy --project wildcard-31d50 --config firebase.json --only "functions:verifyPlayPurchase,functions:fulfillPlayPurchase,functions:markPlayPurchaseDelivered,functions:getPlayEntitlements,functions:playBillingNotification,functions:readSecureCloudSave,functions:writeSecureCloudSave" --non-interactive
```

Deploy before publishing the new AAB. No Firestore rules/index deployment or data migration is required. If the coordinator's initial deployment used the preceding 29-test package, redeploy `functions:readSecureCloudSave,functions:playBillingNotification` from the final 31-test source; these are the only functions changed in that final backend patch. Deployment success must be recorded by the release coordinator separately.

## Remaining live checks

- Verify the Play Developer API service identity has the necessary Play permissions using a real license-tester receipt. Function existence alone does not prove that permission.
- On a Play-installed build: purchase each visible coin product once; confirm exact grant and successful consumption; restart and restore without another grant.
- Purchase Remove Ads with a license tester; confirm forced ads stop immediately and stay removed after restart/sign-in on another device. Confirm voluntary rewarded ads remain optional.
- Exercise pending-payment completion and a test refund/revocation; verify the server ledger and wallet adjustment, then the client restore result.
- Confirm RTDN delivery from Play, not merely the existence of its Pub/Sub trigger.
- Verify App Check on the Play-signed build. No charge, test purchase, actual ad impression, refund or notification delivery was executed by this billing subtask.

Google's relevant primary guidance: [backend purchase processing](https://developer.android.com/google/play/billing/backend), [billing integration](https://developer.android.com/google/play/billing/integrate), [Products v2 API](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2).

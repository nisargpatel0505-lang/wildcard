# Firebase connection

The Android app `com.nisarg.wildcard` is registered in Firebase project `wildcard-31d50` as app ID `1:420107184674:android:d1249c53cbde7160c2387b`.

The release signing certificate SHA-256 registered with Firebase is:

`C3:C2:81:D1:47:0A:EB:F2:D9:96:56:22:1A:DA:78:15:C6:B8:73:F4:E8:A7:48:D7:28:4F:5F:AE:5D:76:47:17`

The matching SHA-1 used by Google sign-in and Play Games is:

`E0:5C:17:94:91:AC:EE:68:9A:A1:E0:3A:63:D9:79:DE:D9:5B:05:C0`

`android/app/google-services.json` is installed and the Google Services Gradle task runs during release builds. Firebase describes this file as project/app identifiers rather than an authorization secret.

## v6.9 services

- Firebase Authentication: Google provider enabled; sign-in remains optional.
- Cloud Firestore: Standard edition `(default)` database in `europe-west2` (London), deletion protection enabled.
- Cloud save path: `users/{auth.uid}/saves/main`.
- Security Rules: all direct client save reads, writes and deletes are denied. Cloud saves use App-Check-protected callable Functions, with recursive default deny for every other path.
- App Check: the Android app is registered with the Play Integrity provider. Firebase App Check and Google Play Integrity APIs are enabled, Play Console is linked to Cloud project number `420107184674`, and Cloud Firestore enforcement is active. Callable Functions independently require valid App Check tokens.
- Google Play Games project/application ID: `420107184674`.
- Official high-score leaderboard ID: `CgkIotTbgp0MEAIQAQ`.

The Firestore emulator attack suite is `npm run test:rules`. It covers unauthenticated and cross-user access, UID spoofing/mutation, unexpected and missing fields, type errors, oversized saves, bad timestamps, enumeration and deletion.

Firebase AI Logic is deliberately not enabled yet. Before adding any Gemini-powered game feature, complete these controls:

1. Define the exact player-facing feature and its data flow.
2. Configure App Check with Play Integrity for the Android distribution model.
3. Restrict the Firebase API key to only the APIs and Android app that need it.
4. Require authenticated users for AI calls.
5. Configure quotas, spend alerts, monitoring, and Remote Config for model selection.
6. Review prompts, safety behavior, privacy disclosure, and failure fallbacks.

## Launch-hardening backend

The source tree now contains second-generation callable Functions in
`functions/index.js`:

- `submitDailyScore` requires Firebase Authentication and an enforced,
  limited-use App Check token. It fixes the date to the current UTC day,
  reserves each board name to one account, applies a per-account rate window,
  records idempotency keys, keeps only the best score, then sends a
  server-signed write to the Pi.
- `deleteMyAccount` requires the same protections and an explicit `DELETE`
  confirmation. It removes the user's custom-board entries, Firestore records
  and Firebase Authentication identity. A temporary Pi outage does not block
  deletion: the pseudonymous board reference is queued and
  `retryBoardDeletions` retries every 15 minutes until the Pi confirms removal.
- `readSecureCloudSave` and `writeSecureCloudSave` keep save ownership and
  entitlement fields server-controlled.
- `verifyPlayPurchase`, `markPlayPurchaseDelivered` and
  `getPlayEntitlements` provide an idempotent trusted purchase ledger.
- `playBillingNotification` consumes Google Play real-time developer
  notifications and records refunds/revocations as server-owned adjustments.

App Check proves that a request came from an attested build/device and
Authentication identifies the account. The score itself is still reported by
the client; it is not a server replay of the run. Daily Board coin prizes must
therefore remain disabled.

The HMAC used between Functions and the Pi is never stored in Git. Generate at
least 32 random bytes and configure the same value in both places:

```bash
openssl rand -hex 32
npx firebase-tools functions:secrets:set WILDCARD_BOARD_HMAC_SECRET
```

Set `WILDCARD_BOARD_HMAC_SECRET` in the `wildcard-api.service` environment on
the Pi, then restart that service. The old public `POST /api/daily` path is
deliberately rejected; only signed `POST /api/internal/daily` writes are
accepted. Exact browser origins can be overridden with the comma-separated Pi
environment variable `WILDCARD_ALLOWED_ORIGINS`.

The deployed backend was verified with:

```bash
npm --prefix functions install
npm --prefix functions test
npm run test:rules
npx firebase-tools deploy --only firestore:rules,functions,hosting
```

All nine second-generation Functions are active in `europe-west2`; the
Firestore Rules emulator suite passes 29/29 and the Functions suite passes
11/11. Configure Firestore TTL for the collection-group field `expiresAt` to
prune score-request idempotency records after 15 days if it is not already
enabled.

The external deletion page deploys to
`https://wildcard-31d50.web.app/account-deletion.html`. Put that exact URL in
Play Console's account-deletion field. The live Android Settings screen exposes
the authenticated `deleteMyAccount` route.

Firebase AI Logic, SQL/Data Connect, Firebase Analytics and Crashlytics remain disabled. Firebase Hosting is now configured solely for the public account-deletion resource. WILDCARD's separate privacy-minimised Pi counters are documented in `docs/ANALYTICS.md`; they do not use a Firebase SDK. The project is on Blaze because Firestore was provisioned; use budget alerts and console monitoring before broad distribution.

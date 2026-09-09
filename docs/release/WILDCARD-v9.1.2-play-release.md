# WILDCARD 9.1.2 / code 77

Release preparation: 2026-09-09. Branch: `release/v9.1.2-play-billing`.

## Scope

Promotes the current official phone-polish source (baseline `5844ba2d20457a2690c5ae3d35216719f4f62251`) to a public, ads-enabled closed-test build. Includes randomized/cycling free starter choices, four new preview room themes, the shop gallery, loading/coin polish and the latest heading-contrast correction. Existing Astra-derived economy/progression work is retained, not retuned in this release. No scoring, Joker mathematics, prices, package identity, signing key, consent policy or test-track enrollment changes.

Major billing fixes: atomic server coin/receipt delivery, durable interrupted-purchase recovery, ownership checks, refund revision handling, and safe account transitions. Remove Ads now restores both activation and revocation; an interstitial finishing its load after Remove Ads activates is discarded. The existing Play product promises instant optional bonuses to paid owners: code 77 honours that promise without an ad, while keeping the shared daily limit and unchanged reward amounts. Owner-only ad suppression does not create this paid benefit. See [billing verification](v9.1.2-validation/billing-verification.md) for protocol details and live-test limitations.

## Build and checks

- Flutter 3.44.7 / Dart 3.12.2; `flutter build appbundle --release --no-pub`, with no owner/offline/test-ad defines. The final code-77 build completed in 387.3 seconds after the paid-bonus correction (the superseded code-76 candidate took 349.7 seconds).
- Full public Flutter suite: 520 passed, two experiment-only skips. Final narrow account-transition guard was subsequently covered by 11 passing focused billing tests.
- Final paid-bonus patch: 54 focused reward/billing/ad/UI/engine tests passed, including 2,000 deterministic complete runs with zero invariant failures. A second independent review checked account switching, claim recovery, daily caps and once-per-run revive behavior.
- Full Flutter analysis after the final code-77 client changes: no issues (38.6 seconds).
- Backend final suite: 31 passed. Ad lifecycle/public-policy checks: 18 passed, including the reproduced Remove Ads loading race.
- Bundletool validation passed. AAB JAR signature verified against the existing release certificate. Universal APK derived from this exact bundle verifies with APK signature schemes v2/v3.
- Package `com.nisarg.wildcard`; version 9.1.2/code 77; min SDK 24, target SDK 36. INTERNET and Play BILLING permissions retained.
- Manifest uses owned AdMob app ID `ca-app-pub-3855192091371080~7622357185`. Automatic Firebase/AdMob startup providers remain removed so initialization stays behind the app's privacy gate.
- All three compiled Dart ABI libraries contain the owned rewarded/interstitial unit IDs and no Google demonstration publisher ID. AAB and derived APK Dart libraries match byte-for-byte for each ABI.
- AAB/APK DEX hash matches the constructor-verified candidate: `d5c767efdef608a9347171ab0d81631add4e53f227f1a1fb73c17087673030e5`. `WorkDatabase_Impl` retains its public no-argument constructor, guarding the prior Play launch crash.
- Original public catalog/owner-dev isolation and no Levels/Arcade mode remain unchanged. Phone-only no-ads flag is not used.
- Signing SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.

Artifacts are outside Git in `official-v9.1.2-delivery/` next to the repository. Source build commit: `c25f95b3ce52f753687272154d51452aebb5ac4c` (pushed to the release branch). Code 76 is superseded and must not be distributed; use only the final files below:

| Artifact | SHA-256 |
| --- | --- |
| WILDCARD-v9.1.2-code77.aab | `0a74dee11daa21ed30f6d53db3018784cc0e071c95372c62236d31d5ea0dd2e4` |
| WILDCARD-v9.1.2-code77.apk | `d8caafcd264fb29291bd73cb60619ed6b2d3ad10593d0f7cb0df06a3441ae37d` |

The AAB is 90,096,731 bytes; Google Play reports a 36.6 MB new install and 6.1 MB update. Bundletool and signature checks passed; Google Play accepted code 77. Jarsigner exits zero with expected self-signed/timestamp warnings and the Android Gradle archive's manifest-order warning. The build daemon was stopped after verification.

## Backend deployment

Deployed only the seven compatible billing/cloud functions to `wildcard-31d50`, `europe-west2`: verifyPlayPurchase, fulfillPlayPurchase, markPlayPurchaseDelivered, getPlayEntitlements, playBillingNotification, readSecureCloudSave and writeSecureCloudSave. The final read/refund/RTDN patch was then redeployed to readSecureCloudSave and playBillingNotification. Both deployments completed successfully; subsequent inventory shows all seven ACTIVE. No Firestore rules, hosting, account data or tester records were changed.

Retain this compatible backend if halting/rolling back the client release; do not remove protocol-2 guards after new receipts exist.

## Play status

Before upload, Console showed closed-test Alpha version 8.5.3/code 72 live, an obsolete code-34 draft, and code 34 still on the separate internal track. Code 76 was initially accepted and submitted, then withdrawn before review and its unpublished release discarded after the final product-description check found the paid-bonus mismatch. Code 77 replaces that candidate; do not distribute code 76. The existing code-72 release and tester lists remain untouched during preparation.

**Final confirmed status, 9 September 2026:** code 77 / version 9.1.2 was accepted, selected as the only new bundle, and submitted for 100% rollout on **Closed testing — Alpha** under release name `WILDCARD 9.1.2 - starter choices and polish`. Publishing overview shows **Changes in review** with automated quick checks running. Managed publishing is OFF, so rollout is automatic after approval. This is submitted, **not yet confirmed available to testers**. No production or separate internal-track release was changed. Play validation had no errors and one existing warning: the game remains unavailable in Korea pending its GRAC rating/review.

All six one-time Play products have one active purchase option. The existing backend service account is ACTIVE and has View financial data / Purchases API permission; no extra permissions were granted. RTDN is enabled for subscriptions, voided purchases and all one-time products on the correct Firebase topic. A Console test notification reached the deployed handler and was recorded as an ignored non-purchase test at 2026-09-09 12:32:49 UTC.

AdMob account approval and ad serving are enabled, but WILDCARD itself is marked **Limited ad serving / Requires review** because its store listing is not linked. Exact-package search did not find the closed-test app. Google states that private Google Play apps cannot be linked; the listing must be publicly available in a supported store. This external restriction is not bypassed by build flags. WILDCARD's European regulations consent message is published; the account also shows one active US-state message. No consent settings were weakened. [AdMob store-link requirements](https://support.google.com/admob/answer/10037806?hl=en).

Production access is not enabled: Console reports two opted-in closed testers, with a requirement for at least 12 for 14 days. Adding an email to a list is not the same as that person opting in.

Protected remote refs were rechecked unchanged: `main` at `5a1a0d0f82a6b25415760bc7a77085a4e4fa3dd1`, `agent/flutter-v8-native-beta` at `26e0f30f1a7b27ef75d1d5cbd8dab1d83ca3e8de`, and `agent/flutter-v8.2.0-dev14-feel` at `0b3e9fa42b872ac7b65509aa3d3ed67a9b3e2c59`. No merge into main was performed.

## Honest verification boundary

Phone disconnected: no new device installation, live purchase, ad impression/click, refund, actual purchase/refund RTDN payload or cross-device paid restore was performed. The transport-only test above does not prove purchase verification. Correct IDs, deployed functions and mocked lifecycle tests do not prove unrestricted AdMob fill or actual Play payment completion. Follow the license-tester checks in the billing note before claiming live monetization verified. Do not click live ads for testing or weaken App Check to make a sideload work.

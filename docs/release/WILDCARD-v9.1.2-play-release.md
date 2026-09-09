# WILDCARD 9.1.2 / code 76

Release preparation: 2026-09-09. Branch: `release/v9.1.2-play-billing`.

## Scope

Promotes the current official phone-polish source (baseline `5844ba2d20457a2690c5ae3d35216719f4f62251`) to a public, ads-enabled closed-test build. Includes randomized/cycling free starter choices, four new preview room themes, the shop gallery, loading/coin polish and the latest heading-contrast correction. Existing Astra-derived economy/progression work is retained, not retuned in this release. No scoring, Joker mathematics, prices, package identity, signing key, consent policy or test-track enrollment changes.

Major billing fixes: atomic server coin/receipt delivery, durable interrupted-purchase recovery, ownership checks, refund revision handling, and safe account transitions. Remove Ads now restores both activation and revocation; an interstitial finishing its load after Remove Ads activates is discarded. Optional rewarded ads remain voluntary and are not removed by the forced-ad entitlement. See [billing verification](v9.1.2-validation/billing-verification.md) for protocol details and live-test limitations.

## Build and checks

- Flutter 3.44.7 / Dart 3.12.2; `flutter build appbundle --release --no-pub`, with no owner/offline/test-ad defines. Build completed in 349.7 seconds.
- Full public Flutter suite: 520 passed, two experiment-only skips. Final narrow account-transition guard was subsequently covered by 11 passing focused billing tests.
- Full Flutter analysis after the final client changes: no issues.
- Backend final suite: 31 passed. Ad lifecycle/public-policy checks: 18 passed, including the reproduced Remove Ads loading race.
- Bundletool validation passed. AAB JAR signature verified against the existing release certificate. Universal APK derived from this exact bundle verifies with APK signature schemes v2/v3.
- Package `com.nisarg.wildcard`; version 9.1.2/code 76; min SDK 24, target SDK 36. INTERNET and Play BILLING permissions present.
- Manifest uses owned AdMob app ID `ca-app-pub-3855192091371080~7622357185`. Automatic Firebase/AdMob startup providers remain removed so initialization stays behind the app's privacy gate.
- Original public catalog/owner-dev isolation and no Levels/Arcade mode remain unchanged. Phone-only no-ads flag is not used.
- Signing SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.

Artifacts are outside Git in `official-v9.1.2-delivery/` next to the repository:

| Artifact | SHA-256 |
| --- | --- |
| WILDCARD-v9.1.2-code76.aab | `4fffcc63b2045e3c574517f39e86e8c691af6c19681b92e5de4e34a94ae140fc` |
| WILDCARD-v9.1.2-code76.apk | `6899582f7c45eddd49a6f9b9664cbf378936ff0413b0d587941095beadc251f5` |

## Backend deployment

Deployed only the seven compatible billing/cloud functions to `wildcard-31d50`, `europe-west2`: verifyPlayPurchase, fulfillPlayPurchase, markPlayPurchaseDelivered, getPlayEntitlements, playBillingNotification, readSecureCloudSave and writeSecureCloudSave. The final read/refund/RTDN patch was then redeployed to readSecureCloudSave and playBillingNotification. Both deployments completed successfully; subsequent inventory shows all seven ACTIVE. No Firestore rules, hosting, account data or tester records were changed.

Retain this compatible backend if halting/rolling back the client release; do not remove protocol-2 guards after new receipts exist.

## Play status

Before upload, Console showed closed-test Alpha version 8.5.3/code 72 live, an obsolete code-34 draft, and code 34 still on the separate internal track. Code 76 was unused. The old bundle was removed from the Alpha draft only (it remains in the artifact library), and the new code-76 bundle upload was started. Final submission/review status must be recorded below after Console confirms it.

Production access is not enabled: Console reports two opted-in closed testers, with a requirement for at least 12 for 14 days. Adding an email to a list is not the same as that person opting in.

## Honest verification boundary

Phone disconnected: no new device installation, live purchase, ad impression/click, refund, RTDN delivery or cross-device paid restore was performed. Correct IDs, deployed functions and mocked lifecycle tests do not prove AdMob approval/fill or actual Play payment completion. Follow the license-tester checks in the billing note before claiming live monetization verified. Do not click live ads for testing or weaken App Check to make a sideload work.

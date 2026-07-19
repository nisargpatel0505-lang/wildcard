# WILDCARD v6.9.14 — release notes

Status: **active on the Google Play internal-testing track**

## Release identity

- Package: `com.nisarg.wildcard`
- Public version: `6.9.14`
- Play/release version code: `34`
- Local developer APK version code: `33`
- Canonical HTML SHA-256: `b34c7cd44834a6468b058b0250c5d6810479f5e299b167a09e8cb5eabd46478b`
- Release APK SHA-256: `51e9f6257497145076bb47aeaf09bb1c2956df9161549e1bc1506e42bd63428d`
- Release AAB SHA-256: `2a846559c074b2fc2818a1d7afcfd693571108c7c7bb5511064c6ad123716693`
- Developer APK SHA-256: `feb2039e41f52c4093aa11533db2f8b8165fa4219985592d0bdbbcaa9f38b413`
- Release signer certificate SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`
- Tester opt-in: <https://play.google.com/apps/internaltest/4699904654718813987>

The APK and AAB each contain an `index.html` that matches the canonical source
byte-for-byte. Bundletool validation and APK/AAB signature checks passed.

## Security and backend

- Public save import and Friend Codes were removed, closing the portable
  economy/score forgery and injected-HTML paths.
- Cloud saves now use authenticated, App-Check-protected callable Functions.
  Direct Firestore save access is denied.
- Cross-account save merging was removed. Server-owned purchase entitlements
  and adjustments cannot be supplied by the client.
- Google Play purchases use server verification, durable token records,
  idempotent delivery, pending/process-death recovery, localized Play pricing
  and real-time developer notifications.
- The Daily Board accepts authenticated Firebase callable submissions and a
  server-signed Firebase-to-Pi request. The public Pi write route rejects
  unauthenticated submissions.
- First launch blocks cloud, ads, billing and telemetry until the player accepts
  the versioned Privacy Policy.
- Settings provides typed-confirmation account deletion. The public deletion
  resource is live at
  <https://wildcard-31d50.web.app/account-deletion.html>.
- The non-working Haptic Feedback preference was removed. Internal native
  feedback calls remain.
- Firebase App Check and Play Integrity APIs are enabled. The Android app is
  registered with Play Integrity, Play Console is linked to Cloud project
  `420107184674`, and Cloud Firestore App Check enforcement is active.
- All nine second-generation Functions are active in `europe-west2`.

## Ads and billing

- Production builds contain the owner AdMob app, rewarded and interstitial unit
  IDs. Google demonstration IDs are limited to the developer variant.
- Ad serving can remain limited until AdMob completes app review and the Play
  listing is linked.
- Billing code is ready for trusted delivery, but real-money products cannot be
  activated until the Play Console merchant account, payments profile,
  tax/bank details and product catalogue are completed by the account owner.
- Daily Board coin prizes remain disabled until score attestation and a
  server-authoritative settlement ledger exist.

## Gameplay and mobile fixes

- The House blocks exactly two stable, randomly selected equipped Jokers.
- Prism Lens accepts five same-colour cards when The Cheat adds a sixth card.
- Glass Joystick now states and uses a one-in-six destruction chance.
- The Deck matrix uses the game's real Ace value.
- Daily attempts are deterministic, resumable and isolated from normal
  progression.
- Luck outcomes are checkpointed so force-closing cannot reroll them.
- Vault odds use the exact remaining eligible pool. The Wooden Vault costs
  60 coins until 15 Jokers are owned, then returns to 100; Gold remains 300.
- Themes reach the remaining overlays and secondary surfaces.
- Safe-area handling, dialog semantics/focus/Escape, touch targets, important
  text sizes and small-screen collection navigation were hardened.
- Android 16, foldable, tablet and Chromebook window handling no longer relies
  on a forced portrait manifest lock.

Scoring pace and the Joker trigger animation were intentionally not changed.
The first-loss chest and special 320×568 layout work also remain outside this
release.

## Verification

- Full project test suite: passed.
- Gameplay-hardening checks: 30/30.
- Firebase Functions tests: 11/11.
- Firestore Rules emulator tests: 29/29.
- Focused deterministic regression: 10,000 scoring cases, 5,000 Cheat checks
  and 550 complete runs.
- Regression failures, invariant failures, hook errors and Cheat mismatches: 0.
- Production/developer AdMob separation: passed.
- Pi API security/analytics checks: passed.
- Connected-phone developer build: launches without crash or ANR, preserves the
  existing save and displays the mandatory privacy gate correctly.

The signed code-34 AAB was published as `WILDCARD v6.9.14 internal test`.
Google Play reported only the non-blocking deobfuscation/native-symbol warnings.

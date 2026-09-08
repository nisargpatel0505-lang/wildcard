# WILDCARD 9.1.1 — release checklist

Reviewed 8 September 2026. **Phone-test candidate only. Google Play is unchanged;
this work does not publish a release.** The owner APK disables ads using a
build-only switch. It must not be distributed as the public ad-supported build.

## Verified in source and targeted checks

- **Separate owner/public ad behaviour.** `WILDCARD_OWNER_NO_ADS` defaults to
  false. The owner override blocks ad consent SDK calls, initialization,
  loading and showing, and hides ad offers. It neither awards pretend ad
  rewards nor changes the saved, purchased Remove Ads entitlement. Public
  release defaults retain owned AdMob units, consent gating, optional rewarded
  ads and the existing forced-interstitial policy. Billing remains enabled.
- **Bundle safeguard.** Android rejects owner-no-ads bundle/publishing tasks.
  An owner APK dry-run succeeded; an owner AAB dry-run failed with the intended
  safeguard. Fourteen public-configuration tests and six owner-configuration
  tests passed; targeted static analysis was clean. These checks establish
  code behaviour, not a verified live ad impression.
- **Existing purchase protection is implemented.** The Flutter billing service
  calls server receipt verification, persists a verified grant before finishing
  the purchase, and supports unfinished-purchase recovery. Firebase contains
  purchase-token ownership/delivery records and refund/revocation handling.
  This is implemented code, not proof that every deployed purchase flow works.
- **Account and board protections exist.** Protected cloud, account-deletion
  and Daily Board calls require authentication and App Check. The board uses
  server-assigned dates, name ownership, rate limiting and idempotent requests.
  Do not treat the older unauthenticated-board or missing-deletion findings as
  the current implementation.
- **Economy scope is retained.** This polish pass does not retune public
  payouts, Vault prices, rewards or Google Play product quantities/prices.
  Starter selection now rotates eligible unlocked Jokers by engine. Its
  12-run smoke check is not a new full balance study. The prior 9.1.0 simulation
  evidence remains useful for its tested configuration, but cannot establish
  every outcome of the expanded starter choices.

Source: [ad service](../../flutter_app/lib/services/ad_service.dart),
[build switch](../../flutter_app/lib/core/build_options.dart),
[Android safeguard](../../flutter_app/android/app/build.gradle.kts),
[billing service](../../flutter_app/lib/services/billing_service.dart),
[billing backend](../../functions/billing.js),
[account and board backend](../../functions/index.js),
[9.1.0 delivery evidence](WILDCARD-v9.1.0-delivery.md), and
[retained economy evidence](v9.1.0-economy/ECONOMY-UPDATE.md).

## Still needs validation before public release

1. **Owner playtest acceptance.** Check starter rotation and cycling, tutorial
   completion, resume-after-restart, scoring readability, Vault reward claiming,
   and the new live theme on the actual phone. Check small screens, larger text,
   reduced-motion behaviour, sustained frame pacing and background/resume.
   Bots cannot establish enjoyment or comfortable animation speed.
2. **Play-installed online services.** The previous signed sideload encountered
   Play Integrity/App Check rejection. Confirm a Play-installed candidate can
   sign in, save and restore progress, post/retry a Daily score and open official
   rankings. Test account deletion using a disposable test account. A handled
   cloud error protects the local save but does not prove successful backup.
   Do not weaken App Check to make this checklist pass. Firebase documents how
   [app recognition depends on distribution channel](https://firebase.google.com/docs/app-check/android/play-integrity-provider).
3. **End-to-end payments.** Existing evidence confirms localized product
   metadata loaded, not successful payment fulfillment. Using configured Play
   license testers, verify approved, declined and pending coin purchases;
   interruption/restart without lost or duplicate grants; Remove Ads purchase
   and restore; and refund/revocation reconciliation. Check server permissions
   and notification delivery during those tests. Ordinary closed testers can
   incur real charges unless also configured as license testers; follow
   [Google's billing test procedures](https://developer.android.com/google/play/billing/test).
4. **Public ad behaviour.** Use a separate ad-enabled test build/device to check
   consent, rewarded completion/cancellation, the daily reward cap, forced-ad
   cooldown and paid forced-ad removal. Proper owned IDs in source do not prove
   AdMob approval, live serving, consent configuration or revenue. Use Google's
   [test-ad procedure](https://developers.google.com/admob/flutter/test-ads) for
   testing; never click live ads to validate the integration. The owner phone
   build deliberately cannot provide this evidence.
5. **Exact public artifact and Console review.** After owner acceptance and
   explicit publication approval, build a fresh AAB from the accepted commit
   without the owner-no-ads or offline-experiment flags. Verify version/code,
   package, signing identity and public configuration; update any hardcoded
   workflow version assertions. Review the resulting Play pre-launch report,
   upgrade behaviour and current store/data-safety declarations. Do not reuse
   an older AAB merely because its filename matches.
6. **Production eligibility.** Current opted-in tester count, continuous testing
   duration and production-access status were not verified in this review.
   For applicable personal developer accounts, Google requires a **closed
   test with at least 12 testers continuously opted in for 14 days**, followed
   by an application for production access. An email list is not an opt-in
   count, and internal testing does not satisfy this requirement. See the
   [current Google Play requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

## Deliberately not activated

Daily leaderboard coin prizes remain disabled. Authentication, App Check and
range checks reduce abuse, but the current submission service does not replay
the run to prove its score. Authoritative score validation, settlement rules
and an idempotent prize ledger are prerequisites before activating prizes.
Their absence is not a reason to enable unverified rewards during this polish
pass.

No Console changes, backend deployment, real purchase, live-ad click or account
deletion was performed for this checklist. No private player data or signing
material is included.

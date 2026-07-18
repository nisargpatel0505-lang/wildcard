# WILDCARD v6.9.10 Release Decision

**Evidence date:** 17 July 2026

**Canonical source:** `www/index.html`

**Source SHA-256:** `116d1878b733667b2fdb87c28e9ed38b5f8010288894e11bbebe9cf9a4c81521`

## Executive summary

WILDCARD v6.9.10 is a defensible **internal/closed-test candidate**, but it is not yet a defensible public monetized release. The game source, release packages, Pi-hosted APK and the six v6.9.10 fixes are present and verifiable. The release APK and AAB contain the canonical HTML, the production package excludes developer controls, and the full test suite is bound to source and simulator hashes.

The remaining work is mostly service hardening and Play/AdMob operations rather than core game construction:

1. Replace Google's demo AdMob IDs and test mode with owner-created production units, then validate consent and real-device delivery without clicking live ads.
2. Stop treating the custom Pi Daily Board as authoritative until score submissions are authenticated/attested. It is publicly reachable, but the current POST accepts a client-supplied name, date and score without proof.
3. Verify the Play-installed build end-to-end for Google sign-in, App Check/Play Integrity, Play Games leaderboards and Billing products. Repository checks cannot prove console publication or product activation.
4. Complete the relevant Play listing, Data Safety, privacy, content-rating and testing requirements.

The previous handoff's seven-strategy percentages were not reproducible. A new source-bound lab ran seven explicit policies across 400 deterministic seeds each (2,800 complete runs). Flush-focused play led at 36.5%; adaptive greedy followed at 29.25%. This is bot-policy evidence for balance work, not player telemetry.

## What was verified

| Claim | Result | Direct evidence |
| --- | --- | --- |
| Locked Stake Contract hides details | Pass | `renderStake()` emits only `🔒 Locked` until unlocked; verifier rejects leaked locked-state copy. |
| Unlocked contract uses numbered steps | Pass | `stakeSteps()` renders a three-item ordered list. |
| Mobile Back control is top-left and safe-area aware | Pass | Fixed 44×44 control at `7px + env(safe-area-inset-*)`; responsive assertion covers the rule. |
| Normal scoring gained only 4% breathing room | Pass | Normal `1.04`, Fast `0.55`; optimized beats and unscaled terminal waits are asserted. Win FX and gameplay sparks remain absent. |
| Android Daily Board reaches the Pi | Pass, with integrity caveat | Native `localhost` resolves to the absolute Pi origin; live health and Daily GET return HTTP 200. |
| Home layout remained the approved v6.9.9 design | Pass | v6.9.10 changes the version label without reintroducing top-level Daily/developer actions or duplicate Start Boost navigation. |

Additional verified properties:

- Release APK SHA-256: `e02eb3b5e6e360c8571e121a8376353221a4f15039a46c21656cbf77b6e40782`.
- Release AAB SHA-256: `2917dc42f60b9cdd947300f6a204151aad0dbabefb95c7be208b2d83f9d986e8`.
- Pi public APK download produces the same release APK hash.
- Pi health reports `analytics: aggregate-v1`; the analytics database has no public read route.
- The telemetry client is non-blocking, bounded in memory, identifier-free and limited to app-open/run-start/run-end aggregates.
- The production APK/AAB exclude developer controls. The separately versioned developer APK retains them for local testing.

## Reproducible strategy comparison

The strategy lab uses the current source and current `tools/deep-sim-v57.js`, records both hashes, saves every seed-level result, resets deterministic phase streams, calculates Wilson 95% intervals and retains paired win/loss counts. Different choices can consume randomness differently after a phase begins, so this is a paired reproducible comparison—not a claim that every later draw remains identical.

| Strategy | Heat 12 wins | Win rate | Wilson 95% CI | Reach H9 | Reach H11 | Avg cleared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Flush engine | 146 / 400 | **36.50%** | 31.93–41.33% | 96.50% | 85.50% | 10.87 |
| Adaptive greedy | 117 / 400 | 29.25% | 25.01–33.89% | 90.50% | 68.00% | 10.17 |
| Economy hoarding | 82 / 400 | 20.50% | 16.83–24.73% | 76.50% | 57.75% | 9.48 |
| Utility and niche | 82 / 400 | 20.50% | 16.83–24.73% | 85.75% | 59.25% | 9.73 |
| Cheat + hand synergy | 46 / 400 | 11.50% | 8.73–15.00% | 78.00% | 48.50% | 9.14 |
| Pair/rank boosting | 32 / 400 | 8.00% | 5.72–11.08% | 83.75% | 45.50% | 9.20 |
| xMult stacking | 10 / 400 | 2.50% | 1.36–4.54% | 83.75% | 50.00% | 9.27 |

Flush-policy conversion by Heat, derived from the 400 retained seed-level outcomes:

| Heat cleared | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Runs | 400 | 400 | 400 | 400 | 400 | 396 | 393 | 386 | 361 | 342 | 323 | 146 |
| Rate | 100% | 100% | 100% | 100% | 100% | 99.00% | 98.25% | 96.50% | 90.25% | 85.50% | 80.75% | 36.50% |

Interpretation:

- The modeled Flush policy is the strongest of the seven implemented policies. It beat adaptive greedy on 93 paired seeds where greedy lost; greedy won on 64 seeds where Flush lost.
- Heat 12 is the dominant modeled cliff: 323 Flush runs cleared Heat 11, but only 146 cleared Heat 12 (45.2% conversion among Heat-12 entrants).
- xMult forcing reaches later Heats reasonably often but rarely converts Heat 12, consistent with insufficient flat-mult foundations.
- Cheat-focused, Pair/rank and xMult results are policy results, not proof that the underlying Jokers are individually weak. The policy definitions and purchasing heuristics must be reviewed before making large balance changes.
- The correct next evidence is a small human closed test with event-level, privacy-safe progression funnels—not another single headline bot percentage.

Full inputs and raw outcomes are in `docs/release/wildcard-v6.9.10-strategy-results.json`; the readable output is `docs/release/wildcard-v6.9.10-strategy-report.md`.

## Revenue sensitivity—not a forecast

The current build uses Google's sample AdMob application and ad-unit IDs with `AD_TESTING=true`. It therefore earns **£0 in production ad revenue** as currently configured.

The separate executable sensitivity model makes fill rate, impressions, eCPM, MAU/DAU, payer conversion, ARPPU and Play fee explicit. Modeled monthly proceeds combine ads and IAP after the scenario Play fee, but before VAT/tax, refunds, chargebacks and FX:

| Daily active players | Low | Base | High |
| ---: | ---: | ---: | ---: |
| 50 | £8.79 | £42.30 | £111.19 |
| 200 | £35.14 | £169.20 | £444.75 |
| 1,000 | £175.73 | £846.00 | £2,223.75 |
| 10,000 | £1,757.25 | £8,460.00 | £22,237.50 |

These are scenario outputs, not expected revenue. No WILDCARD retention, geography, fill, eCPM, payer-conversion or ARPPU telemetry exists yet. The fee is deliberately a 15%/25%/30% sensitivity because the applicable Play commercial terms vary by program, transaction and market.

## Release blockers and risks

### Must resolve before a public monetized launch

- **AdMob production configuration:** create/approve the real app and ad units, remove demo IDs/test mode from the release variant, retain test devices for development, complete consent/privacy configuration and verify fail-soft behavior.
- **Leaderboard integrity:** the Pi endpoint validates shape and ranges but accepts unauthenticated scores. Use published Play Games leaderboards as the authoritative competitive board, or add server-verified identity plus Play Integrity/App Check attestation before trusting Pi submissions.
- **Play services on a Play-installed build:** verify Google sign-in, Firestore backup/merge, App Check enforcement, Play Games achievement/leaderboard publication and all time spans.
- **Billing:** confirm every source product ID exists and is active in Play Console; test purchase, acknowledgement, consumable re-purchase, restore/remove-ads and cancelled/refunded states with licensed testers.
- **Store compliance:** finish the listing, privacy URL, Data Safety, ads declaration, content rating, target-audience choices and current testing/production-access requirements.
- **Developer-build code hygiene:** old tracked APKs contain the historical plaintext developer-code comparison, so that reused code must be treated as public. The v6.9.10 production packages contain no developer surface, but rotate the code before distributing any future developer APK.

### Appropriate for internal/closed testing now

- Core gameplay, save migration, source/package provenance and Pi delivery are testable now.
- Keep test ads during tester builds until production AdMob units and consent behavior are ready.
- Do not present the custom Pi board as cheat-resistant.
- Preserve the current developer APK separately; do not upload it to Play.

## Release distance

Engineering readiness is close: v6.9.10 can enter or continue internal/closed testing after this evidence is committed. Public-release timing is controlled by console setup and the developer account's applicable testing gate. For new personal accounts that fall under Google's published rule, production access requires at least 12 opted-in testers for 14 continuous days. Because that account condition cannot be proven from source, it must be checked in Play Console rather than assumed.

A reasonable planning range is:

- **Internal/closed test:** now, once the exact AAB is selected and console diagnostics are checked.
- **Public non-monetized/limited release:** roughly 2–3 weeks if the 14-day gate applies and no policy rejection occurs.
- **Public monetized release:** roughly 3–4 weeks if production Ads/Billing, consent, leaderboard integrity and Play-installed service tests are completed in parallel. This is a dependency-based estimate, not a guaranteed date.

## Recommended next sequence

1. Commit and review this exact v6.9.10 source, artifacts, full stress evidence, strategy lab and revenue model on GitHub.
2. Upload only `releases/WILDCARD-v6.9.10.aab` (version code 29) to the intended Play test track and record Play's artifact digest/status.
3. Run a Play-installed device checklist for save preservation, Auth, Firestore, App Check, Play Games, Billing and ad consent/test delivery.
4. Choose the authoritative leaderboard path. Prefer Play Games for official rankings; keep the Pi Daily Board cosmetic/non-authoritative until submissions are attested.
5. Recruit/retain the required testers, monitor crash/ANR and coarse progression funnels, then make only evidence-backed balance changes.

## Evidence files

- `docs/release/WILDCARD-v6.9.10-fix-notes.md`
- `docs/release/wildcard-v6.9.10-sim-results.json`
- `docs/release/wildcard-v6.9.10-sim-report.md`
- `docs/release/wildcard-v6.9.10-strategy-results.json`
- `docs/release/wildcard-v6.9.10-strategy-report.md`
- `docs/release/wildcard-v6.9.10-economy-results.json`
- `docs/release/wildcard-v6.9.10-economy-report.md`
- `docs/release/wildcard-v6.9.10-revenue-sensitivity.json`
- `docs/release/wildcard-v6.9.10-revenue-sensitivity.md`
- `analysis/WILDCARD-v6.9.10-strategy-revenue.ipynb`

Official operational references:

- Google test ads: <https://developers.google.com/admob/android/test-ads>
- Google Play testing requirements: <https://support.google.com/googleplay/android-developer/answer/14151465>
- Google Play service fees: <https://support.google.com/googleplay/android-developer/answer/112622>
- AdMob payment thresholds: <https://support.google.com/admob/answer/2772208>

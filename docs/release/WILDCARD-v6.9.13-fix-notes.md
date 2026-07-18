# WILDCARD v6.9.13

## Release intent

v6.9.13 turns run-shop supplies into a persistent, readable run economy: an offer can be used once in its shop, and repeatedly choosing the same supply in later shops makes that specific supply cost more for the rest of the run.

## Supply pricing and shop rules

- Every supply offer can be bought only once in a shop round.
- Buying one offer does not block the other supply offer in that shop.
- Each specific supply has its own run-long purchase count.
- A supply costs two more run coins after each successful use: for example, Scalpel progresses from 3 to 5 to 7.
- Other supplies keep their own price progression; buying Scalpel does not make Copier more expensive.
- Temporary Inflation is added to the persistent run price and disappears normally when the modifier ends.
- Starting a new shop clears only the current-shop purchase locks. It does not reset the run-long price history.

## Atomic purchase safety

- The app rechecks affordability, pending Joker swaps, and current-shop purchase state at the moment an effect commits.
- The current-shop lock is written before the supply mutates the deck or run.
- A failed effect rolls that lock back.
- Coins are charged once and the persistent purchase count advances only after a successful effect.
- Repeated taps or a stale picker callback cannot mutate the run twice or receive an effect without paying.

## Save and mode compatibility

- Per-supply purchase counts and current-shop locks are included in the run checkpoint.
- Resume normalizes malformed or duplicate IDs before restoring the shop.
- Older saves safely start with empty per-supply history because the retired shared counter could not reconstruct which individual supplies had been bought.
- Normal, Daily and Gauntlet use the same live pricing and purchase locks.
- Daily retains its existing no-resume/checkpoint policy; Gauntlet checkpoints normally.

## Phone UI

- Purchased supplies stay in place so the two-column shop grid does not jump.
- Their action changes to `✓ Bought this shop` and becomes disabled.
- The card shows the price that supply will have in the next shop.
- The shop heading explains the rule in one compact line.
- Phone-width Chromium validation at 393×873 confirmed readable cards, stable layout, correct independent pricing, and no runtime errors.

## Verification

- Canonical HTML SHA-256: `499c1ebe75a5346e7fe3c06cf0b0328cc29e32e90d62a77b237071ffeaa2bab9`
- 10,000 scoring/Joker cases passed.
- 5,000 Cheat comparisons passed with zero mismatches.
- 550 complete runs passed with zero data, hook, or invariant failures.
- Executable supply tests passed for independent 3→5→7 pricing, shop reset behavior, temporary Inflation, affordability and pending-swap guards, cancel/throw rollback, stale double completion, save/resume, legacy migration, Daily and Gauntlet.
- The complete regression suite passed, including Heat-12 cinematic/ad/choice routing, service-worker MP4 Range handling, native ads and Billing callbacks, reward idempotency, and Pi analytics privacy.
- Google/Firebase repository configuration audit passed with no failures or warnings.
- Release APK and AAB contain the canonical HTML and Sly video byte-for-byte.
- APK signature verification passed with the existing release certificate.
- AAB JAR signature verification passed.

## Android artifacts

- Developer APK: `releases/WILDCARD-v6.9.13-developer.apk` — SHA-256 `8dfc47077b6ef823b28c058e90aaebd83e5dfef7f090a55bbbfc00d8dc4bfa84` — version code 32
- Release APK: `releases/WILDCARD-v6.9.13.apk` — SHA-256 `d92e9be8e32f50717b9474dc934b7a4d76ddc2690a050966fdbe665801777958` — version code 33
- Release AAB: `releases/WILDCARD-v6.9.13.aab` — SHA-256 `cc07440391da28e160608534085cbccc83587c8aec48578488164ab423fbc259` — version code 33
- Release certificate SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`

The developer APK was installed in place on the POCO X7. Android retained the original `2026-07-13 08:55:06` first-install timestamp, and the existing Best Heat 20 and 578-coin save loaded after launch.

The release APK/AAB are signed locally. Uploading the AAB to Play Console and deploying the APK/PWA to the Pi remain separate explicit release actions.

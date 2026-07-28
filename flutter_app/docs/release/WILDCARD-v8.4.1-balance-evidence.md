# WILDCARD v8.4.1 balance evidence

Date: 2026-07-28

Branch: `agent/flutter-v8.4.1-sim-balance`

This owner profile update applies the simulation-derived v8.4.1 balance map
without changing poker hand values, the save schema, backend integrations,
package identity, or production signing.

## Player-facing balance changes

- Easy target multiplier: `0.75` to `0.60`.
- Heat Surge: `+0.20` to `+0.12` Multiplier per cleared Heat.
- Butcher: `+0.50` to `+0.30` Multiplier per destroyed card.
- Overclock: `x3` to `x2.4`.
- Rainbow: `x2` to `x1.8`.
- Triple Threat leaves the starter pool and unlocks at 40.
- Face Value becomes a free Rare starter.
- Public rarity totals are pinned at 36 Common, 36 Uncommon, 23 Rare, and
  7 WILD.
- Starter rarity totals are pinned at 8 Common and 2 Rare.
- Run-shop price guards now enforce Common 4-6, Uncommon 5-7, Rare 6-8,
  and WILD 10-12 coins.

The supplied prompt's per-Joker labels are authoritative. Its summary claimed
11 Common / 19 Uncommon / 11 Rare / 4 WILD for the 45 expansion Jokers, but
the listed entries actually total 11 / 18 / 12 / 4. Existing save-compatible
IDs `ace_in_the_hole` and `warm_up` were retained instead of renaming them.

## Rule correctness repairs

- Understudy duplicates the highest rank for hand detection only; the
  synthetic card can no longer score.
- Leadoff advances to the first live scoring card when an earlier card is
  suppressed by Heartless, Frostbite, or Counterfeit.
- Gap Filler applies only to a five-card, five-unique-rank Straight spanning
  six ranks.
- Blood Money keeps its advertised `x1.8` at zero coins while its one-coin
  payment floors safely at zero.
- Twin Study follows the supplied `2+ copies` rule. This intentionally means
  an untouched standard deck satisfies its four-rank requirement.

## Balance harness

The previous fixed-starter/solo contribution method was replaced with matched
five-Joker cohorts:

- treatment: the forced Joker plus four deterministic random teammates;
- control: one random replacement plus the exact same four teammates;
- pair treatment: two forced Jokers plus three shared teammates;
- Medium and Easy are supported;
- shop offers remain limited with `allJokersUnlocked: false`;
- progress measures cleared Heats plus exact failed-Heat score/target;
- DEV x20 is excluded from every public pool;
- top-12 pairs over 70% Medium win rate emit `PAIR_OVER_70`.

The harness defaults to 200 runs and remains opt-in because the full
102-Joker sweep is intentionally heavyweight.

## Verification

- `flutter analyze`: no issues.
- Focused balance/structural/harness suite: 104 passed, 1 expected opt-in skip.
- Complete Flutter suite: 322 passed, 1 expected opt-in skip.
- Deterministic complete-run test: 2,000 runs, zero invariant failures.
- Price check and price self-test: pass.
- Rarity assignment and guarded apply self-tests: pass.
- APK package: `com.nisarg.wildcard`.
- APK version: `8.4.1` (`versionCode 63`).
- APK profile SHA-256:
  `F7ACA82883A480C4111AB01C02274736106D465E9704F1B71AA766049B54E2B8`.
- Signing certificate SHA-256:
  `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.
- Connected POCO device upgraded in place from v8.4.0 code 62 to v8.4.1
  code 63 with `adb install -r -t`.
- Launch sanity check passed, with the existing 1,630 coins, Best Heat 21,
  title, and resumable run still visible.

The owner profile APK is a local validation artifact and is not committed to
the public repository.

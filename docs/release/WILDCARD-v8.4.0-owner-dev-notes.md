# WILDCARD v8.4.0 — owner development notes

## Release intent

v8.4.0 expands the native Flutter game with 45 new Jokers, 10 new table cosmetics, and a deterministic strategic-bot simulation harness. This is an owner-development build for balance validation; it is not a Play Store release artifact.

Version: `8.4.0+62`

Working branch: `agent/flutter-v8.4.0-smart-jokers-tables`

Branch baseline: `be2c074ebbb58d769f3116b19368dd34bb0f8157`

## Implemented scope

- Added 45 public Jokers, taking the public catalogue from 57 to 102.
- Implemented scoring, structural-hand, stateful, risk, deck-state and deterministic-RNG effects for all 45 additions.
- Added focused coverage for all new effects, including preview-versus-commit RNG safety and the structural hand recognizers.
- Added 10 tables at the requested prices: six efficient procedural designs and four cached WebP-backed premium designs.
- Added a deterministic adaptive bot that examines every legal play, makes completion-aware discards, judges target pace and hands remaining, and buys synergistic Jokers, supplies and boosts.
- Added opt-in single-Joker and Joker-pair contribution audits, sharded runners, ranked CSV merging, and an economy projection tool.
- Kept the authoritative scoring result, save schema, backend, ads, billing and cloud behaviour outside this change.

## Owner-only DEV Joker warning

`DEV ×20` remains available only in non-product owner builds. Flutter product/release builds exclude it from the public catalogue.

The owner APK must be built in profile or debug mode for device validation and must never be uploaded to Google Play, shared with testers, copied to the Pi, or treated as a production artifact.

## Verified evidence

- `flutter analyze`: clean, with no diagnostics.
- Full Flutter suite: 277 tests passed and one expected opt-in heavy balance audit was skipped by default.
- New Joker expansion suite: 48 of 48 tests passed.
- Strategic-bot tests passed for byte-for-byte determinism, materially better matched-seed performance than the random bot, and behaviour distinct from the greedy policy.
- The pure-Dart AOT balance runner compiled successfully.
- The final-catalogue 1,000-run adaptive baseline completed with zero invariant failures:
  - Wins: 55
  - Win rate: 5.5%
  - Average terminal Heat: 11.030
  - Average Heats cleared: 10.085
  - Average score: 9,029.52

## Final simulation evidence

- Single-Joker arms completed: `102 / 102`
- Joker-pair arms completed: `66 / 66`
- Runs per arm: `1,000`
- Invariant or determinism failures: `0`
- Strongest solo Joker: `Flush Fund`, 56.5% win rate and `+50.7` percentage points versus the measurement baseline.
- Weakest solo Joker: `Shortcut`, 0.6% win rate and `-5.2` percentage points versus the measurement baseline.
- Strongest tested pair: `Rule Breaker + Safe Cracker`, 80.6% win rate and `+75.1` percentage points versus the final-catalogue baseline.
- Pairs above the 70% win-rate guardrail: `20 / 66`. These are retained and flagged rather than silently nerfed because this task required the specified effects exactly.
- Final rarity split: `42 common / 32 uncommon / 20 rare / 8 WILD`
- Pair Polisher final rarity: `Uncommon`
- High Roller final rarity: `Uncommon`
- Final public Joker chest sink: `10,540 coins`
- Final full direct collection sink: `83,190 coins`
- Economy decision: keep the cheap Joker/chest prices. The model projects about 201–289 days for a casual full collection and 112–147 days for a dedicated one depending on rewarded-ad use. The total is slightly below the model's 88,000-coin planning floor, but raising gameplay-unlock prices would conflict with the explicit no-paywall goal.

Committed evidence files:

- Solo ranking CSV: `docs/release/wildcard-v8.4.0-joker-balance.csv`
- Pair ranking CSV: `docs/release/wildcard-v8.4.0-joker-pairs.csv`
- Economy report/results: `docs/release/wildcard-v8.4.0-economy-results.json`

## Owner APK and phone validation

- Build mode: `Profile — owner-only`
- Local APK path: `flutter_app/build/app/outputs/flutter-apk/app-profile.apk`
- APK size: `129,058,016 bytes`
- APK SHA-256: `e1abf29a6b4c857a3a1ecde4029fbd2234b8a6f6f5fc99e0186b13fd98c414ff`
- Package/version verified from the APK: `com.nisarg.wildcard`, `8.4.0` (`62`)
- Device: `POCO X7 — Android 16`
- Device serial used for validation: `6TLZJV89Q4TCHYMN`
- Provisional install result: `Success` before the owner disconnected the phone.
- Provisional launch/smoke result: launched successfully; Collection reported 102 public Jokers and Wardrobe showed all 10 new tables.
- Existing save retained in provisional smoke: `3,456 coins`, `Best Heat 21`.
- Final exact APK install: `Pending phone reconnection`. The final APK differs by measured rarity/price assignments and the Understudy four-of-a-kind edge-case fix.

The owner APK is intentionally excluded from Git and must not be published.

## Known owner-development follow-ups

- Twenty elite pair combinations exceeded the requested 70% Medium guardrail. Review those combinations with real playtesting before a public balance freeze.
- The four premium 1024px WebP table tiles are efficient placeholders with a source `TODO` for final AI artwork, seam/contrast QA and final-device memory checks.
- New structural Jokers score correctly but, like existing Shortcut, Pocket Flush and The Cheat, do not yet emit a dedicated non-arithmetic proc animation. A later presentation pass should add a purpose-built event rather than a misleading zero-value score beat.

## Protected branch record

This work must not modify or merge into:

- `main`
- `agent/flutter-v8-native-beta`
- `agent/flutter-v8.2.0-dev14-feel`
- `agent/flutter-v8.3.0-webview-parity`

Protected remote hashes before publishing:

- `main`: `5a1a0d0f82a6b25415760bc7a77085a4e4fa3dd1`
- `agent/flutter-v8-native-beta`: `26e0f30f1a7b27ef75d1d5cbd8dab1d83ca3e8de`
- `agent/flutter-v8.2.0-dev14-feel`: `0b3e9fa42b872ac7b65509aa3d3ed67a9b3e2c59`
- `agent/flutter-v8.3.0-webview-parity`: `be2c074ebbb58d769f3116b19368dd34bb0f8157`

No Play Console upload, production-signing change, Pi deployment or merge to `main` is part of this owner-development handoff.

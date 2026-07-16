# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.9**
- Android package: `com.nisarg.wildcard`
- Android version code: **26** (local developer build: **27**)
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `64bbcfe2e2141260bf8ed948af12ad5db7f1e3cfe3d5b8e62555ee3244b642c3`
- Release APK SHA-256: `7ef00910252f6ba547651ec851c32a43b2be051da3a6fbd940d264f4b97b55a2`
- Release AAB SHA-256: `8f5445ec05ab561ca93471e0586eb7ceccb4d3909f15738d87a97ca5a7771246`
- Google Play internal track: v6.9.9 AAB built and signed locally; upload not performed from this branch

The v6.9.9 release repairs the scoring-feel regression: Normal/Fast pacing is restored to 1.0/0.55, terminal waits are no longer slowed twice, and redundant full renders, animated Heat-score rewrites, repeated mission saves, mobile blur layers and WebAudio graph buildup are removed from the scoring path. Win FX is fully retired from production code and the cosmetic catalogue. Joker triggers now use short, transform-only, in-card labels, while Sly retains hand-specific reactions and focused table dialogue.

The phone-first home screen now uses a brighter palace, a clear gold primary action, compact two-column Royal Vault controls and consistent icon tiles. All themes use lighter grading without changing table opacity. Eleven Base64 assets were externalized: canonical `www/index.html` fell from 4.23 MB to 0.48 MB while the generated work-laptop HTML remains genuinely standalone.

The v6.9.8 economy remains intact: paid Joker prices total 10,875 coins, Wooden/Golden Vaults cost 100/300, and rewarded recovery claims remain idempotent and save-safe.

The gameplay pass removes the expensive in-run Win FX path, keeps the approved scoring beat sequence, gives Sly hand-specific reactions and focused taunts, shows the active Heat modifier with its effect, and replaces the mid-run deck scroller with an at-a-glance 4-by-13 card matrix. The phone table, Joker area and card spacing were also rebalanced around the available viewport.

Standard UI themes now cost 1,000 coins. Premium illustrated Sly-room themes cost 3,500 or 5,000 coins. Existing purchases, local saves and cloud-save compatibility are retained.

Daily attempts are consumed and saved when play starts, Cosmetic Vault odds now describe the real theme gate, disabled Win FX can no longer drop from that vault, and THE HOUSE copy matches its 10% target increase.

Android MCP installation notes for Codex-assisted phone testing are in `docs/ANDROID-MCP.md`.

## Local setup

1. Install Node.js 22 or newer and the Android SDK.
2. Run `npm ci`.
3. Run `npm run sync:android` after every change to `www/`.
4. For a local signed release, place `wildcard-release.keystore` and `keystore-password.txt` in the repository root. These files are intentionally excluded from Git.
5. Run `npm run build:android:release`.

The APK is written to `android/app/build/outputs/apk/release/app-release.apk`.

## Verification

The release evidence is under `docs/release/`. The v6.9.9 light release gate completed 10,000 randomized scoring/Joker cases, 5,000 six-card Cheat comparisons and 550 complete runs with zero data, hook or run-invariant failures. Native rewarded callbacks, canonical source, standalone provenance and Google/Firebase configuration are checked independently. The earlier v6.9.8 full economy/depth audit remains available, and the work-machine handoff requests a new 50,000/15,000/2,600 stress pass. Firestore Rules previously passed 19 hostile allow/deny checks.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` and its external artwork/audio/fonts through the existing GoatCounter-aware deployer, and publishes the current APK as `WILDCARD-v6.9.9.apk`, `WILDCARD-v6.9.9-release.apk` and `WILDCARD-latest.apk`.

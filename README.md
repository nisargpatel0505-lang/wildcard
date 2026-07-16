# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.8**
- Android package: `com.nisarg.wildcard`
- Android version code: **22**
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `eb6d06b054fc0c9e41fa0dbc3a6b1296fcf089a6e59ffdb17425d96c7fc123a0`
- Release APK SHA-256: `e00e0d71a0e146294d9af9e906ae1fe0bd02b5b648f8ea9294a4e90abb294738`
- Release AAB SHA-256: `fb0c67379554368deffcf2077f1974f9e5f5aeb03dec5c880bd70e94c704257e`
- Google Play internal track: v6.9.8 AAB built locally; upload not performed from this branch

The v6.9.8 release rebalances long-term progression and adds two opt-in rewarded placements: one save-safe final play per run and a once-only run-coin double on eligible results. Paid Joker prices now total 10,875 coins, Wooden/Golden Vaults cost 100/300, and the daily-login curve is reduced by exactly 40%. Reward claims use an idempotency ledger so duplicated callbacks or replayed Heat checkpoints cannot pay twice.

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

The release evidence is under `docs/release/`. The v6.9.8 economy report is generated from the live catalogue and reward constants; 50,000 randomized scoring/Joker cases, 15,000 six-card Cheat comparisons and 2,600 complete runs passed with zero data, hook or run-invariant failures. Native rewarded callbacks, canonical source, standalone build and Google/Firebase configuration are checked independently. Firestore Rules previously passed 19 hostile allow/deny checks.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` and its external artwork/audio through the existing GoatCounter-aware deployer, and publishes the current APK as `WILDCARD-v6.9.8.apk`, `WILDCARD-v6.9.8-release.apk` and `WILDCARD-latest.apk`.

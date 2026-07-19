# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the web game in `www/`.

## Current release

- Game version: **6.9.14**
- Android package: `com.nisarg.wildcard`
- Android version code: **34** (local developer build: **33**)
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `b34c7cd44834a6468b058b0250c5d6810479f5e299b167a09e8cb5eabd46478b`
- Release APK SHA-256: `51e9f6257497145076bb47aeaf09bb1c2956df9161549e1bc1506e42bd63428d`
- Release AAB SHA-256: `2a846559c074b2fc2818a1d7afcfd693571108c7c7bb5511064c6ad123716693`
- Release signer certificate SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`
- Google Play internal track: **active** as `WILDCARD v6.9.14 internal test`
- Tester opt-in: <https://play.google.com/apps/internaltest/4699904654718813987>

v6.9.14 is a launch-hardening release. Its release scope covers authenticated Daily Board writes, safer account/cloud reconciliation, removal of public save importing and Friend Codes, trusted Play purchase delivery, first-launch privacy acceptance, account deletion, truthful vault odds, Daily-run isolation and recovery, deterministic luck recovery, mobile accessibility, broader theme coverage and focused gameplay correctness fixes. The release intentionally does not change the approved scoring pace or Joker trigger animation.

The v6.9.13 run-shop supply economy remains: each offered supply can be bought once in that shop, and each specific supply becomes two run coins more expensive every time it is used for the remainder of the run. Prices are independent by supply, survive save/resume, compose with temporary Inflation, and commit atomically so a double tap cannot apply an effect twice or create a free mutation.

The build also includes privacy-minimised Pi analytics for internal testing: app opens, run starts and run outcomes are queued only in memory and sent as a tiny non-blocking idle/background batch. The Pi keeps daily aggregate counters only; no player identity, exact score, cards, save data or persistent analytics identifier is sent. See [docs/ANALYTICS.md](docs/ANALYTICS.md).

The phone-first home screen now uses a brighter palace, a clear gold primary action, compact two-column Royal Vault controls and consistent icon tiles. All themes use lighter grading without changing table opacity. Eleven Base64 assets were externalized: canonical `www/index.html` fell from 4.23 MB to 0.48 MB while the generated work-laptop HTML remains genuinely standalone.

The paid-Joker economy remains intact. The Wooden Vault costs 60 coins until the player owns 15 Jokers, then returns to 100; the Golden Vault remains 300. Rewarded recovery claims remain idempotent and save-safe.

The gameplay pass removes the expensive in-run Win FX path, keeps the approved scoring beat sequence, gives Sly hand-specific reactions and focused taunts, shows the active Heat modifier with its effect, and replaces the mid-run deck scroller with an at-a-glance 4-by-13 card matrix. The phone table, Joker area and card spacing were also rebalanced around the available viewport.

Standard UI themes now cost 1,000 coins. Premium illustrated Sly-room themes cost 3,500 or 5,000 coins. Existing purchases, local saves and cloud-save compatibility are retained.

Daily runs are resumable, deterministic and isolated from normal progression. Vault odds are derived from the same remaining-pool calculation used for reward selection.

Android MCP installation notes for Codex-assisted phone testing are in `docs/ANDROID-MCP.md`.

## Local setup

1. Install Node.js 22 or newer and the Android SDK.
2. Run `npm ci`.
3. Run `npm run sync:android` after every change to `www/`.
4. For a local signed release, place `wildcard-release.keystore` and `keystore-password.txt` in the repository root. These files are intentionally excluded from Git.
5. Run `npm run build:android:release`.

The APK and AAB are written to `android/app/build/outputs/apk/release/app-release.apk` and `android/app/build/outputs/bundle/release/app-release.aab`.

## Verification

Release evidence is under `docs/release/`. The final v6.9.14 source passed the complete project suite plus a focused 10,000 scoring / 5,000 Cheat / 550-run deterministic regression with zero failures or mismatches. Firebase Functions tests passed 11/11 and Firestore Rules emulator tests passed 29/29. The larger v6.9.10 balance, strategy and economy evidence remains the latest full balance baseline.

## Firebase

The Android package and release certificates are registered with Firebase App Check using Play Integrity. Firebase App Check and Play Integrity APIs are enabled, Play Console is linked to Cloud project `420107184674`, and Cloud Firestore App Check enforcement is active. Google Authentication and the London-region Firestore database remain active; direct client save access is denied and cloud operations use App-Check-protected callable Functions. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/`, the privacy page and its external artwork/audio/fonts/video through the existing GoatCounter-aware deployer, installs the source-controlled Daily Board/aggregate analytics API, and publishes the current APK as `WILDCARD-v6.9.14.apk`, `WILDCARD-v6.9.14-release.apk` and `WILDCARD-latest.apk`.

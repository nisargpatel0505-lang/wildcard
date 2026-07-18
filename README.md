# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.12**
- Android package: `com.nisarg.wildcard`
- Android version code: **32** (local developer build: **31**)
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `6585cb1976fe44bfbaf49a4aca310d512fbca008392dfc83ff89077f7256f75c`
- Release APK SHA-256: `7eb6c488441e005c4121d356c76944654f72ad85edb69d2d96ad63c40bcdd5d2`
- Release AAB SHA-256: `0bd24f97628514680726942acd7c5f1370b303a1ecbe1aa2bd3f016e578bc581`
- Google Play internal track: v6.9.12 AAB is built and signed locally after the release checks; Play Console upload remains a separate explicit step

The v6.9.12 release replaces the hard Joker flash/lift and moving `TRIGGER` chip with a short, stationary rarity glow and effect-only text. Standard modifiers remain at Heats 3, 6 and 9 with THE HOUSE at 12; Endless now deals a modifier only every third Heat. Clearing Heat 12 plays a 2.4-second full-screen Sly single-tear cinematic, attempts one fail-safe interstitial, then presents `Continue → Endless` or `End Run · Bank Score`. The victory checkpoint is saved before media or ads, resume never repeats the cinematic/ad, and Daily/Gauntlet settlement remains isolated.

The build also includes privacy-minimised Pi analytics for internal testing: app opens, run starts and run outcomes are queued only in memory and sent as a tiny non-blocking idle/background batch. The Pi keeps daily aggregate counters only; no player identity, exact score, cards, save data or persistent analytics identifier is sent. See [docs/ANALYTICS.md](docs/ANALYTICS.md).

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

The release evidence is under `docs/release/`. v6.9.12 uses a focused 10,000 scoring / 5,000 Cheat / 550-run regression because its primary changes are presentation and orchestration; the larger v6.9.10 balance, strategy and economy evidence remains the latest full balance baseline. Executable tests cover Heat-12 video/ad/choice failure paths, one-interstitial enforcement, Daily and resume routing, native rewarded/interstitial and Billing callbacks, offline MP4 Range responses, economy idempotency, Pi analytics privacy, canonical source, standalone provenance, Android packaging, and Google/Firebase configuration. Firestore Rules previously passed 19 hostile allow/deny checks.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/`, the privacy page and its external artwork/audio/fonts/video through the existing GoatCounter-aware deployer, installs the source-controlled Daily Board/aggregate analytics API, and publishes the current APK as `WILDCARD-v6.9.12.apk`, `WILDCARD-v6.9.12-release.apk` and `WILDCARD-latest.apk`.

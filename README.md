# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.7**
- Android package: `com.nisarg.wildcard`
- Android version code: **20**
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `d1dbe27e7ccb12f7653c73952be0195d5507b12e0665470f0947e05d04c04c04`
- Release APK SHA-256: `bee5d4c0c79e0071f8351a366c615473158400c091bee5ff7dd4a8c873e2ce1c`
- Release AAB SHA-256: `2dc2566793a9850b4da79dc7fdd6af907dfffa38f6b1dd2e2f518d6a9b1b9d18`
- Google Play internal track: release draft prepared; manual AAB file selection remains

The v6.9.7 release reorganizes the phone home screen around New Run, Shop, Cabinet, Weekly Missions, Settings and More, while using the available height more evenly. Shop now contains the Coin Store and Wardrobe, and the New Run picker contains Normal, Gauntlet and the once-per-day Daily Challenge. Settings includes a safe tutorial replay; developer grant tools are excluded from production builds.

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

The release evidence is under `docs/release/`. The current v6.9.7 audit completed 10,000 randomized scoring/Joker cases, 5,000 six-card Cheat comparisons and 550 complete bot runs with zero scoring/data, hook or run-invariant failures. The canonical source, standalone build and Google/Firebase configuration audit also pass. Firestore Rules previously passed 19 hostile allow/deny checks.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` and its external artwork/audio through the existing GoatCounter-aware deployer, and publishes the current APK as `WILDCARD-v6.9.7.apk`, `WILDCARD-v6.9.7-release.apk` and `WILDCARD-latest.apk`.

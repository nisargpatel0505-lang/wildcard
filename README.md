# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.5**
- Android package: `com.nisarg.wildcard`
- Android version code: **16**
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `9773C98FA6F4EF2D4FD673AFFF6B38E51411F401EBB28F87376E4D62CBC88F71`
- Release APK SHA-256: `00CF94AE0FAC171F2F8A7E7F177F116C48BB1AC141DE62FC0D2A6F4725B5EE9F`
- Release AAB SHA-256: `DB8DED0D33323063241E194896EE04EB67B59AEED103073138105734971B781E`

The v6.9.5 release makes the equipped Win FX visible after every scored hand, with light, standard and hero tiers that preserve the approved normal-mode scoring rhythm. It retains v6.9.4's in-game Google Play Games leaderboard bridge and the v6.9.3 visual release.

Android MCP installation notes for Codex-assisted phone testing are in `docs/ANDROID-MCP.md`.

## Local setup

1. Install Node.js 22 or newer and the Android SDK.
2. Run `npm ci`.
3. Run `npm run sync:android` after every change to `www/`.
4. For a local signed release, place `wildcard-release.keystore` and `keystore-password.txt` in the repository root. These files are intentionally excluded from Git.
5. Run `npm run build:android:release`.

The APK is written to `android/app/build/outputs/apk/release/app-release.apk`.

## Verification

The release evidence is under `docs/release/`. v6.9.5 retains the deterministic v6.9.1 balance baseline (50,000 scoring cases, 15,000 Cheat checks and 2,600 complete runs with zero failures) and adds focused source, standalone and physical-phone checks. Firestore Rules previously passed 19 hostile allow/deny checks.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` and its external artwork/audio through the existing GoatCounter-aware deployer, and publishes the current APK as both `WILDCARD-v6.9.5.apk` and `WILDCARD-latest.apk`.

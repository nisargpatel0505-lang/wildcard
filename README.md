# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.1**
- Android package: `com.nisarg.wildcard`
- Android version code: **14**
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `CC7A95E2D271A92CF51BF7D2DA094E72A49057101B9A609E6148C84D4B63F5C0`
- Release APK SHA-256: `7A343554B1AE387994CFA4CBD172430AFA2F6E64E5E58BF1B2F3D2932479862A`
- Release AAB SHA-256: `650FDE650D6E93BF44651D8C877EBE97DC9E7D0A1844CB6B2497FAC667FB0C86`

The v6.9.1 recovery release preserves the phone-tested mobile/vault fixes, adds true Android immersive mode, improves card touch spacing and safe-area layout, keeps optional no-reset Firestore backup, adds an in-game Play Games daily/weekly/all-time board with actionable diagnostics, and integrates five optimized room backgrounds recovered from the work-laptop handoff.

Android MCP installation notes for Codex-assisted phone testing are in `docs/ANDROID-MCP.md`.

## Local setup

1. Install Node.js 22 or newer and the Android SDK.
2. Run `npm ci`.
3. Run `npm run sync:android` after every change to `www/`.
4. For a local signed release, place `wildcard-release.keystore` and `keystore-password.txt` in the repository root. These files are intentionally excluded from Git.
5. Run `npm run build:android:release`.

The APK is written to `android/app/build/outputs/apk/release/app-release.apk`.

## Verification

The release evidence is under `docs/release/`. The deterministic v6.9.1 suite covers 50,000 scoring cases, 15,000 Cheat checks, and 2,600 complete runs with zero failures. Firestore Rules passed 19 hostile allow/deny checks. The 375px phone-layout audit is under `docs/qa/`.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` through the existing GoatCounter-aware deployer, installs the external WebP room artwork, and publishes the current APK as both `WILDCARD-v6.9.1.apk` and `WILDCARD-latest.apk`.

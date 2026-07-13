# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9**
- Android package: `com.nisarg.wildcard`
- Android version code: **13**
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `F822E3568FD682A6FF716917C5DE33004580194CE253AEA390165BA56DE3870E`
- Release APK SHA-256: `A7BF82962014E40D24DB9EAC5579A4A80081F566AEFB9950AF1F0B5D934FA35C`
- Release AAB SHA-256: `B91687E38475CFA5EABBF7F422077F76B6C3DDA2AA648DDCC970B4A38EE7A3E5`

The v6.9 release adds optional Google sign-in, no-reset Firestore cloud backup and official Play Games daily/weekly/all-time rankings while retaining guest play, offline phone saves, the custom Daily Board and all v6.8 mobile/vault fixes.

Android MCP installation notes for Codex-assisted phone testing are in `docs/ANDROID-MCP.md`.

## Local setup

1. Install Node.js 22 or newer and the Android SDK.
2. Run `npm ci`.
3. Run `npm run sync:android` after every change to `www/`.
4. For a local signed release, place `wildcard-release.keystore` and `keystore-password.txt` in the repository root. These files are intentionally excluded from Git.
5. Run `npm run build:android:release`.

The APK is written to `android/app/build/outputs/apk/release/app-release.apk`.

## Verification

The release evidence is under `docs/release/`. The deterministic v6.9 suite covers 10,000 scoring cases, 5,000 Cheat checks, and 550 complete runs with zero failures. Firestore Rules passed 19 hostile allow/deny checks. The 375px phone-layout audit is under `docs/qa/`.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` through the existing GoatCounter-aware deployer, and publishes the current APK as both `WILDCARD-v6.9.apk` and `WILDCARD-latest.apk`.

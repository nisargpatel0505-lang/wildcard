# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.8**
- Android package: `com.nisarg.wildcard`
- Android version code: **11**
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `F1A3D3FD1ADFC66128F61F42402BDF0E0F5787437C573C9C720F30141EA520BD`
- Release APK SHA-256: `857B73FE6B29678776F2C87D57C4354477A5193BA74A2665CE24D88EBC8F96AF`

The v6.8 release includes Weekly Mission rewarded-ad refresh, the full Royal Vault reveal, the contained mobile Sly header, and corrected phone-width vault framing.

Android MCP installation notes for Codex-assisted phone testing are in `docs/ANDROID-MCP.md`.

## Local setup

1. Install Node.js 22 or newer and the Android SDK.
2. Run `npm ci`.
3. Run `npm run sync:android` after every change to `www/`.
4. For a local signed release, place `wildcard-release.keystore` and `keystore-password.txt` in the repository root. These files are intentionally excluded from Git.
5. Run `npm run build:android:release`.

The APK is written to `android/app/build/outputs/apk/release/app-release.apk`.

## Verification

The release evidence is under `docs/release/`. The deterministic v6.8 suite covers 10,000 scoring cases, 5,000 Cheat checks, and 550 complete runs with zero failures. The 375px phone-layout audit is under `docs/qa/`.

## Firebase

The Android package and release SHA-256 certificate are registered with Firebase. `android/app/google-services.json` contains Firebase project identifiers and is safe to keep with the app source. No billable Firebase product or AI endpoint is enabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/` through the existing GoatCounter-aware deployer, and publishes the current APK as both `WILDCARD-v6.8.apk` and `WILDCARD-latest.apk`.

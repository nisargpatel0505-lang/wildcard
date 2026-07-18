# WILDCARD

WILDCARD is a mobile-first arcade roguelike poker game. The Android app is a Capacitor wrapper around the self-contained game in `www/index.html`.

## Current release

- Game version: **6.9.11**
- Android package: `com.nisarg.wildcard`
- Android version code: **29** (local developer build: **28**)
- Firebase project: `wildcard-31d50`
- Source HTML SHA-256: `116d1878b733667b2fdb87c28e9ed38b5f8010288894e11bbebe9cf9a4c81521`
- Release APK SHA-256: `e02eb3b5e6e360c8571e121a8376353221a4f15039a46c21656cbf77b6e40782`
- Release AAB SHA-256: `2917dc42f60b9cdd947300f6a204151aad0dbabefb95c7be208b2d83f9d986e8`
- Google Play internal track: v6.9.11 AAB is built and signed locally after the release checks; Play Console upload remains a separate explicit step

The v6.9.11 release makes scoring readable without restoring expensive Win FX: the previous Normal timing is now Fast, while Normal uses a 1.85 pacing multiplier and longer labelled Joker holds. Five Jokers fit in a centred 3+2 phone grid, card hit-testing uses untransformed centres so adjacent selections are reliable, and the hidden tap-to-fast-forward shortcut is removed. Vault/Wardrobe rewarded-coin shortcuts, claim-button containment, notification badges, Daily full-catalogue shops, a protected-first-Heat 25% Glass Joystick, themed marquee lights and a still premium collection/settings room complete the mobile pass.

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

The release evidence is under `docs/release/`. v6.9.11 uses a focused 10,000 scoring / 5,000 Cheat / 550-run regression because its primary changes are UI, timing and bridge safety; the larger v6.9.10 balance, strategy and economy evidence remains the latest full balance baseline. Native rewarded and Billing callbacks, canonical source, standalone provenance, Android Daily Board routing and Google/Firebase configuration are checked independently. Firestore Rules previously passed 19 hostile allow/deny checks.

## Firebase

The Android package and release SHA-1/SHA-256 certificates are registered with Firebase. Google Authentication and a London-region Firestore database are active; deployed Rules restrict the fixed cloud-save document to its authenticated owner. Firebase AI Logic remains disabled. See `docs/FIREBASE.md`.

## Raspberry Pi deployment

The Pi keeps a private read-only clone and runs `deploy/update-pi.sh`. That script pulls `main`, deploys `www/`, the privacy page and its external artwork/audio/fonts through the existing GoatCounter-aware deployer, installs the source-controlled Daily Board/aggregate analytics API, and publishes the current APK as `WILDCARD-v6.9.11.apk`, `WILDCARD-v6.9.11-release.apk` and `WILDCARD-latest.apk`.

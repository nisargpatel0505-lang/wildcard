# WILDCARD v8.3.0 Flutter release-candidate evidence

Date: 25 July 2026

Branch: `agent/flutter-v8.3.0-webview-parity`

Package: `com.nisarg.wildcard`

Version: `8.3.0` (`versionCode 61`)

## Scope

This isolated Flutter release-candidate branch brings the native presentation
closer to the protected WebView reference without changing poker evaluation,
authoritative scoring mathematics, Joker effects, economy, rewards, RNG
streams, save schema, cloud behaviour, billing verification, ads behaviour or
backend rules.

The completed presentation work includes:

- readable phone typography, card faces and suit alignment;
- a lower, more compact playfield with more room for Jokers;
- overlapping cards with a broad exposed tap strip and a clear selected lift;
- retained per-card and per-Joker scoring chips;
- visible Sly reaction faces, reaction badges and stale-timer protection;
- a rebuilt Royal Vault ceremony with a real hinge, lock, cavity light,
  no-spoiler scan, large reward reveal and unobscured Claim action;
- first-run coaching and first-loss comeback Vault presentation;
- phone-safe overlays, controls and theme treatment;
- profile-build owner tools with ad bypass kept separate from the public
  release behaviour.

## Sly reaction repair

The reaction state machine was working, but every non-classic Sly cosmetic used
one static frame from `sly-skins-grid.webp`. On the owner's save, Devil Sly
therefore kept the same face even when the game requested shocked, laughing,
thoughtful or triumphant.

During an active reaction, premium cosmetics now crossfade to the correct frame
from the existing 3 x 3 expression atlas. When the reaction settles, the
equipped cosmetic returns. The mapping is explicit, so later enum changes
cannot silently shift atlas frames.

Verified outcomes include:

- major hand: shocked;
- Heat clear: triumphant;
- failed final play: laughing;
- reduced motion: face changes without motion;
- reaction settle: equipped premium portrait returns.

No score value or scoring delay was changed by this repair.

## Automated verification

`flutter analyze --no-pub`

- Result: no issues found.

Focused Sly, playfield and Royal Vault suite:

- 23 tests passed.
- Includes real asset/frame assertions for premium Sly reactions.
- Includes 320 x 568 through 800 x 1280 Vault coverage.
- Includes selected-card adjacency and touch-strip coverage.

Full `flutter test --no-pub`:

- 200 tests passed.
- 2,000 deterministic complete runs passed.
- Random-strategy simulation: 1,000 runs, 0 invariant failures.
- Ranked-strategy simulation: 1,000 runs, 0 invariant failures.
- Save, migration, RNG, scoring, economy, progression, tutorial, accessibility
  and phone-surface checks passed.

## Owner profile APK

File: `releases/WILDCARD-v8.3.0-owner-profile.apk`

- Size: 122,732,098 bytes
- SHA-256:
  `7F1D213C322D5B9790745FD2A67B4878B933A378FD455E251EF797F7528089C1`
- Purpose: owner performance testing with developer tools and in-memory ad
  bypass; it does not grant the paid no-ads entitlement.
- Installation must use `adb install -r -t` so the existing app data remains.

Physical-device installation passed on 26 July 2026 using
`adb install -r -t`. Package inspection confirmed version `8.3.0` / code `61`;
the original 13 July first-install timestamp remained intact. The launched
home screen retained Best Heat 21 and 5,466 coins, confirming the existing save
survived the in-place update.

## Public release AAB

File: `releases/WILDCARD-v8.3.0.aab`

- Size: 74,498,722 bytes
- SHA-256:
  `D6811C53EF30361E207D918157E4399B28CA73B31C40D59EC8F8B3761029CE6E`
- JAR signature verification: passed.
- Upload certificate SHA-256:
  `C3:C2:81:D1:47:0A:EB:F2:D9:96:56:22:1A:DA:78:15:C6:B8:73:F4:E8:A7:48:D7:28:4F:5F:AE:5D:76:47:17`
- Certificate owner:
  `CN=Nisarg Patel, OU=WILDCARD, O=WILDCARD, C=GB`
- Minimum SDK: 24
- Target SDK: 36

Merged release-manifest checks:

- package `com.nisarg.wildcard`;
- version `8.3.0` / code `61`;
- production AdMob app ID
  `ca-app-pub-3855192091371080~7622357185`;
- no `MobileAdsInitProvider`;
- no `PlayGamesInitProvider`.

The AAB was built without the demo-ad flags. It is a public release candidate,
not proof of an uploaded or approved Google Play release.

## Physical-device target

Device used during presentation validation:

- Xiaomi `24095PCADG` / POCO X7-class device
- Android 16 / API 36
- ADB serial `6TLZJV89Q4TCHYMN`

Device evidence on this branch confirms the lowered table, enlarged Joker
area, lifted selected card, readable nine-card fan, immersive navigation,
rebuilt Vault layout and successful launch of the Sly-reaction build.

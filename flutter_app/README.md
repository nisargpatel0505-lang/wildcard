# WILDCARD native Flutter client

This directory contains the native Flutter port of WILDCARD. Gameplay, scoring,
run state, shops, progression and screens are implemented in Dart/Flutter. It
does not load the old HTML game in a WebView.

## Current development build

- Version: `8.0.0-dev.1` (`versionCode 46`)
- Android package: `com.nisarg.wildcard`
- Minimum Android API: 24
- Phone target: portrait-first, tested down to 320 x 568 logical pixels
- Save upgrade: reads the existing Capacitor phone save once, copies it into
  Flutter storage and retains the old values for rollback

The debug APK is signed with the existing WILDCARD release key so it can update
the installed v7.1.0 phone build without uninstalling or resetting progress.
Debug builds use Google's demonstration AdMob units. Release builds use the
owned production units configured in `AppConstants` and the Android manifest.

## Architecture

- `lib/domain/` - cards, scoring, all 57 public Jokers, modes, economy,
  progression catalogues, deterministic RNG and simulations
- `lib/game/` - resumable run state machine, shops, supplies, scoring event
  presentation and terminal account mutations
- `lib/ui/` - phone-first reusable screens and widgets
- `lib/app/` - navigation, account orchestration, mode launch, settings,
  collection, Royal Vault, Cabinet and the live game host
- `lib/services/` - local saves, Firebase/Auth/App Check, AdMob/UMP, verified
  Play Billing, Play Games, Pi Daily Board/aggregate analytics and audio
- `test/` - scoring goldens, save/RNG parity, controller tests, simulations,
  backend-facing state tests and small-phone rendering checks

The old `www/` client remains outside this directory only as the released
reference and migration source while the Flutter beta is validated.

## Safety rules carried into Flutter

- Local/offline play remains available without an account.
- The first-launch privacy gate runs before consent-gated services.
- Cloud progress is linked to one Firebase UID; saves from different accounts
  are not silently unioned.
- Paid purchases are verified by Firebase and recorded durably before Play
  consumes or acknowledges them.
- Daily mode is deterministic, resumable and isolated from normal Best Heat.
- Random outcomes checkpoint their RNG state so force-closing cannot reroll a
  scored hand.
- Vault rewards persist before the reveal animation.
- Debug developer grants cannot write cloud saves or leaderboard scores and are
  compiled out of release builds.

## Verification

From this directory:

```powershell
$env:ANDROID_HOME = 'C:\Android\sdk'
$env:ANDROID_SDK_ROOT = 'C:\Android\sdk'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

C:\Users\nisar\development\flutter\bin\flutter.bat analyze
C:\Users\nisar\development\flutter\bin\flutter.bat test
C:\Users\nisar\development\flutter\bin\flutter.bat build apk --debug
```

The full test command includes deterministic complete-run simulations. Firebase
purchase and Daily Board backend tests live in the repository-level
`functions/test/` directory and run with `npm test` from `functions/`.

## Device validation

Install upgrades in place; do not uninstall the released app because local
guest progress may not exist in cloud storage:

```powershell
C:\Android\sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk
```

After the first Flutter launch, verify coins, Best Heat, equipped title,
unlocks and any active run before doing destructive test actions. The migration
does not delete the old Capacitor preferences.

## Release notes

The Flutter build is a development beta until physical-device validation has
covered save migration, a complete run, Royal Vault, rewarded/interstitial demo
ads, Firebase sign-in/cloud recovery, Play Games and an Internal Testing billing
install. Sideloaded APKs cannot prove Play product availability; billing must be
validated from Google Play's Internal Testing track.

# WILDCARD v8.3.0-dev.1 build evidence

Branch: `agent/flutter-v8.3.0-webview-parity`

Baseline: `0b3e9fa42b872ac7b65509aa3d3ed67a9b3e2c59`

Package: `com.nisarg.wildcard`

Version: `8.3.0-dev.1` (`versionCode 60`)

## Scope

This branch restores the WebView presentation rhythm and hierarchy in native
Flutter without changing poker evaluation, scoring results, Joker effects,
economy, RNG, save schema or online-service behaviour.

Key presentation changes:

- A dedicated timestamped scoring timeline now drives cards, Jokers, equation,
  audio, haptics, Sly, callouts and the final score without broad per-beat
  controller rebuilds.
- The running equation uses the authoritative formula at every step:
  `base + round(raw rank × 0.6)`, followed by
  `round(value points × multiplier)`.
- Playing cards remain fixed during selection and scoring. Gold card chips,
  violet Joker contributions, retriggers, Lucky Seven outcomes, multiplier
  labels and the large final score remain readable and sequence-keyed.
- Sly reactions now carry priority, mood, expression, speech, motion and hold
  duration.
- The Royal Vault now has a physically continuous charge, scan, latch, hinged
  lid, internal light, reward emergence, rarity impact and calm claim state.
- Background atmosphere reacts cheaply to progress, modifiers and THE HOUSE.
- Painted WILDCARD coin components replace platform emoji in the updated shop
  and Vault surfaces.
- Responsive metrics cover very-short through tablet layouts, and effects
  profiles bound particles, glow and ambient motion.
- Boot progress is tied to real local startup milestones.
- Gradle is bounded to a 4 GB heap and two workers so release builds complete
  reliably on the 8 GB development laptop.

## Automated verification

- `flutter analyze`: no issues.
- Complete test suite: 167 tests passed.
- Presentation-specific rerun: 7 tests passed.
- Deterministic simulation coverage includes 2,000 complete runs plus
  Gauntlet, supplies and explicit Endless stress.
- Surface tests cover 320×568, 360×640, 360×800, 393×873, 412×915,
  480×960, 600×960 and 800×1280.
- Royal Vault tests include required screen classes, 1.3 text scale and
  reduced motion.
- `git diff --check`: clean.

## Physical-device verification

Device: POCO X7 (`24095PCADG`), Android 16 / API 36, 120 Hz.

- Existing v8.2 app data was archived before installation.
- Profile APK signature matched the installed certificate:
  `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.
- `adb install -r -t` upgraded the app in place; first-install time and save
  files were retained.
- Installed version reports `8.3.0-dev.1` / code `60`.
- Best Heat 21 and 5,264 account coins were visible after upgrade.
- A Pair and a second scoring play completed correctly on device.
- During the sampled score, SurfaceFlinger reported a 120 Hz surface with
  125 continuous frame intervals: median 9.03 ms, p95 9.39 ms,
  p99 9.95 ms, maximum 10.37 ms, and zero intervals over 16.7 ms.

## Signed artifacts

### Release APK

- File: `build/app/outputs/flutter-apk/app-release.apk`
- Size: 72,090,336 bytes
- SHA-256:
  `AA9195E78ED9953F0E7A8103A1C36614C6B85C0C4A143148AD21D4604E74C71E`

### Play App Bundle

- File: `build/app/outputs/bundle/release/app-release.aab`
- Size: 74,328,843 bytes
- SHA-256:
  `55D8C59D4F605B2535CB0225D5A4A3AC4B520528516CDAD792E3E9630BB3C3B0`

Both artifacts use the established release certificate. The profile build
installed on the phone retains the test-ad configuration intended for device
testing; the release artifacts retain the existing production configuration.

## Known non-blocking build warning

Flutter reports that `cloud_functions` and `firebase_app_check` still apply
the Kotlin Gradle Plugin directly. They build successfully today, but those
plugins should be upgraded when compatible releases adopt Flutter's built-in
Kotlin path.

# WILDCARD v8.5.3 Play startup hotfix

## Release identity

- Package: `com.nisarg.wildcard`
- Version: `8.5.3` (`versionCode 72`)
- Source branch: `agent/flutter-v8.5.3-play-startup-hotfix`
- Pre-Level source base: `39f038295879a332eb83ba76554512edf63d2389`
- Level Mode is not present. The first Level Mode commit (`82dabcd`) is not an ancestor of this build.

## Root cause

The Play-delivered minified build could terminate before Flutter rendered its
first frame. AGP 9/R8 full mode removed the reflective no-argument constructor
from WorkManager's generated Room database implementation,
`androidx.work.impl.WorkDatabase_Impl`. AndroidX Startup initializes
WorkManager before `runApp`, so the failure looked like an app that simply did
not open.

Profile and owner APKs did not expose this fault because they were not using
the same minified Play release path.

## Fix

The release build now loads `android/app/proguard-rules.pro`, which preserves
constructors on generated `RoomDatabase` implementations. A regression test
also guards both the Gradle wiring and the keep rule.

Gradle is capped at one worker and a 2 GB heap for this 8 GB development laptop
to prevent release builds from exhausting system RAM.

## Artifact evidence

- AAB: `WILDCARD-v8.5.3-code72-play-hotfix.aab`
- Size: `89,252,325` bytes
- SHA-256: `B9CB1C0CAD7AF2593AFAC41D9AC279160BF52D7F625285590508D171BC4A7983`
- Google bundletool `1.18.3` validation: passed
- R8 seed evidence: `androidx.work.impl.WorkDatabase_Impl: WorkDatabase_Impl()` is present
- Manifest evidence: package `com.nisarg.wildcard`, version `8.5.3`, code `72`

## Physical-device evidence

The device-specific split APKs were generated from the exact AAB with Google
bundletool and installed in place over the existing app. No uninstall or data
clear was used.

- Existing progress loaded: 4,400 coins and Best Heat 21
- Cold starts: 10/10 successful
- Fatal Android/WorkManager matches: 0
- Installed version confirmed: `8.5.3` (`versionCode 72`)

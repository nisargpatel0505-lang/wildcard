# Firebase connection

The Android app `com.nisarg.wildcard` is registered in Firebase project `wildcard-31d50` as app ID `1:420107184674:android:d1249c53cbde7160c2387b`.

The release signing certificate SHA-256 registered with Firebase is:

`C3:C2:81:D1:47:0A:EB:F2:D9:96:56:22:1A:DA:78:15:C6:B8:73:F4:E8:A7:48:D7:28:4F:5F:AE:5D:76:47:17`

The matching SHA-1 used by Google sign-in and Play Games is:

`E0:5C:17:94:91:AC:EE:68:9A:A1:E0:3A:63:D9:79:DE:D9:5B:05:C0`

`android/app/google-services.json` is installed and the Google Services Gradle task runs during release builds. Firebase describes this file as project/app identifiers rather than an authorization secret.

## v6.9 services

- Firebase Authentication: Google provider enabled; sign-in remains optional.
- Cloud Firestore: Standard edition `(default)` database in `europe-west2` (London), deletion protection enabled.
- Cloud save path: `users/{auth.uid}/saves/main`.
- Security Rules: owner-only fixed-document reads/writes, strict field allowlist/types/sizes, server timestamp, no deletes, recursive default deny.
- App Check: the Android SDK uses Play Integrity. Enforcement should be enabled only after the Play-distributed internal test build has been verified; a Pi-sideloaded build may not receive a valid Play Integrity verdict.
- Google Play Games project/application ID: `420107184674`.
- Official high-score leaderboard ID: `CgkIotTbgp0MEAIQAQ`.

The Firestore emulator attack suite is `npm run test:rules`. It covers unauthenticated and cross-user access, UID spoofing/mutation, unexpected and missing fields, type errors, oversized saves, bad timestamps, enumeration and deletion.

Firebase AI Logic is deliberately not enabled yet. Before adding any Gemini-powered game feature, complete these controls:

1. Define the exact player-facing feature and its data flow.
2. Configure App Check with Play Integrity for the Android distribution model.
3. Restrict the Firebase API key to only the APIs and Android app that need it.
4. Require authenticated users for AI calls.
5. Configure quotas, spend alerts, monitoring, and Remote Config for model selection.
6. Review prompts, safety behavior, privacy disclosure, and failure fallbacks.

Firebase AI Logic, SQL/Data Connect, Firebase Analytics, Crashlytics and Hosting remain disabled. WILDCARD's separate privacy-minimised Pi counters are documented in `docs/ANALYTICS.md`; they do not use a Firebase SDK. The project is on Blaze because Firestore was provisioned; use budget alerts and console monitoring before broad distribution.

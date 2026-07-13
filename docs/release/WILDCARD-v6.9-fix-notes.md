# WILDCARD v6.9 — Optional Google Cloud Save and Official Rankings

v6.9 keeps guest/offline play and the existing Android phone save, then adds an optional account layer without resetting established progress.

## Accounts and cloud backup

- Added optional **Sign in with Google** in Settings.
- Existing coins, unlocks, cosmetics, purchases, achievements, best scores and current run are linked on first sign-in.
- First-link reconciliation keeps phone choices and safely unions earned progress; repeat syncs choose the newer complete checkpoint.
- The existing WebView and Android Preferences copies remain active, so guest and offline play still work.
- Firestore saves at safe account/run checkpoints and queues synchronization when connectivity returns.
- A failed or uncertain cloud read is never followed by a blind overwrite.
- Signing out keeps the current phone save.
- The privacy screen now explains optional account, Firestore and Play Games processing.

## Firestore protection

- The only client path is `users/{uid}/saves/main`.
- Authenticated owners can read/create/update their own fixed save document only.
- Deletes, collection enumeration, other paths, extra fields, bad types, spoofed UIDs, client-authored server timestamps and oversized payloads are denied.
- App Check uses the Android Play Integrity provider. Enforcement remains off until the Play-distributed internal build is verified so Pi sideloads cannot strand guest play.
- Nineteen hostile emulator checks passed before the rules were deployed.

## Google Play Games

- Created the WILDCARD Play Console app and linked Play Games Services to Firebase project `wildcard-31d50`.
- Added the tamper-protected **WILDCARD High Score** leaderboard.
- One official leaderboard provides daily, weekly and all-time views in the Google Play Games UI.
- Scores submit only through the native signed-in Play Games client.
- The custom WILDCARD Daily Board and its existing in-game design remain unchanged.

## Android release

- Package: `com.nisarg.wildcard`
- Version name: `6.9`
- Version code: `13`
- Firebase App ID: `1:420107184674:android:d1249c53cbde7160c2387b`
- Play Games application ID: `420107184674`
- Leaderboard ID: `CgkIotTbgp0MEAIQAQ`

## Verification

- Android release APK and AAB compiled successfully.
- Inline JavaScript compiled; 140 HTML IDs are unique.
- No-reset merge regression passed.
- Firestore Rules: 19 allow/deny attack tests, zero failures; rules compiled and deployed.
- Gameplay simulation: 10,000 scoring cases, 5,000 Cheat checks, 550 complete runs, zero data/hook/invariant failures.
- Physical phone upgrade from v6.8 to v6.9 preserved 5,035 coins, best score 1,500, Heat 6 and 13 unlocks.

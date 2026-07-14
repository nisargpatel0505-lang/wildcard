# WILDCARD v6.9.1 — Recovery, Mobile Polish and Play Games Diagnostics

v6.9.1 is the authoritative recovery release built from the home laptop's phone-tested source. It selectively incorporates useful diagnostics, optimized artwork and standalone-playtest tooling from the work-laptop draft PR without replacing the newer game with its older v6.9 copy.

## Phone and game presentation

- Uses true Android immersive mode; system navigation/status bars stay hidden and can be revealed temporarily with a swipe.
- Keeps Sly and his dialogue inside the phone layout.
- Keeps both rank/suit markings inside every card and slightly increases adjacent-card touch separation.
- Corrects bottom safe-area placement for the movie/ad button.
- Keeps the Royal Vault stage centered inside its containing panel.
- Adds five optimized WebP rooms for the menu, The House, Sly's shop, Royal Vault and Endless victory screens.

## Accounts, saves and official rankings

- Guest and offline play remain available.
- Explicit Sign in with Google links an existing phone save to Firestore without resetting established progress.
- Save reconciliation retains coins, unlocks, cosmetics, purchases, achievements, best scores and the current run.
- Play Games daily, weekly and all-time scores can render inside WILDCARD, with the native Google Play leaderboard retained as a fallback.
- Native and web layers now return safe `PGS_*` diagnostic codes with actionable messages for signature, tester, consent, network and Play-services failures.
- Both the direct/upload and Google Play app-signing SHA-1 Android OAuth clients are present in `google-services.json`.

## Portable work-laptop playtest

- `playtest/WILDCARD-work-laptop-standalone.html` is generated from the canonical `www/index.html`.
- It embeds the five room backgrounds and application icon so it opens directly in Chrome or Edge without an install.
- The generated file carries the canonical HTML SHA-256 and verification rejects stale or externally dependent copies.

## Android release

- Package: `com.nisarg.wildcard`
- Version name: `6.9.1`
- Version code: `14`
- Source HTML SHA-256: `CC7A95E2D271A92CF51BF7D2DA094E72A49057101B9A609E6148C84D4B63F5C0`
- APK SHA-256: `7A343554B1AE387994CFA4CBD172430AFA2F6E64E5E58BF1B2F3D2932479862A`
- AAB SHA-256: `650FDE650D6E93BF44651D8C877EBE97DC9E7D0A1844CB6B2497FAC667FB0C86`

## Verification

- Inline JavaScript compilation and unique-ID checks pass.
- Android signed release APK and AAB compile successfully.
- Google/Firebase package, project, leaderboard and both signing-SHA mappings pass the repository audit.
- Firestore Standard rules pass 19 owner-isolation, schema and hostile-write emulator tests with zero failures.
- Gameplay simulation covers 50,000 scoring cases, 15,000 Cheat checks and 2,600 complete runs with zero failures.
- The earlier v6.9-to-v6.9.1 phone upgrade preserved 5,042 coins, best score 1,500, Heat 6, 13 Jokers, 31 cosmetics and 14 achievements.

## Remaining external validation

Before a public Google Play release, install the v6.9.1 AAB from the Internal testing track and confirm on a tester-listed Google account that Google sign-in, Firestore restore, score submission and all three Play Games leaderboard spans work. The newly integrated room artwork also needs one final physical-phone visual pass because the phone was disconnected after the earlier mobile-layout checks.

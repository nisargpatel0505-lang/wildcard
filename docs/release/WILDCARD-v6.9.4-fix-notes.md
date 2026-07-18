# WILDCARD v6.9.4

## Google Play Games rankings

- Wired the missing JavaScript-to-native `loadLeaderboardScores` bridge.
- The in-game Official Rankings overlay now loads Google's Daily, Weekly and All Time spans instead of always falling back to the native Google view.
- Opening Official Rankings signs the player into Play Games when needed and submits the account's existing best score before loading the board.
- The native Google Play leaderboard remains available as a fallback.

## Console verification

- Package: `com.nisarg.wildcard`
- Play Games project: `420107184674`
- Leaderboard: `CgkIotTbgp0MEAIQAQ` (`WILDCARD High Score`)
- Leaderboard state observed on 15 July 2026: draft, ready to publish to everyone.
- Tester account observed: `nisargpatel0505@gmail.com`.
- Tamper protection remains enabled.

## Daily Board

- The separate WILDCARD Daily Board API returned HTTP 200 for 15 July 2026.
- An empty `top` array means no Daily Challenge score has been posted for that date; it is not an outage.

## Verification

- Source/standalone verification: 50,000 scoring cases, 15,000 Cheat checks and 2,600 complete runs, zero failures.
- Google/Firebase identifier audit: zero failures and zero warnings.
- Signed release APK installed over v6.9.3 on the physical phone without clearing app data.
- Physical phone reports version code 17 / version name 6.9.4.
- APK signature verification passed.

## Release artifacts

- `releases/WILDCARD-v6.9.4.apk`
- `releases/WILDCARD-v6.9.4.aab`
- APK SHA-256: `6EE22CF5DD475DB281E9D17AA698EF0C30FF18787273A32E3619712038FC8EDD`
- AAB SHA-256: `EC643B91E277E8D49F18E11F94627B17C26011E36C93C6EFD67E1CB6C1E331DC`

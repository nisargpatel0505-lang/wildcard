# WILDCARD 9.1.0 phone-test delivery

Delivered 8 September 2026. **Google Play was not updated.** The owner requested
phone testing first; the live closed-test release remains 8.5.3 (72). No new
AAB was uploaded or submitted. Unpublished Console edits were discarded.

## Exact installed artifact

| Field | Verified value |
| --- | --- |
| Package | `com.nisarg.wildcard` |
| Version | `9.1.0`, Android version code `74` |
| Compiled source | `3516c0d5ead9161cffceb3d4e417345e96952507` |
| Branch | `release/v9.1.0-astra` |
| APK | `WILDCARD-v9.1.0-code74.apk` |
| Size | 87,057,348 bytes |
| SHA-256 | `c59b12ffc07bb5c90eca8d85e913b1354bd6ca2d3e866f872fc5c8747307bc31` |
| Signing certificate SHA-256 | `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717` |

The signed APK was installed as an in-place update on the owner's POCO X7.
Android reported installation success and version 9.1.0/code 74. There was no
uninstall, app-data clear, run abandonment or cross-app save merge. The separate
offline Astra app was not replaced. The final APK includes the last native
splash-overlay fix as well as the loading-screen and coin-medallion changes.

The intended GitHub prerelease/tag is `official-9.1.0-code74`; it points to the
compiled source above. This documentation may be committed after that source.
The prerelease is for owner testing, not a Google Play rollout.

## Phone checks and save preservation

- Final home check showed the same active Continue Run, Best Heat 21 and
  4,209-coin balance recorded immediately before the final visual rebuild.
- Earlier before/after checks also covered collection counts, achievements,
  best score, run history and equipped theme. No reset was observed.
- The pre-upgrade balance was 4,204; it became 4,209 during the earlier session,
  alongside the daily +5 reward disappearing. The final update did not reset
  that newer balance. No byte-for-byte private-save comparison is claimed.
- Startup logs for the current app process contained zero matches for
  `E/flutter`, `FATAL EXCEPTION` or the earlier Room initialization failure.
- Screenshots of loading, home, Cabinet, Vault prices, Shop and run selection
  were retained locally. Raw phone saves, device identifiers and signing
  material are not uploaded to the public repository.
- The upgrade creates its own local pre-migration recovery snapshot; the
  existing secure cloud-save rules and consent gates are unchanged.

The final loading screenshot confirms a visible segmented progress bar,
readable status/tip panel, no yellow fallback underlines and no duplicate
Android splash logo/scrim. One remaining polish issue is recorded honestly:
the central logo was not yet visible in the cold-start capture at 57%; an
earlier capture of the same Flutter layout at 86% showed it correctly. Logo
first-frame readiness needs another device check rather than a claim that
every startup frame is perfect. The home screenshot confirms the new gold W
coin medallion. An Android usage-duration notification in that screenshot is
system UI, not a WILDCARD overlay.

## Build and test evidence

- Release APK build succeeded, including Android native compilation and R8.
- Full regression before the final presentation follow-up: **476 passed,
  two experiment-only skips, zero failures**.
- After loading/coin changes: **24 targeted presentation tests passed**.
- Static Flutter analysis: **no issues found**.
- Four loader reference images cover 320x568 and 393x873 at 1.0x and 1.3x text;
  tests assert visible bar height, normal Material text decoration and layout.
- Coin reference rendering covers 15, 20, 46 and 96 pixels.
- The final native splash-only change was verified by successful APK build,
  installation and the physical-device cold-start screenshot.

Local logs remain under `flutter_app/build/official-delivery/`. The older local
AAB predates the final cosmetic/native follow-up and is **not** this delivery
artifact; it must not be uploaded as if it matches this APK. Rebuild a fresh
AAB from the accepted source only after the owner approves Play publication.

## Economy evidence and limitations

The update includes the measured run rewards, cheaper newcomer Vaults, free
strategy starters, early-shop improvements and once-only Journey progression
described in [the update report](WILDCARD-v9.1.0-update.md).

- 3,000 fresh-seed native-engine runs across eight cohorts, plus a separately
  identified 40-run pilot: zero invariant/scorer/reward-formula failures.
- The previous 7,550-run study is also preserved.
- Summary data and reproduction guidance: [economy folder](v9.1.0-economy/).
- Full raw archive: `WILDCARD-v9.1.0-economy-raw-data.zip`, 5,576,235 bytes,
  SHA-256 `7fca704d0650c2143c10b4bd4788819b335b249b3185edf62bb50fa1c597357e`.

Bots measure rule consistency, affordability and strategy outcomes, not human
enjoyment, retention or willingness to pay. Phone playtesting remains necessary.

Google Play supplied localized Shop metadata on the phone. No real purchase
was made and end-to-end paid fulfillment is not claimed. The sideloaded app
encountered Play Integrity/App Check rejection on protected cloud calls. That
startup rejection is now handled without losing the local save, and Back Up
Now can retry. **Successful cloud backup is not yet verified on this sideload.**
App Check enforcement was not weakened to bypass that limitation.

## Protected source refs

Rechecked at delivery, unchanged:

- `main`: `5a1a0d0f82a6b25415760bc7a77085a4e4fa3dd1`
- `agent/flutter-v8-native-beta`: `26e0f30f1a7b27ef75d1d5cbd8dab1d83ca3e8de`
- `agent/flutter-v8.2.0-dev14-feel`: `0b3e9fa42b872ac7b65509aa3d3ed67a9b3e2c59`

No merge into main and no Google Play deployment were performed.

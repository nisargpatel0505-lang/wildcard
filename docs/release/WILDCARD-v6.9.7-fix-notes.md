# WILDCARD v6.9.7

## Release identity

- Game and Android version: `6.9.7`
- Android version code: `20`
- Android package: `com.nisarg.wildcard`
- Canonical source: `www/index.html`
- Release APK: `releases/WILDCARD-v6.9.7.apk`
- Release AAB: `releases/WILDCARD-v6.9.7.aab`
- Source HTML SHA-256: `d1dbe27e7ccb12f7653c73952be0195d5507b12e0665470f0947e05d04c04c04`
- APK SHA-256: `bee5d4c0c79e0071f8351a366c615473158400c091bee5ff7dd4a8c873e2ce1c`
- AAB SHA-256: `2dc2566793a9850b4da79dc7fdd6af907dfffa38f6b1dd2e2f518d6a9b1b9d18`
- Google Play internal track: release draft prepared; manual AAB file selection remains

## Phone home screen and navigation

- Reorganized the main menu around New Run plus a compact two-column set of Shop, Cabinet,
  Weekly Missions, Settings and More actions.
- Used the available phone height to space the action rows more evenly without adding menu
  clutter.
- Combined Coin Store and Wardrobe behind one Shop button.
- Moved Achievements, Local High Scores, Daily Board, Play Games Rankings and How to Play into
  More.
- New Run now offers Normal Run, unlock-aware Gauntlet and Daily Challenge in one mode picker.
- A completed Daily Challenge is disabled until the next local day and displays its saved score.
- Added a safe Replay tutorial action in Settings without resetting player progress.
- Removed the production developer grant interface and its client-side unlock path.

## Economy and cosmetics

- Standard UI themes now have a consistent 1,000-coin price.
- Illustrated premium Sly-room themes cost 3,500 coins for Rare and 5,000 coins for Wild.
- Wardrobe navigation now concentrates on Tables, UI Themes and Sly Skins.
- Existing owned cosmetics and equipped selections remain compatible with the current save.
- Cosmetic Vault odds now disclose the real 0.8% UI-theme gate and calculate rarity odds from
  the same two-stage draw used by the reward code.
- Disabled Win FX cosmetics are excluded from paid vault rewards.

## Gameplay integrity

- A Daily attempt is consumed and saved as soon as play begins, preventing force-close retries.
- Daily copy now accurately explains that deck order and Heat modifiers are shared while shop
  stock can differ with each player's unlocked collection.
- THE HOUSE description now matches the implemented 10% target increase.
- The final first-run coaching stage now appears when the player reaches the next Heat.
- Resumed runs count live cards by rank/suit totals in the deck matrix instead of comparing
  deserialized object identities.

## Scoring and Sly

- Removed the expensive gameplay Win FX particle/pulse path from scored hands to reduce mobile
  scoring stutter.
- Preserved the approved Normal and Fast score-beat timings and scoring results.
- Sly now reacts at score reveal to High Card, Pair, Two Pair, Trips, Straight, Flush, Full House,
  Quads, Straight Flush and Royal Flush outcomes.
- Cosmetic refreshes preserve Sly's current expression instead of resetting it, and alternate
  Sly skins retain a visible mood response.
- Replaced generic dialogue with short, gameplay-focused taunts about the hand, target, Mult and
  Heat state.

## In-run phone layout

- Rebalanced the tall-phone layout so the Joker row has more room and the table sits lower in the
  usable viewport.
- Kept selected-card movement inside the available card area and retained the existing table
  opacity so room artwork remains visible.
- The Heat intro now shows the active modifier name, full effect and target together.
- Replaced the horizontally scrolling deck view with a fixed 4-by-13 rank/suit matrix showing
  live, in-hand, played and copied-card state at a glance.

## Compatibility and deployment

- Local-first saves, optional cloud backup, Google Play Games bridges, Firebase configuration,
  AdMob and Billing integration remain in place.
- The standalone browser build is regenerated from the same canonical source used by Android.
- The Pi deployment script publishes `WILDCARD-v6.9.7.apk`,
  `WILDCARD-v6.9.7-release.apk` and `WILDCARD-latest.apk`.

## Verification

- Canonical and standalone JavaScript compile successfully.
- The deterministic v6.9.7 audit completed 10,000 randomized scoring/Joker cases, 5,000
  six-card Cheat comparisons and 550 complete bot runs.
- The audit found zero Cheat mismatches, scoring/data failures, hook exceptions or run-invariant
  failures.
- Google/Firebase repository configuration passes its hard checks, including the direct and
  Google Play signing certificate registrations.
- Final source/APK/AAB hashes are recorded above. The Play release name and notes are saved in
  its Internal-testing draft; the signed AAB is ready for the remaining manual file selection.

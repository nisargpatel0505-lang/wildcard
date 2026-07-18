# WILDCARD v6.9.11

## Release intent

v6.9.11 is a phone-first gameplay and clarity update. It makes Normal scoring readable without bringing back Win FX, improves adjacent-card selection and Joker feedback, cleans up Vault and Cabinet presentation, and hardens Daily Board, analytics, Billing callback, and save-sensitive paths.

## Scoring and mobile play

- Normal scoring now uses a 1.85 timing multiplier. Fast uses 1.04 and keeps the same event sequence.
- The hidden tap-to-fast-forward path was removed. Touching the screen cannot accidentally accelerate scoring.
- Reduced-motion users receive shortened waits rather than disabled visuals followed by a full slow timeline.
- Win FX remains fully removed from gameplay and the Wardrobe.
- Joker triggers show a visible `TRIGGER` chip, highlight the Joker, update a live status line with the Joker name and effect, and remain readable longer in Normal.
- The Joker status line now correctly distinguishes an empty row from an equipped starter Joker.
- Five Jokers use a centred 3+2 phone grid.
- Nine cards have slightly more separation. Delegated hit-testing chooses the nearest stable card centre, so a raised selected card cannot steal a neighbouring tap.
- Selected cards lift 18 px and remain inside the table.
- Sly’s speech remains game-focused and reacts after the scoring sequence.
- The compact deck overview shows every rank and suit at once on a phone.

## Vaults, rewards, and notifications

- Wardrobe and Joker Chests include a context-aware rewarded-ad `+25` shortcut.
- Cosmetic Vault shelf copy no longer presents an overlapping probability series. It clearly guarantees a new duplicate-free cosmetic.
- The common footer now distinguishes Joker rarity odds from the Cosmetic Vault guarantee.
- Joker reveal no longer repeats the reward name and effect.
- Claim actions sit inside the illuminated Vault stage and remain above the dimmed background.
- Android/browser Back is consumed while a Vault reveal is running. A saved reward must be claimed before leaving, preventing stale reveal timers from affecting another purchase.
- Achievement notices queue, wrap safely on narrow phones, and point players to the claim screen.
- Yellow menu badges identify ready Weekly Mission rewards and unclaimed achievement rewards.

## Daily Challenge and board

- Daily shop rolls use the complete Joker catalogue for every player; a locked Joker bought during the Daily remains run-only.
- The Daily challenge date is captured at launch and used for its seed, local result, and score submission. A run crossing midnight cannot post to the next day’s board.
- Board requests use explicit timeouts, retry one failed GET, and show `NETWORK`, `TIMEOUT`, or HTTP status diagnostics.
- The proposed `300 / 200 / 200` top-three rewards are labelled as planned and not active. Secure payout still requires authenticated identity, score validation, final next-day settlement, and an idempotent claim ledger.

## Progression and presentation

- Glass Joystick survives its first cleared Heat, then rolls the documented 25% shatter chance on later clears. Its armed state saves with the run and resets when sold or removed.
- Cabinet collection percentage includes Jokers and cosmetics.
- Cabinet grids contain complete rows and add runs, wins, Jokers, and recent-sample context.
- Secondary collection/settings screens use a still, theme-tinted premium poker-room background.
- UI-theme marquee lights derive from theme colours.

## Android services

- The Billing v13 bridge recognises `receipt.collection` and `sourceReceipt.transactions`.
- A verified callback is delivered before `receipt.finish()`, only one purchase is active, duplicate receipt events cannot grant twice in one session, and unavailable/order-failure paths fail closed.
- Public Billing remains blocked until backend receipt/token verification, active Play Console products, and Play-installed license-tester flows are proven.
- Pi analytics accepts both v6.9.10 and v6.9.11 while preserving the aggregate-only, identifier-free payload.
- Google/Firebase repository identifiers, direct-signing SHA-1, Play-signing SHA-1, package name, Play Games app ID, and leaderboard resource all pass local configuration audit. Play Games Console publication and tester enablement remain console checks.

## Verification

- Canonical HTML SHA-256: `0ad6a95e87b170d93099e40de1105a8fa5f45598ef794e2a4403b7641fa2d111`
- 10,000 scoring/Joker cases
- 5,000 Cheat comparisons
- 550 complete runs
- Zero data failures, hook errors, invariant failures, or Cheat mismatches
- Native rewarded-ad and Billing callback tests passed
- Economy/reward idempotency tests passed
- Pi analytics privacy and aggregation tests passed
- Phone-sized browser QA passed at 393 CSS px: adjacent selection, bottom card ranks, 3+2 Joker grid, trigger feedback, deck overview, and runtime console

## Android artifacts

- Developer APK: `releases/WILDCARD-v6.9.11-developer.apk` — SHA-256 `f4d9053e474c4ff1845a234628c243dd60fc52aa66a2b3adfb7b894a7c5d52bb` — version code 30
- Release APK: `releases/WILDCARD-v6.9.11.apk` — SHA-256 `e3428358fb18773ad083052c56eec54f645d116a00f695944bdae9f8ddb307c7` — version code 31
- Release AAB: `releases/WILDCARD-v6.9.11.aab` — SHA-256 `724c97a0eadbf7ca6e114edee47048ea4030da1c9cb788f8b0c0b7c41706e14f` — version code 31
- Release certificate SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`

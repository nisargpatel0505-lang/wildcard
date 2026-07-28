# WILDCARD v8.5.0 implementation report

## Release identity

- Flutter version: `8.5.0+64`
- Android package: `com.nisarg.wildcard`
- Development branch: `agent/flutter-v8.5.0-chests-progression-arcade`
- Parent branch: `agent/flutter-v8.4.1-sim-balance`
- Authoritative client: `flutter_app/`
- Legacy presentation reference only: `www/index.html`

This release is intentionally isolated from `main`. It does not alter the
protected original Flutter branches or merge into the released WebView client.

## What changed

### Royal Vault

The placeholder chest presentation was replaced with a native Flutter Royal
Vault built from original layered Wood, Gold and Cosmetic artwork. The
animation uses one controller and bounded transforms, opacity and custom paint:
lock scan, rarity anticipation, lid opening, beam/particles, reward rise and a
clear Claim state.

Rewards and account spending are persisted before the reveal starts. Repeated
taps and repeated claim IDs are idempotent. Normal, Fast and reduced-motion
timelines remain readable and are covered at six phone sizes.

Detailed artwork prompts, generated files, timings, screenshot evidence and
package-size impact are recorded in
`WILDCARD-v8.5.0-royal-vault-visual-evidence.md`.

### Permanent Joker acquisition

- New accounts begin with the exact ten-Joker starter set.
- Permanent direct Joker purchasing was removed.
- After the tutorial, permanent discoveries come from Wood or Gold Vaults.
- Existing ownership is preserved.
- The first genuine Normal loss offers one durable Common/Uncommon comeback
  reward. It excludes WILD and measured high-impact Jokers.
- In-run shops only offer Jokers the account has discovered; purchases last
  for that run.
- Wood is 200 coins with 70% Common / 27% Uncommon / 3% Rare / 0% WILD.
- Gold is 350 coins with 52% Uncommon / 44% Rare / 4% WILD.
- Duplicate protection and exhausted-rarity fallthrough are deterministic.
- The UI displays the exact live probabilities from the same functions used by
  the reward rolls.

### Joker shop guardrails

WILD offers remain blocked until Heat 6 and use a 24-miss eligible-shop pity.
Seven measured high-impact non-WILD Jokers are blocked until Heat 4, use half
their same-rarity shelf weight, and share a maximum-one-per-shelf rule with
WILD Jokers. Tutorial shelves, comeback rewards, Arcade shelves and restored
legacy shelves all pass through the same constraints.

### Arcade prototype held back

The native three-card Arcade prototype remains isolated in source and tests for
possible future work, but it is deliberately not routed or imported by the
shipped application. The v8.5 phone APK exposes Normal, Daily and Gauntlet
only; Flutter tree shaking excludes the unreferenced Arcade screens.

### Long-term progression

- Daily login: 5 / 10 / 15 / 20 / 25+ coins, with missed-day reset and trusted
  UTC handling.
- Five deterministic Weekly Missions from a ten-mission pool.
- One rewarded refresh per week; completed unclaimed missions stay pinned.
- Eight long-term achievement families with 41 sequential tiers.
- Manual, idempotent tier claiming and five equipable titles.
- Endless milestones at 1 / 5 / 10 / 25 / 50 / 100.
- Migration-safe typed counters and Cabinet presentation.

### Ads and shop layout

The paid entitlement is presented as **Remove Forced Ads**. It removes
automatic terminal interstitials; optional rewarded adverts remain optional
and only grant rewards after a completed callback. Forced ads use a central
cooldown policy and exclude the tutorial, first run, Arcade, short abandon and
repeat terminal events.

The between-Heat shop uses a safe bottom action dock. Next Heat and View Deck
remain clear of system insets and scale correctly across the required phone
sizes.

### Sly's Stake Contract

The payout curve now protects early losses while flattening the previous
Heat 9-12 farming tail. A 4,500-run confirmation placed weak/new EV at
0.812-0.878, mid EV at 0.952-0.960 and skilled/late EV at 1.043-1.064 across
Easy, Medium and Hard. The 200-coin cap, target multipliers, scoring, cards and
RNG remain unchanged.

### Theme propagation

All 17 UI themes now resolve tokens across all 24 registered surfaces:
loading, privacy, home, mode selection, Normal play, tutorial,
Royal Vault, both shops, collection, wardrobe, settings, Cabinet,
achievements, missions, ad break, overlays, results, leaderboard and More.

Intentional semantic exceptions are playing-card suit colours, rarity/tier
colours, native ad creative, table/chest artwork, cinematic black/death
effects and neutral disabled-Joker shading. Table felt and Sly appearance
remain separately equipable.

## Safety and compatibility

- Existing saves and permanent ownership are preserved.
- Legacy shelves and pity counters are normalized on resume.
- Daily progress remains isolated from Normal progression.
- RNG checkpoints prevent process-kill rerolls.
- Developer grants cannot upload cloud progress or leaderboard scores.
- Release builds hide developer tools.
- No scoring formula, hand evaluator, target curve or deck-order manipulation
  was introduced by the presentation and acquisition work.

## Evidence

- `WILDCARD-v8.5.0-economy-balance-evidence.md`
- `WILDCARD-v8.5.0-economy-balance-results.json`
- `WILDCARD-v8.5.0-royal-vault-visual-evidence.md`
- `WILDCARD-v8.5.0-stake-curve-evidence.md`
- `WILDCARD-v8.5.0-stake-curve-results.json`
- `WILDCARD-v8.5.0-difficulty-simulation.md`
- `WILDCARD-v8.5.0-joker-shop-rarity.md`
- `WILDCARD-v8.5.0-chest-distribution.md`
- `wildcard-v8.5.0-joker-balance.csv`
- `wildcard-v8.5.0-joker-pairs.csv`

## Remaining release gates

Before Play promotion, complete an eyes-on physical-device pass of both Vault
speeds, one full Normal run, cloud backup/restore, Play Games,
and Play-installed billing. The final locally signed APK can update the
existing sideload in place; a Play-signed build requires the documented
one-time cloud migration route.

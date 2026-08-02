# WILDCARD v8.6.0 — Native Level Mode Implementation

## Release identity

- Working branch: `agent/flutter-v8.6.0-level-mode`
- Exact baseline: `39f038295879a332eb83ba76554512edf63d2389`
- Baseline title: `Add complete suit kingdom cosmetic themes`
- Flutter version: `8.6.0+67`
- Android package: `com.nisarg.wildcard`
- Scope: native Flutter only; `www/index.html` and the WebView game were not changed.

## Outcome

This branch adds a fully playable, native 100-table campaign without changing
the existing Arcade scoring formula, Joker catalogue, economy, Daily attempt,
stake, shop, leaderboard, ads, cloud-save or entitlement behaviour.

The New Run flow is now:

```text
Home
└── New Run
    ├── Levels
    │   └── Level Select
    │       └── Level Brief / temporary Joker choice
    │           └── one authored Level table
    └── Arcade
        └── existing Normal / Daily / Gauntlet picker
```

## Architecture

### Catalog and authored layouts

`assets/data/levels-v8.5.2.generated.json` is the exact supplied production
catalog. `LevelCatalog` parses schema 2 into immutable definitions and rejects
unsupported schemas, non-sequential IDs, invalid Joker references, bad Joker
selection counts, duplicate layouts, malformed cards, duplicate physical
cards, bad blocked-deck sizes, undersized decks and invalid numeric rules.

The shipping asset contains 100 sequential levels and 1,460 explicit deck
layouts. A chosen layout's ID and authored RNG seed are retained for retry and
resume. The selected layout is checkpointed before the first deal, and the
dealt opening state is checkpointed immediately afterwards. Blocked cards are
derived by comparing the exact layout with the native 52-card deck; no random
percentage is removed at runtime.

### Existing scoring engine, Level-only overrides

Level Mode calls `WildcardScoringEngine`; it does not contain a second
production scoring formula. An optional immutable `LevelScoringOverride`
implements the authored Level-only rules. A null override follows the existing
Arcade path and is covered by snapshot/parity tests.

Supported overrides include High Card zero, allowed hand types, face-card rank
zero, red/black rank suppression and factors before Mult, repeat decay,
no-repeat scoring, per-play final factors, disabled-suit rotation and readable
score events. Preview and committed scoring use the same override.

### Objective and table rules

`LevelObjectiveProgress` durably tracks score, hand counts/history, exact
sequence state, variety, quality, premium-hand type coverage, forbidden hands
and per-hand cumulative checkpoints. It supplies concise objective/progress
text for Sly's Level-only speech panel.

The controller installs the catalog target, hands, discards, hand size, maximum
selection, exact deck and temporary Jokers. It also supports discard target
tax, shrinking discards, rotating/blackout/fading Jokers, disabled-suit
rotation, card-burning hooks and Scorched Ranks. One Level is one table: it has
no shop, revive, Heat rewards, interest, stake, starter payment, Daily charge,
Arcade statistic mutation or leaderboard submission.

### Persistence and progression

Account persistence now contains typed `highestUnlockedLevel`,
`clearedLevelIds`, `levelBestScores` and `levelAttempts` fields. Old accounts
migrate to Level 1 unlocked. Clearing a table durably unlocks the next level;
clears are replayable and failures have unlimited free retry. Direct controller
launches reject locked or out-of-range levels.

Cloud reconciliation is monotonic: highest level and scores/attempts use max,
clears use union, and a remote save cannot relock local progress. Existing
unknown fields, entitlements and economy protections are retained.

Run saves retain the catalog reference, layout, authored seed through the
restored scoring state, exact remaining deck and hand, temporary Jokers,
objective progress, dynamic target, checkpoint violation state, disabled suit,
faded/blocked Joker state, phase and pending transition.

### Native UI

- `RunTypePickerScreen`: large Levels and Arcade entry points.
- `LevelSelectScreen`: all 100 levels with chapters, locked, cleared and
  frontier states plus best score and attempts.
- `LevelBriefScreen`: pass requirement, target, hands, discards, blocked-card
  count, visible rules, fixed/negative Jokers and exact temporary Joker choice.
- Existing game host/table: Level label, objective/progress, Level-specific Sly
  copy, visible rule state and no generated dialogue overwrite.
- Deck overlay: exact blocked-card cells, red-X treatment, legend and semantic
  labels.
- Result screen: Retry, Level Select and Next Level (not shown after Level 100),
  with the authored hint after three attempts.

## Changed implementation areas

- `lib/domain/level_mode/`: catalog, definitions, objective progress and native
  simulation/replay harness.
- `lib/domain/scoring_engine.dart`: optional immutable Level scoring override.
- `lib/domain/game_rules.dart`: effective Level target/hand/discard/selection
  values while preserving Arcade defaults.
- `lib/game/game_models.dart` and `lib/game/game_controller.dart`: Level attempt
  config, exact layout seed, lifecycle, checkpoints, table rules and results.
- `lib/domain/account_state.dart`, `lib/services/local_save_repository.dart`
  and `lib/app/app_controller.dart`: durable progression and monotonic merge.
- `lib/app/wildcard_app.dart`, `lib/app/screens/` and `lib/ui/screens/`: native
  run-type, selection, brief, play, deck and result presentation.
- `tool/level_mode_validation.dart`: re-runnable native campaign policy and
  optional solver-route validation CLI.
- `test/domain/level_mode/` and `test/app/level_mode_flow_test.dart`: catalog,
  scoring, objectives, controller, save/merge, simulation and UI coverage.
- `pubspec.yaml`: version `8.6.0+67` and the production data asset.

## Exact shipping level table

Target `0` denotes an objective-only table, not missing data.

| Level | Name | Target | Hands | Discards | Layouts |
|---:|---|---:|---:|---:|---:|
| 1 | First Pair | 0 | 5 | 5 | 12 |
| 2 | Pair Practice | 0 | 5 | 5 | 12 |
| 3 | Two at Once | 0 | 5 | 5 | 12 |
| 4 | Double Two | 0 | 5 | 5 | 12 |
| 5 | Triple Two | 0 | 5 | 5 | 12 |
| 6 | Three Together | 0 | 5 | 5 | 12 |
| 7 | Run It | 0 | 5 | 5 | 12 |
| 8 | Same Suit | 0 | 5 | 5 | 12 |
| 9 | Full House | 0 | 5 | 5 | 12 |
| 10 | First Score Test | 515 | 5 | 5 | 12 |
| 11 | Pair Chain | 145 | 4 | 5 | 12 |
| 12 | Two Pair Chain | 240 | 4 | 5 | 12 |
| 13 | Mixed Set | 305 | 5 | 5 | 12 |
| 14 | Straight Practice | 455 | 5 | 5 | 12 |
| 15 | Flush Practice | 530 | 5 | 5 | 12 |
| 16 | House Party | 425 | 5 | 5 | 12 |
| 17 | Four Strong | 600 | 5 | 5 | 12 |
| 18 | Variety Pack | 550 | 5 | 5 | 12 |
| 19 | No Waste | 450 | 5 | 5 | 12 |
| 20 | Basics Final | 535 | 5 | 5 | 12 |
| 21 | No High Cards | 380 | 5 | 5 | 12 |
| 22 | Pairs Only | 245 | 5 | 5 | 12 |
| 23 | Red Heat | 430 | 5 | 5 | 12 |
| 24 | Blackout | 480 | 5 | 5 | 12 |
| 25 | Face Off | 410 | 5 | 5 | 12 |
| 26 | Ace Lock | 485 | 5 | 5 | 20 |
| 27 | Repeat Tax | 435 | 5 | 5 | 12 |
| 28 | Costly Discards | 480 | 5 | 5 | 12 |
| 29 | Final Hand | 410 | 5 | 5 | 12 |
| 30 | Modifier Checkpoint | 450 | 5 | 5 | 12 |
| 31 | One of Each | 460 | 5 | 5 | 12 |
| 32 | In Order | 300 | 5 | 5 | 12 |
| 33 | Even Lock | 625 | 5 | 5 | 20 |
| 34 | Odd Lock | 610 | 5 | 5 | 20 |
| 35 | Suit Shift | 455 | 5 | 5 | 12 |
| 36 | Shrinking Discards | 485 | 5 | 4 | 12 |
| 37 | Four Hands | 370 | 4 | 3 | 12 |
| 38 | Two Discards | 480 | 5 | 2 | 12 |
| 39 | Rising Pressure | 375 | 4 | 3 | 12 |
| 40 | Modifier Final | 420 | 5 | 5 | 12 |
| 41 | Quarter Blocked | 445 | 5 | 5 | 20 |
| 42 | Pairs Through It | 335 | 5 | 5 | 20 |
| 43 | Double Pair | 360 | 5 | 5 | 20 |
| 44 | Broken Run | 380 | 5 | 5 | 20 |
| 45 | Thin Suit | 410 | 5 | 5 | 20 |
| 46 | Forty Down | 450 | 5 | 5 | 20 |
| 47 | Adapt | 515 | 5 | 5 | 20 |
| 48 | Half Deck | 385 | 5 | 5 | 20 |
| 49 | Find a Route | 395 | 5 | 5 | 20 |
| 50 | Half-Deck Final | 420 | 5 | 5 | 20 |
| 51 | Half and No High | 405 | 5 | 5 | 20 |
| 52 | Half and Tight | 475 | 5 | 3 | 20 |
| 53 | Half and Faceless | 385 | 5 | 5 | 20 |
| 54 | Red Rescue | 395 | 5 | 5 | 20 |
| 55 | Black Rescue | 395 | 5 | 5 | 20 |
| 56 | Half Variety | 415 | 5 | 5 | 20 |
| 57 | Half Sequence | 320 | 5 | 5 | 20 |
| 58 | Half Pressure | 525 | 4 | 3 | 20 |
| 59 | Shifting Suit | 410 | 5 | 5 | 20 |
| 60 | Restricted Final | 400 | 5 | 5 | 20 |
| 61 | Copper Chip | 495 | 5 | 5 | 12 |
| 62 | Pair Polisher | 660 | 5 | 5 | 12 |
| 63 | Chips Times Mult | 800 | 5 | 5 | 12 |
| 64 | Royal Engine | 680 | 5 | 5 | 12 |
| 65 | Glass Cannon | 1275 | 5 | 4 | 12 |
| 66 | Pair Build | 695 | 5 | 5 | 12 |
| 67 | Straight Build | 1170 | 5 | 5 | 12 |
| 68 | Flush Build | 1400 | 5 | 5 | 12 |
| 69 | Choose Three | 1720 | 5 | 5 | 12 |
| 70 | Joker Checkpoint | 5350 | 5 | 5 | 12 |
| 71 | Pair Architect | 850 | 5 | 5 | 12 |
| 72 | Straight Architect | 1545 | 5 | 5 | 12 |
| 73 | Flush Architect | 1425 | 5 | 5 | 12 |
| 74 | Rank Architect | 875 | 5 | 5 | 12 |
| 75 | Dead Slot | 1320 | 5 | 5 | 12 |
| 76 | Rising Power | 1025 | 5 | 5 | 12 |
| 77 | Joker Blackout | 1125 | 5 | 5 | 12 |
| 78 | Quarter Block Build | 1420 | 5 | 5 | 20 |
| 79 | Half Block Build | 1200 | 5 | 5 | 20 |
| 80 | Build Final | 4600 | 4 | 3 | 12 |
| 81 | Double Trouble | 2550 | 5 | 5 | 12 |
| 82 | No Repeat Build | 3300 | 5 | 5 | 12 |
| 83 | Black Build | 1520 | 5 | 5 | 12 |
| 84 | Red Build | 1525 | 5 | 5 | 12 |
| 85 | Expensive Discards | 1725 | 5 | 5 | 12 |
| 86 | Scorched Ranks | 3700 | 5 | 5 | 12 |
| 87 | Combo Ladder | 710 | 5 | 5 | 12 |
| 88 | Four Styles | 2950 | 5 | 5 | 12 |
| 89 | Half-Deck Blackout | 1795 | 5 | 5 | 20 |
| 90 | Expert Final | 2500 | 5 | 5 | 12 |
| 91 | Open Build | 6100 | 5 | 5 | 12 |
| 92 | Half-Deck Power | 1475 | 5 | 5 | 20 |
| 93 | Half-Deck Variety | 3300 | 5 | 5 | 20 |
| 94 | Minimal Discards | 1970 | 5 | 2 | 12 |
| 95 | Faceless Build | 1000 | 5 | 5 | 20 |
| 96 | Low-Card Lock | 2100 | 5 | 5 | 20 |
| 97 | Decay | 4400 | 5 | 5 | 12 |
| 98 | Fading Jokers | 1695 | 5 | 5 | 12 |
| 99 | The Wall | 3500 | 5 | 5 | 20 |
| 100 | Master Level | 5345 | 5 | 3 | 24 |

## Native simulation and validation

The re-runnable native CLI calls the real `WildcardScoringEngine` and the real
Level objective engine. It was run once for every shipping layout with each of
two deterministic policies, using the catalog-recommended loadout only as
hidden validation input:

| Policy | Attempts | Clears | Clear rate | Median score | Failed layouts | Runtime |
|---|---:|---:|---:|---:|---:|---:|
| Adaptive planning | 1,460 | 1,079 | 73.90% | 556 | 381 | 105.39 s |
| Hand ranking | 1,460 | 699 | 47.88% | 550 | 761 | 76.20 s |

Adaptive planning uses objective-aware selection, per-hand score pace,
checkpoint urgency and deterministic redraws. Hand ranking is intentionally a
simpler highest-score baseline. They are independent approaches rather than
duplicated scoring formulas.

Level 100 results:

| Policy | Clears / 24 | Clear rate | Median score |
|---|---:|---:|---:|
| Adaptive planning | 1 / 24 | 4.17% | 3,029 |
| Hand ranking | 8 / 24 | 33.33% | 4,646 |
| Combined policy attempts | 9 / 48 | 18.75% | — |

The two-policy Level 100 result is inside the requested 15–30% proxy band. At
chapter level the two deterministic policies bracket the supplied proxy rather
than reproducing it exactly, especially on late Joker-build tables. This was
investigated as a policy/mirror difference: native scoring snapshots, preview
parity and catalog targets pass, while the supplied Python solver routes needed
for exact action-level comparison are absent. No target was changed without
that required proof.

Structured per-level attempts, clear rate, median score, layout failures and
recommended-loadout frequencies are saved in:

- `docs/release/level-mode-policy-adaptive-full.json`
- `docs/release/level-mode-policy-hand-ranking-full.json`

## Verification

- Final `flutter analyze --no-pub`: no issues (26.7 seconds).
- Level Mode domain/controller/UI suite: 73/73 passed.
- Existing app/core/game/services partition: 93/93 passed.
- Existing UI/golden partition: 138/138 passed.
- Existing tracked domain/widget partition: 164/164 passed.
- Existing native simulation/balance partition: 40 passed, one explicitly
  opt-in heavyweight Joker contribution test skipped by its own environment
  guard.
- Native run simulation: 2,000 complete deterministic runs, zero invariant
  failures (1,000 random-policy and 1,000 ranked-policy runs).
- Release APK build: passed.
- Release AAB build: passed.
- APK contents: production level catalog present; solver-route artifact absent.
- APK manifest: `com.nisarg.wildcard`, version `8.6.0`, code `67`.
- APK signature: v2 verified, signer certificate SHA-256
  `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.
- AAB JAR signature integrity: verified.

An unfiltered `flutter test` discovery run also picked up two unrelated,
untracked local `v850_*_audit_test.dart` Monte Carlo probes and exceeded the
bounded test window. Those files are not part of this branch and were neither
changed nor staged. All tracked suites plus every Level Mode test were run in
the explicit partitions above.

## Known limitation: required solver artifact absent

`WILDCARD-solver-results-v8.5.2.generated.json` was not present in the supplied
Downloads files, repository, local Git refs or available attachments. The
provided SHA manifest expects:

```text
29d06a8ee81ae4cf8b43ccd5280934f9f0aa47b9b849b1616e9b819f2b718e3b
```

Consequently this machine could not truthfully replay the claimed 1,460 solver
routes or prove at least one supplied solver route for every layout. The harness
reports this as unavailable and never fabricates a pass. When the file is
provided, run:

```text
dart run tool/level_mode_validation.dart \
  --solver PATH/TO/WILDCARD-solver-results-v8.5.2.generated.json \
  --output docs/release/level-mode-solver-replay.json
```

Solver JSON parsing requires every play to carry expected hand type, play score
and cumulative score; successful coverage is reported only when the real native
engine matches those checkpoints and completes the final objective.

## Artifact hashes

| Artifact | Size | SHA-256 |
|---|---:|---|
| `assets/data/levels-v8.5.2.generated.json` | 1,685,306 bytes | `d9de66f8893938f5220dddbd0976ef5162bfab0b9e81bf3a6eb0a2d800a3f904` |
| `docs/release/level-mode-policy-adaptive-full.json` | 155,421 bytes | `f9ece1e916ade6dd6f0449bb9647495d05016ab21292300d0a4918e8d30dce26` |
| `docs/release/level-mode-policy-hand-ranking-full.json` | 180,301 bytes | `3a68845a821a52f303f50edd04ff2cfe13267011da776da1ed8320b295ad9a4f` |
| `releases/WILDCARD-v8.6.0-code67-level-mode.apk` | 87,768,316 bytes | `6cd4693022617cb6cc853221773d3fe83345d486e5840b3eed258c713167123b` |
| `releases/WILDCARD-v8.6.0-code67-level-mode.aab` | 89,744,654 bytes | `2009c248f04cba60bf5f4fab4b846e30972bdf5d5ff632dbe65196001c3127fc` |

The APK/AAB are local release outputs and are intentionally not added to Git;
the source branch and evidence reports reproduce them.

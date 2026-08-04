# WILDCARD v8.5 Sly's Contract stake-curve evidence

## Decision

The Standard-run stake payout has been changed from:

`[0, 5, 10, 18, 28, 40, 55, 72, 92, 115, 140, 170, 200]`

to:

`[0, 20, 35, 45, 55, 70, 82, 92, 100, 105, 110, 115, 150]`

The difficulty payout multipliers are now:

| Difficulty | Old | New |
| --- | ---: | ---: |
| Easy | 0.60 | 0.80 |
| Medium | 1.00 | 0.92 |
| Hard | 1.60 | 1.00 |

Target multipliers remain exactly `0.60 / 1.00 / 1.30`. No scoring, target,
deck, shop, Joker or RNG rule was changed. The stake cap remains 200.

The new base curve improves the refund at every early/mid point from Heat 1
through Heat 8. Its Heat 9-to-12 climb is 45 rather than 85, removing the
old late-progression leak. A full clear still jumps from 115 to 150 so a win
has a meaningful premium over a near miss.

## Exact player-facing return for 100 staked

| Heats cleared | Easy | Medium | Hard |
| ---: | ---: | ---: | ---: |
| 0 | 0 | 0 | 0 |
| 1 | 16 | 18 | 20 |
| 2 | 28 | 32 | 35 |
| 3 | 36 | 41 | 45 |
| 4 | 44 | 51 | 55 |
| 5 | 56 | 64 | 70 |
| 6 | 66 | 75 | 82 |
| 7 | 74 | 85 | 92 |
| 8 | 80 | 92 | 100 |
| 9 | 84 | 97 | 105 |
| 10 | 88 | 101 | 110 |
| 11 | 92 | 106 | 115 |
| 12 | 120 | 138 | 150 |

These are gross returned coins. The stake is deducted on entry, so net profit
is return minus stake.

## Reproducible validation

The exact production simulation engine ran 4,500 Standard runs:

- 500 seeds per cell, `0x71010000` through `0x710101f3`.
- New/weak proxy: immediate-score hand-ranking strategy with the ten starter
  discoveries.
- Mid proxy: pair-building strategy with a fixed 25-Joker discovery pool.
- Skilled/late proxy: adaptive strategy with all 102 public Jokers discovered.
- Every difficulty was run as an isolated shard and merged only after all
  shards agreed on the payout configuration.
- The old and new payouts use each run's same Heat result. The payout change
  therefore cannot alter the deck, shop, play decision or RNG outcome.

| Difficulty | Profile | Old gross EV | New gross EV | Target |
| --- | --- | ---: | ---: | ---: |
| Easy | New/weak | 0.8370 | **0.8784** | 0.80–0.90 |
| Easy | Mid | 0.9944 | **0.9595** | 0.95–1.00 |
| Easy | Skilled/late | 1.0643 | **1.0644** | 1.03–1.08 |
| Medium | New/weak | 0.8362 | **0.8577** | 0.80–0.90 |
| Medium | Mid | 1.1093 | **0.9515** | 0.95–1.00 |
| Medium | Skilled/late | 1.4110 | **1.0634** | 1.03–1.08 |
| Hard | New/weak | 0.9597 | **0.8122** | 0.80–0.90 |
| Hard | Mid | 1.3666 | **0.9549** | 0.95–1.00 |
| Hard | Skilled/late | 1.8519 | **1.0426** | 1.03–1.08 |

All nine cells land inside their intended band. In particular, the skilled
Hard leak falls from 1.8519 to 1.0426 without making the payout random or
manipulating gameplay.

An external claim of late EV `1.186 / 1.875 / 2.783` could not be reproduced
because its referenced `tool/opus_economy.dart`, cohort definitions and seeds
were not present. It was treated as directional evidence of the same leak.
The table above is independently reproducible from the current v8.5 source.

## Evidence and regression protection

- Runner: `tool/v85_stake_curve_audit.dart`
- Machine-readable result:
  `docs/release/WILDCARD-v8.5.0-stake-curve-results.json`
- Result SHA-256:
  `23c35322b727682bf74804119dd0e797c3179a53d7af0bc65b02f66ab826f0f4`
- Result size: 5,991 bytes
- Focused stake, difficulty and economy tests: 51 passed.
- Focused static analysis: no issues.

The regression tests lock the exact curve, monotonicity, early protection,
late-tail width, 200 cap, target independence, per-difficulty displayed payout
table and all nine audited EV bands.

# WILDCARD v8.5.0 difficulty simulation

## Method

The live Dart `WildcardSimulationHarness` ran 900 complete deterministic
Normal runs: 100 runs for each difficulty and discovery cohort. The Adaptive
bot chooses hands and shop purchases strategically. All cohorts started with
Copper Coin and Pair Polisher. The discovery pools were the starter 10, a
fixed 25-Joker early/mid pool, and all 102 public Jokers.

These are balance indicators, not a claim that the bot exactly represents
human players. Every run completed with zero engine invariant failures.

## Results

| Difficulty | Discovery | Wins | Win rate | Avg Heats | Avg account coins |
|---|---|---:|---:|---:|---:|
| Easy | Starter 10 | 66/100 | 66% | 11.62 | 50.36 |
| Easy | 25 Jokers | 59/100 | 59% | 11.30 | 48.00 |
| Easy | All 102 | 55/100 | 55% | 11.21 | 47.10 |
| Medium | Starter 10 | 17/100 | 17% | 10.77 | 40.72 |
| Medium | 25 Jokers | 16/100 | 16% | 10.17 | 37.70 |
| Medium | All 102 | 26/100 | 26% | 9.80 | 37.09 |
| Hard | Starter 10 | 3/100 | 3% | 9.79 | 34.42 |
| Hard | 25 Jokers | 5/100 | 5% | 9.04 | 31.15 |
| Hard | All 102 | 14/100 | 14% | 8.93 | 31.70 |

## Interpretation

Easy is intentionally forgiving. Medium remains challenging, and its full-pool
95% win-rate interval overlaps the retained v8.4.1 reference. Hard is severe
but does not meet the predeclared "unplayable" rule of both under 3% wins and
under six average Heats.

The non-monotonic discovery rows are expected in a weighted shop game: a
larger discovered pool increases variety and can dilute a compact starter
engine. This is why v8.5 adds shop gating and weight controls instead of
changing scoring or secretly biasing the deck.

## Stake-contract correction

The original stake payout curve was skill-scaled: players who regularly reached
Heats 9-12 received much more favourable return than early players. A stake cap
only limits coin volume because payout is linear in stake; it cannot fix the
return rate.

v8.5 now uses the monotonic curve
`[0,20,35,45,55,70,82,92,100,105,110,115,150]` and payout multipliers
Easy `0.80`, Medium `0.92`, Hard `1.00`. The 200-coin cap remains unchanged.

The final confirmation ran 4,500 deterministic runs: 500 runs for each of
three representative player profiles on all three difficulties.

| Difficulty | Weak/new | Mid | Skilled/late |
|---|---:|---:|---:|
| Easy | 0.878 | 0.960 | 1.064 |
| Medium | 0.858 | 0.952 | 1.063 |
| Hard | 0.812 | 0.955 | 1.043 |

The old skilled/late EV was 1.411 on Medium and 1.852 on Hard in the same
4,500-run sample. The new table improves lower-Heat protection, flattens
near-miss returns, and preserves a 1.5x raw Heat-12 completion value.

No deck-order, draw-quality, scoring, target or RNG manipulation is permitted
as a stake-balancing tool.

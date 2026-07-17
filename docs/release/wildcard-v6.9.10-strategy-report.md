# WILDCARD v6.9.10 Strategy Lab

Generated from the canonical game source with paired deterministic run seeds.

## Provenance

- Source: `www/index.html`
- Source SHA-256: `116d1878b733667b2fdb87c28e9ed38b5f8010288894e11bbebe9cf9a4c81521`
- Simulator: `tools/deep-sim-v57.js`
- Simulator SHA-256: `11660571a5ad227b24ff2f205969dba7801df1d79156bdbb64d65078f72ceb09`
- Runs: 7 strategies × 400 paired seeds = 2,800 complete runs
- Seed base: 0x69100000; phase streams: modifier, deck-and-draw, shop

## Results

| Strategy | Runs | Clear Heat 12 | Wilson 95% CI | Reach Heat 9 | Reach Heat 11 | Avg Heats Cleared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adaptive greedy | 400 | 29.25% | 25.01%–33.89% | 90.5% | 68% | 10.17 |
| Cheat + hand synergy | 400 | 11.5% | 8.73%–15% | 78% | 48.5% | 9.14 |
| Pair and rank boosting | 400 | 8% | 5.72%–11.08% | 83.75% | 45.5% | 9.2 |
| Utility and niche | 400 | 20.5% | 16.83%–24.73% | 85.75% | 59.25% | 9.73 |
| Flush engine | 400 | 36.5% | 31.93%–41.33% | 96.5% | 85.5% | 10.87 |
| Economy hoarding | 400 | 20.5% | 16.83%–24.73% | 76.5% | 57.75% | 9.48 |
| xMult stacking | 400 | 2.5% | 1.36%–4.54% | 83.75% | 50% | 9.27 |

The observed leader is **Flush engine** at **36.5%**, but rankings should not be treated as conclusive when confidence intervals overlap. These are deterministic bot policies, not player telemetry.

## Strategy Definitions

- **Adaptive greedy:** Ranks every offer by broad immediate and scaling value without forcing an archetype.
- **Cheat + hand synergy:** Prioritises The Cheat, hand-specific multipliers, hand Boost scaling and flexible hand enablers.
- **Pair and rank boosting:** Prioritises rank modifiers and Pair-or-better support.
- **Utility and niche:** Prioritises unusual deck, hand-size and conditional utility effects.
- **Flush engine:** Prioritises suit, colour and Flush enablers and payoffs.
- **Economy hoarding:** Prioritises coin engines and keeps a 25-coin reserve instead of spending for tempo. It keeps a 25-coin reserve.
- **xMult stacking:** Prioritises Jokers with multiplicative scoring hooks, even when the flat base is weak.

## Validation

- Data/scoring failures: 0
- Hook errors: 0
- Run invariant failures: 0
- Raw seed-level outcomes are retained in the JSON for paired comparisons and independent review.

## Method Caveat

Each strategy receives the same run seed, with deterministic substreams reset for modifier, deck/draw and shop phases. Different decisions can still consume different amounts of randomness after a phase begins, so this is a paired, reproducible comparison rather than a claim that every downstream draw is identical.

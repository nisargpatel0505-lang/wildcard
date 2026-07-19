# WILDCARD v6.9.13 Strategy Lab

Generated from the canonical game source with paired deterministic run seeds.

## Provenance

- Source: `www/index.html`
- Source SHA-256: `499c1ebe75a5346e7fe3c06cf0b0328cc29e32e90d62a77b237071ffeaa2bab9`
- Simulator: `tools/deep-sim-v57.js`
- Simulator SHA-256: `2490034930b72b26d4a1d0c1735638e6b658dffc9309005d3971d919c3fbb4e1`
- Runs: 7 strategies × 1000 paired seeds = 7,000 complete runs
- Seed base: 0x69100000; phase streams: modifier, deck-and-draw, shop
- Fixed start mode: none

## Results

| Strategy | Runs | Clear Heat 12 | Wilson 95% CI | Reach Heat 9 | Reach Heat 11 | Avg Heats Cleared |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adaptive greedy | 1000 | 23.3% | 20.79%–26.02% | 84.4% | 63.1% | 9.8 |
| Cheat + hand synergy | 1000 | 16.1% | 13.95%–18.51% | 80.8% | 56.7% | 9.49 |
| Pair and rank boosting | 1000 | 9.2% | 7.56%–11.15% | 76.2% | 41.7% | 8.89 |
| Utility and niche | 1000 | 14.6% | 12.55%–16.92% | 77.7% | 50.5% | 9.22 |
| Flush engine | 1000 | 22.5% | 20.02%–25.19% | 83.9% | 65.4% | 9.81 |
| Economy hoarding | 1000 | 19.8% | 17.45%–22.38% | 66.3% | 48.4% | 8.82 |
| xMult stacking | 1000 | 1.8% | 1.14%–2.83% | 76.7% | 40.9% | 8.81 |

The observed leader is **Adaptive greedy** at **23.3%**, but rankings should not be treated as conclusive when confidence intervals overlap. These are deterministic bot policies, not player telemetry.

## Fun Proxies

| Strategy | Hand entropy | Dominant hand | Joker-active plays | Trigger events/play | Final-play clears | Meaningful shops | Dead shops | Build Jaccard distance |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adaptive greedy | 0.773 | Two Pair (30.85%) | 80.12% | 2.13 | 25.26% | 88.6% | 2.03% | 0.906 |
| Cheat + hand synergy | 0.776 | Two Pair (31.09%) | 77.81% | 1.99 | 24.56% | 88.19% | 2.09% | 0.893 |
| Pair and rank boosting | 0.76 | Two Pair (32.38%) | 82.41% | 3.05 | 25.9% | 87.99% | 2.24% | 0.853 |
| Utility and niche | 0.78 | Two Pair (29.96%) | 75.88% | 1.81 | 26.51% | 87.89% | 2.14% | 0.895 |
| Flush engine | 0.742 | Flush (33.02%) | 80.97% | 2.49 | 23.42% | 88.83% | 2.02% | 0.878 |
| Economy hoarding | 0.765 | Two Pair (30.26%) | 56.39% | 1.32 | 29.71% | 93.71% | 1.57% | 0.935 |
| xMult stacking | 0.774 | Two Pair (31.79%) | 70.78% | 1.59 | 25.68% | 87.13% | 2.26% | 0.899 |

Across paired seeds, 52.1% produced different win/loss outcomes across strategies; 47.9% were lost by every tested strategy.

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
The card-play selector still maximises immediate score for every strategy. Strategy differences primarily measure shop/build preferences and Pair/Flush discard priorities, not fully independent human play styles.

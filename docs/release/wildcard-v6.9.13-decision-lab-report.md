# WILDCARD v6.9.13 Opening and Starter Decision Lab

Generated from the canonical game source with paired deterministic seeds.

## Provenance

- Source: `www/index.html`
- Source SHA-256: `499c1ebe75a5346e7fe3c06cf0b0328cc29e32e90d62a77b237071ffeaa2bab9`
- Simulator: `tools/deep-sim-v57.js`
- Simulator SHA-256: `2490034930b72b26d4a1d0c1735638e6b658dffc9309005d3971d919c3fbb4e1`
- Opening deals: 50,000 paired deals across 12 configurations
- Full runs: 12 starter configurations × 1,000 paired seeds = 12,000

## Best Immediate Opening Play

| Start configuration | Deals | Mean best score | Median | P90 | Clears Heat 1 in one play | Most common best hand |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| No start boost | 50,000 | 100.14 | 73 | 196 | 41.02% | Two Pair (39.25%) |
| Copper Chip | 50,000 | 118.34 | 86 | 231 | 47.77% | Two Pair (39.25%) |
| Suit Presser | 50,000 | 102.85 | 77 | 199 | 41.23% | Two Pair (39.25%) |
| Royal Retainer | 50,000 | 103.4 | 78 | 197 | 41.88% | Two Pair (39.25%) |
| Even Odds | 50,000 | 103.72 | 76 | 200 | 41.59% | Two Pair (39.25%) |
| Low Ball | 50,000 | 103.97 | 76 | 204 | 41.89% | Two Pair (39.25%) |
| Suit Uniform | 50,000 | 112.25 | 76 | 227 | 43.39% | Two Pair (39.25%) |
| Triple Threat | 50,000 | 101.26 | 75 | 198 | 41.34% | Two Pair (39.25%) |
| Full Table | 50,000 | 136.73 | 99 | 267 | 64.83% | Two Pair (39.25%) |
| Pair Polisher | 50,000 | 140.03 | 102 | 274 | 67.15% | Two Pair (39.25%) |
| Opening Act | 50,000 | 145.6 | 106 | 285 | 74.12% | Two Pair (39.25%) |
| Guided first run: Copper Chip + Pair Polisher | 50,000 | 165.48 | 120 | 324 | 80.4% | Two Pair (39.25%) |

Immediate score is not the same as full-run value. These results enumerate the best legal useful play on the initial nine-card deal and do not assume a player should always play instead of discarding.

## Guided First-Run Hand Frontier

| Hand type | Available in initial deal | Mean best score when available | Median | P90 |
| --- | ---: | ---: | ---: | ---: |
| Royal Flush | 0.02% | 795 | 795 | 795 |
| Straight Flush | 0.17% | 622.04 | 621 | 637 |
| Four of a Kind | 0.61% | 435.89 | 435 | 457 |
| Full House | 12.01% | 336.88 | 337 | 357 |
| Flush | 13.29% | 263.34 | 264 | 275 |
| Straight | 16.9% | 226.26 | 226 | 249 |
| Three of a Kind | 17.48% | 154.23 | 153 | 169 |
| Two Pair | 62.05% | 110.3 | 109 | 126 |
| Pair | 94.9% | 58 | 58 | 69 |
| High Card | 100% | 17.3 | 18 | 18 |

## Starter Joker Full Runs

Every arm uses the same adaptive shop policy, the same paired run seeds and the real ten-Joker starter shop pool.

| Starter | Runs | Clear Heat 12 | Wilson 95% CI | Avg Heats cleared | Reach Heat 9 | Reach Heat 12 | Heat 12 hazard |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| No start boost | 1,000 | 1.4% | 0.84%–2.34% | 9.49 | 92.9% | 33.8% | 95.86% |
| Copper Chip | 1,000 | 1.1% | 0.62%–1.96% | 9.64 | 94.8% | 35.9% | 96.94% |
| Suit Presser | 1,000 | 1.4% | 0.84%–2.34% | 9.61 | 94.3% | 34.7% | 95.97% |
| Royal Retainer | 1,000 | 1.7% | 1.06%–2.71% | 9.58 | 93.6% | 34.8% | 95.11% |
| Even Odds | 1,000 | 1.3% | 0.76%–2.21% | 9.6 | 94.3% | 34.4% | 96.22% |
| Low Ball | 1,000 | 1.3% | 0.76%–2.21% | 9.59 | 94.1% | 33.5% | 96.12% |
| Suit Uniform | 1,000 | 1.3% | 0.76%–2.21% | 9.55 | 93.4% | 33.3% | 96.1% |
| Triple Threat | 1,000 | 1.3% | 0.76%–2.21% | 9.59 | 93.9% | 33.6% | 96.13% |
| Full Table | 1,000 | 1.5% | 0.91%–2.46% | 9.75 | 94.8% | 38.5% | 96.1% |
| Pair Polisher | 1,000 | 1% | 0.54%–1.83% | 9.72 | 96% | 36.5% | 97.26% |
| Opening Act | 1,000 | 1% | 0.54%–1.83% | 9.68 | 94.4% | 36.5% | 97.26% |
| Guided first run: Copper Chip + Pair Polisher | 1,000 | 1.3% | 0.76%–2.21% | 9.87 | 96.5% | 42.3% | 96.93% |

Observed leader: **Royal Retainer** at **1.7%**. Confidence intervals and paired outcomes must be considered before treating small gaps as real.

## Fun-Proxy Readout for the Observed Leader

- Hand diversity entropy: 0.732
- Dominant hand: Two Pair (36.85% of plays)
- Joker-active plays: 96.09%; trigger events per play: 4.34
- Final-play clears: 22.08%; close clears: 25.74%; comeback clears: 1.61%
- Meaningful shops: 99.72%; dead shops: 0.02%
- Mean final-build Jaccard distance: 0.153

## Validation and Limits

- Data/scoring failures: 0
- Hook errors: 0
- Run invariant failures: 0
- Starter account-coin costs are reported but not deducted from run coins.
- Simulation proxies cannot prove enjoyment. Closed testing still needs player pace, fairness and Joker-recall questions.

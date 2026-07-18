# WILDCARD v6.9.10 Economy Simulation

Deterministic 180-day progression model generated from the live `www/index.html` Joker catalogue and economy configuration.

## Live inputs

- Source SHA-256: `116d1878b733667b2fdb87c28e9ed38b5f8010288894e11bbebe9cf9a4c81521`
- Model script SHA-256: `43d40d7109d56429790ab89ede2e29cda4f3b51921a2a4ab5ceb54f580660345`
- Source UI version label: 6.9.10
- Gameplay depth input: `docs/release/wildcard-v6.9.10-sim-results.json` · SHA-256 `962eca3bd84ecd0f7ec562472433a7270e98933cd4a4c38de9e09e6ac4515fd0` (1500 all-unlocked runs; 700 starter-pool runs)
- Economy trials: 1,000 per cohort, route and scenario (12,000 total player timelines)
- Free / paid Jokers: 10 / 47

The two gameplay cohorts use the same bot. They bound collection strength, not human skill. Each simulated run blends those distributions by the percentage of paid Jokers already owned.

## Before and after

| Measure | v6.9.7 baseline | v6.9.10 current |
| --- | ---: | ---: |
| Direct paid-Joker catalogue | 4,700 | 10,875 |
| Vault completion, mean | 2,969.19 | 8,776.21 |
| Vault discount vs direct | 36.83% | 19.3% |
| Daily rewards, 7 days | 980 | 588 |
| Daily rewards, 30 days | 8,250 | 4,950 |
| Daily rewards, 180 days | 56,250 | 33,750 |

Proposed Vault-route distribution: p05 8,100, p50 8,900, p95 9,300 coins. It remains duplicate-free; variance comes from occasional Rare Jokers appearing in the Wooden Vault.

## Progression cohorts

| Scenario | Route | Cohort | 25% p50 day | 50% p50 day | 75% p50 day | 100% p50 day | Complete by day 180 | Paid owned p50 | Wallet p50 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline | direct | Casual | 6 | 20 | 40 | 69 | 100% | 47 | 7,598 |
| baseline | direct | Regular F2P | 3 | 7 | 13 | 21 | 100% | 47 | 39,531 |
| baseline | direct | Grinder F2P | 2 | 4 | 7 | 11 | 100% | 47 | 95,664 |
| baseline | vault | Casual | 4 | 11 | 26 | 43 | 100% | 47 | 9,314 |
| baseline | vault | Regular F2P | 2 | 4 | 9 | 14 | 100% | 47 | 41,276 |
| baseline | vault | Grinder F2P | 1 | 3 | 5 | 8 | 100% | 47 | 97,392 |
| proposed | direct | Casual | 17 | 55 | 119 | >180 | 1.8% | 43 | 288 |
| proposed | direct | Regular F2P | 6 | 16 | 32 | 60 | 100% | 47 | 22,212 |
| proposed | direct | Grinder F2P | 3 | 8 | 15 | 27 | 100% | 47 | 66,982 |
| proposed | vault | Casual | 22 | 48 | 110 | 180 | 51.1% | 47 | 260 |
| proposed | vault | Regular F2P | 7 | 14 | 30 | 48 | 100% | 47 | 24,478 |
| proposed | vault | Grinder F2P | 4 | 7 | 14 | 22 | 100% | 47 | 69,194 |

Assumptions: Casual = three runs/week, four expected login days/week, no ads; Regular = one run/day, six expected login days/week and two coin ads on active days; Grinder = three runs/day, daily login and five coin ads. Every profile starts with the real 200-coin tutorial gift and receives the real duplicate-free first-loss comeback Joker.

## Release gates

- PASS — Joker catalogue: 10 free / 47 paid
- PASS — Proposed direct sink band: 10,875 coins
- PASS — Proposed direct target: 10,875 / 10,875 coins
- PASS — Daily curve: 30 + 18/day, cap 192
- PASS — Daily totals: 588 / 4,950 / 33,750
- PASS — Vault prices: 100 Wooden / 300 Golden
- PASS — Vault discount: 19.3% mean discount
- PASS — Non-negative balances: minimum simulated wallet >= 0
- PASS — Trial count: 1,000 per cohort/route/scenario

## Interpretation limits

This is a deterministic scenario model, not retention or revenue telemetry. Ad usage and login frequency are explicit assumptions. The gameplay run-depth samples come from bots, so live Firebase cohorts should replace those assumptions once enough players exist.

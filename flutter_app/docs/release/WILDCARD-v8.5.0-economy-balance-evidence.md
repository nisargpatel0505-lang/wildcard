# WILDCARD v8.5.0 economy and balance evidence

## Release decision

This bounded audit supports keeping the current scoring, Joker effects, targets,
Vault prices, rewards, and RNG streams. It does support the shop-acquisition
guardrails implemented with this audit:

- WILD drought protection moved from 6 to 24 missed eligible shops. A standard
  12-Heat run has only six WILD-eligible natural shops, so it cannot force a
  WILD before victory.
- Seven measured high-impact non-WILD Jokers are unavailable before Heat 4,
  use half their normal same-rarity shelf weight, and share a one-per-shop cap
  with WILD Jokers.
- Arcade uses the same weighted, duplicate-free, max-one-premium draw helper.
  WILD remains blocked until Arcade Round 12 and Arcade has no pity counter.
- Guided tutorial shops and the deterministic comeback Vault cannot award a
  high-impact/WILD Joker. The comeback reward is Straight Wire.
- Restored legacy shelves are normalized through the same gates and cap, and
  restored WILD pity is clamped to 0..24.

The 280,000-shop stress run had zero discovery, duplicate, early-gate, or
premium-cap failures. The 900 strategic runs had zero engine invariant
failures.

Normal does not have evidence for a target change. Medium/full won 26/100 runs
(26.0%, 95% Wilson interval 18.4%-35.4%). The interval still overlaps the
retained v8.4.1 reference interval of approximately 32.6%-38.6%. Hard/full won
14/100 and averaged 8.93 Heats, so it did not meet the predeclared severe
friction rule of both under 3% wins and under 6 average Heats.

One economy finding needs product review: the 8,500-coin pack took the median
rational collector from 13 to 56 Jokers on Day 1, and every simulated account
crossed the predeclared "50 by Day 7" too-fast threshold. Packs do not choose a
Joker, alter scoring, change targets, change RNG, or directly buy a leaderboard
result. They do accelerate a gameplay-relevant collection, however, so the
current largest pack must not be described as strict zero-impact non-P2W.

## Authoritative rules

The audit imports the live Dart definitions and stops if these contracts drift:

- 102 public Jokers and the exact 10-Joker starter set;
- Wood Vault: 200 coins, 70% Common / 27% Uncommon / 3% Rare / 0% WILD;
- Gold Vault: 350 coins, 52% Uncommon / 44% Rare / 4% WILD;
- Cosmetic Vault: 1,000 coins;
- duplicate-protected Vault rewards and no permanent chosen-Joker purchase;
- five coin grants: 250 / 600 / 1,600 / 3,600 / 8,500;
- daily login 5 / 10 / 15 / 20 / 25+ and five visible Weekly Missions;
- 25 coins per optional rewarded view, capped at five views per day;
- WILD shop gate at Heat 6, 24-miss pity, and Arcade WILD gate at Round 12;
- high-impact gate at Heat 4, 0.5 weight, and the exact set:
  `rarity_hunter`, `flushfund`, `rule_breaker`, `danger_music`, `purist`,
  `survivor`, and `ensemble`.

After the starters and free Straight Wire comeback reward, the theoretical
minimum Joker-collection spend is 19,250 coins: 84 remaining non-WILD
discoveries at 200 coins, followed by seven WILD discoveries at 350 coins.

## Before/after economy

The raw JSON retains the v8.4 baseline commit
`b23642ce4e71abf81ec7bb3675759a10b43d5f13`.

| Rule | v8.4 baseline | v8.5 current | Delta |
|---|---:|---:|---:|
| Permanent chosen-Joker purchase | available | removed | Vault discovery only |
| Full direct-unlock catalogue sink | 17,030 | n/a | route removed |
| Efficient chest completion after comeback | 10,340 | 19,250 | +8,910 |
| Current sink versus old direct sink | 17,030 | 19,250 | +2,220 (+13.0%) |
| Wood / Gold Vault | 60-100 / 300 | 200 / 350 | fixed current prices |
| 180 uninterrupted login days | 33,750 | 4,450 | -29,300 |
| Expected reward for all visible weeklies | 700 across 3 | 225 across 5 | -475 |
| Sequential long-term coin pool | 0 | 520 | +520 one-time |

## Strategic run cohorts

Each cell used 100 complete deterministic Adaptive-bot runs. Progression pools
are the exact starter 10, a fixed Wood-shaped 25-Joker pool, and all 102 public
Jokers.

| Difficulty | Pool | Wins | Win rate (95% CI) | Avg Heats | Coins/run |
|---|---:|---:|---:|---:|---:|
| Easy | starter 10 | 66 | 66.0% (56.3%-74.5%) | 11.62 | 50.36 |
| Easy | discovered 25 | 59 | 59.0% (49.2%-68.1%) | 11.30 | 48.00 |
| Easy | full 102 | 55 | 55.0% (45.2%-64.4%) | 11.21 | 47.10 |
| Medium | starter 10 | 17 | 17.0% (10.9%-25.5%) | 10.77 | 40.72 |
| Medium | discovered 25 | 16 | 16.0% (10.1%-24.4%) | 10.17 | 37.70 |
| Medium | full 102 | 26 | 26.0% (18.4%-35.4%) | 9.80 | 37.09 |
| Hard | starter 10 | 3 | 3.0% (1.0%-8.5%) | 9.79 | 34.42 |
| Hard | discovered 25 | 5 | 5.0% (2.2%-11.2%) | 9.04 | 31.15 |
| Hard | full 102 | 14 | 14.0% (8.5%-22.1%) | 8.93 | 31.70 |

The wider pool is not monotonic power because it also exposes more niche shop
choices. These samples are decision bounds, not human-retention forecasts.

## Shop-generation stress

The audit generated 160,000 Normal shops and 120,000 Arcade shops.

| Cohort | Shops | Offers | Common | Uncommon | Rare | WILD | WILD shop | High-impact shop | Premium shop | Pity forced |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Starter, Heat 3 | 20,000 | 2 | 33,668 | 0 | 6,332 | 0 | 0% | 0% | 0% | 0% |
| Full, Heat 3 | 20,000 | 2 | 18,841 | 13,722 | 7,437 | 0 | 0% | 0% | 0% | 0% |
| Discovered 25, Heat 8 | 20,000 | 2 | 29,777 | 6,305 | 3,918 | 0 | 0% | 3.470% | 3.470% | 0% |
| Full, Heat 8 | 100,000 | 2 | 88,302 | 68,100 | 38,610 | 4,988 | 4.988% | 6.537% | 11.525% | 3.164% |
| Arcade full, Round 3 | 20,000 | 3 | 27,845 | 21,204 | 10,951 | 0 | 0% | 0% | 0% | n/a |
| Arcade full, Round 12 | 100,000 | 3 | 133,827 | 105,660 | 57,557 | 2,956 | 2.956% | 10.023% | 12.979% | n/a |

The full Normal Heat-8 row is a steady Endless-style sequence with pity state
carried across 100,000 shops. It is not a claim that one standard run has a
4.988% guarantee: standard play cannot reach the 24-miss force point.

## Collection strategy comparison

All rows use 1,000 comparable regular no-ad accounts, identical non-spending
random streams, the live Medium smart-run histograms, no Cosmetic diversion,
and 180 calendar days.

Median day to collection milestone:

| Strategy | 10% (11) | 25% (26) | 50% (51) | 75% (77) | 90% (92) | 100% (102) | Full by Day 180 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Wood only | 1 | 19 | 66 | 116 | 145 | impossible | 0% |
| Gold only | 1 | 40 | 122 | impossible | impossible | impossible | 0% |
| Rational mixed | 1 | 19 | 66 | 116 | 145 | 172 | 90.0% |

Wood-only structurally stops at 95 Jokers because Wood has zero WILD odds.
Gold-only cannot discover the 28 locked Common Jokers and therefore stops below
75%. Rational mixed buys Wood until all non-WILD Jokers are owned, then Gold.

Rarity acquisition timing:

| Strategy | Rarity | Total / starter-owned | First Vault median day | Full-rarity median day | Full rarity by Day 180 |
|---|---|---:|---:|---:|---:|
| Wood only | Common | 36 / 8 | 1 | 66 | 100% |
| Wood only | Uncommon | 36 / 0 | 1 | 113 | 100% |
| Wood only | Rare | 23 / 2 | 35 | 151 | 100% |
| Wood only | WILD | 7 / 0 | never | never | 0% |
| Gold only | Common | 36 / 8 | never | never | 0% |
| Gold only | Uncommon | 36 / 0 | 1 | 176 | 39.4% |
| Gold only | Rare | 23 / 2 | 1 | 143 | 90.8% |
| Gold only | WILD | 7 / 0 | 44 | 159 | 0.7% |
| Rational mixed | Common | 36 / 8 | 1 | 66 | 100% |
| Rational mixed | Uncommon | 36 / 0 | 1 | 113 | 100% |
| Rational mixed | Rare | 23 / 2 | 35 | 151 | 100% |
| Rational mixed | WILD | 7 / 0 | 154 | 172 | 90.0% |

### Specific WILD: Heat Surge

The exact uncensored Gold-only Markov expectation is 50.506 Gold Vaults, or
17,677.07 coins, from the post-comeback starting pool. This uses the live
depleted-tier fallback probabilities. The 180-day Gold-only cohort acquired
Heat Surge in 37.9% of paths; among acquired paths, the median was Day 84 and
29 Gold Vaults. Those conditional values are not substituted for the
uncensored expectation.

Rational mixed first removes all 84 non-WILD locks. With seven WILDs left, the
specific target's expected position is exactly the fourth Gold Vault. Expected
total is therefore 88 Joker Vaults and 18,200 coins. In the calendar cohort,
98.7% had Heat Surge by Day 180; median acquisition was Day 162, with a sampled
mean of 3.81 Gold Vaults after the non-WILD phase. Wood-only can never acquire
it.

## Current coin-pack comparison

These six paths use the same rational-mixed profile and identical non-spending
random streams. The only difference is one Day-1 currency grant.

Median Jokers discovered at every requested horizon:

| Path | Day 1 | Day 3 | Day 7 | Day 14 | Day 30 | Day 90 | Day 180 | Full-collection median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| No pack | 13 | 15 | 18 | 23 | 32 | 63 | 102 | Day 172 |
| 250 | 15 | 17 | 20 | 24 | 33 | 64 | 102 | Day 170 |
| 600 | 16 | 18 | 21 | 26 | 35 | 66 | 102 | Day 168 |
| 1,600 | 22 | 24 | 27 | 32 | 40 | 71 | 102 | Day 156 |
| 3,600 | 32 | 34 | 37 | 42 | 50 | 81 | 102 | Day 137 |
| 8,500 | 56 | 59 | 62 | 66 | 75 | 101 | 102 | Day 91 |

Median days saved versus no pack:

| Pack | 25% | 50% | 75% | 90% | 100% |
|---|---:|---:|---:|---:|---:|
| 250 | 2 | 3 | 3 | 2 | 2 |
| 600 | 5 | 5 | 5 | 5 | 4 |
| 1,600 | 12 | 16 | 16 | 16 | 16 |
| 3,600 | 18 | 35 | 35 | 35 | 35 |
| 8,500 | 18 | 65 | 81 | 82 | 81 |

At Day 1, the packs added a median +2, +3, +9, +19, and +43 Jokers
respectively. At Day 30 the deltas were +1, +3, +8, +18, and +43. Every path
converged to the full collection by the Day-180 median, so late-horizon equality
does not erase the early access difference.

The 250, 600, 1,600, and 3,600 paths stayed below the severe too-fast guard.
The 8,500 path triggered it in 100% of accounts and should be reviewed before a
public-money launch.

## Human activity archetypes

Each row summarizes 1,000 accounts with live rewards and balanced Vault
spending.

| Archetype | Day 7 Jokers | Day 30 | Day 90 | Day 180 | Day-180 cosmetics | Full Joker median |
|---|---:|---:|---:|---:|---:|---:|
| Casual, no ads | 15 | 21 | 34 | 53 | 3 | not reached |
| Regular, no ads | 18 | 26 | 45 | 68 | 10 | not reached |
| Regular, one optional ad/day | 19 | 29 | 50 | 82 | 11 | not reached |
| Engaged, three optional ads/day | 22 | 37 | 74 | 102 | 31 | Day 134 |

No human archetype crossed the severe too-fast or sustained-insolvency
threshold. No account spent coins on a permanent chosen-Joker purchase, and no
simulated archetype completed all 48 optional cosmetics by Day 180.

## Reproduction and evidence

From `flutter_app/`:

```text
dart run tool/v85_economy_balance_audit.dart --smart-runs=100 --economy-accounts=1000 --shop-rolls=100000 --output=build/simulation/v85_economy_balance --durable-output=docs/release/WILDCARD-v8.5.0-economy-balance-results.json
flutter test test/domain/v85_economy_balance_audit_test.dart test/domain/v85_joker_acquisition_test.dart test/game/game_controller_test.dart test/game/arcade_controller_test.dart
flutter analyze lib/domain/economy.dart lib/domain/joker_catalog.dart lib/domain/simulation.dart lib/game/game_controller.dart lib/game/arcade_controller.dart tool/v85_economy_balance_audit.dart
```

The full run took 374.479 seconds and covered 900 strategic runs, 280,000 shop
generations, and 13,000 account paths (13 cohorts x 1,000 accounts).
The final acquisition/controller set contains 52 focused passing tests
(24 game controller, 21 acquisition, 5 Arcade, and 2 harness tests), and focused
analysis of the seven changed source/tool files reports no issues.

Evidence:

- `tool/v85_economy_balance_audit.dart`
- `test/domain/v85_economy_balance_audit_test.dart`
- `test/domain/v85_joker_acquisition_test.dart`
- `test/game/game_controller_test.dart`
- `test/game/arcade_controller_test.dart`
- `docs/release/WILDCARD-v8.5.0-economy-balance-results.json`

The durable JSON contains exact seeds, fixed discovery IDs, every horizon,
income-source medians, strategy limits, pack comparisons, rarity timing,
specific-WILD expectations, Wilson intervals, and verdicts.

Durable JSON SHA-256:
`9b997cf0aa548657989c8539cf58669a88ddd3bacbcea756963c3fb5414bf9bf`
(154,093 bytes).

## Limitations

- The Adaptive bot is strategic but not a human skill distribution.
- One hundred runs per strategic cell gives useful bounds, not a final live
  balance estimate. Re-run 500-1,000 per decision-critical cell after beta.
- Weekly completion is archetype-based and does not model mission preference.
- Legacy achievement income is conservative and excludes rare hand conditions.
- Stake contracts, Daily Board prizes, revenue, refunds, regional prices, and
  forced-ad income are excluded.
- Pack modelling measures granted currency and collection acceleration only.
- Recheck onboarding and pack conversion against opt-in beta telemetry after at
  least 14 days.
- The installed phone build that existed before this correction does not contain
  the 24-pity/high-impact/resume normalization changes.

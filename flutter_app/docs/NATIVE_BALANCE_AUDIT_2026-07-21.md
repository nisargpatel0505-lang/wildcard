# WILDCARD native Flutter balance audit — 21 July 2026

## Verdict

The native Dart rules completed **11,100 deterministic full runs** with **zero
invariant failures**. The run matrix exercised Normal, Daily, Gauntlet and
Endless, every difficulty, all ten public starter Jokers, the guided first-run
pair, three build-aware policies, shops, row upgrades, supplies, modifiers and
THE HOUSE.

This is deterministic bot evidence, not a claim about human win rate or fun.
No gameplay balance, scoring rule, Joker rule or animation pace was changed as
a result of this audit.

## Coverage

- 11,100 complete run attempts
- 243,654 scored hands
- 96,451 shops visited
- 55,385 Joker purchases or upgrades
- 49,627 supply purchases
- 34,959 modifier slots faced
- 3,321 boss heats faced
- 797,671 visible Joker trigger events
- 0 score, deck, economy, copy-cap, Joker-cap or mode invariant failures

## Strategy matrix

All policies used the same paired seed range, the guided Copper Chip + Pair
Polisher start, the complete unlocked catalogue and Medium difficulty.

| Policy | Runs | Heat-12 clears | Wilson 95% CI | Avg Heats | Dominant hand |
| --- | ---: | ---: | ---: | ---: | --- |
| Adaptive | 1,000 | 21.9% | 19.45–24.57% | 9.95 | Full House (28.7%) |
| Flush builder | 1,000 | 16.5% | 14.33–18.93% | 9.52 | Flush (41.2%) |
| Pair builder | 1,000 | 12.2% | 10.31–14.37% | 9.60 | Full House (31.8%) |
| Immediate-score ranking | 1,000 | 5.0% | — | 7.38 | Two Pair (33.2%) |
| Random legal tapping | 500 | 0% | — | 0.65 | High Card (79.7%) |

The adaptive policy produced a broad hand mix: Full House 28.7%, Flush 26.3%,
Straight 20.9%, Two Pair 16.3%. Its normalized hand entropy was 0.710, 98.8%
of hands produced at least one Joker event, it averaged 2.60 trigger events per
hand, and its 1,000 runs ended in 988 distinct final builds. Pair and Flush
policies also shifted their dominant hand in the intended direction. These are
useful agency/variety proxies, but closed-test feedback is still required.

## Difficulty and modes

| Cohort | Runs | Completion | Avg Heats | Completion-boss clear rate |
| --- | ---: | ---: | ---: | ---: |
| Normal Easy | 250 | 39.6% | 10.80 | 54.70% |
| Normal Medium | 250 | 18.4% | 9.86 | 41.07% |
| Normal Hard | 250 | 9.6% | 8.87 | 32.88% |
| Daily (Medium locked) | 250 | 17.6% | 8.79 | 56.41% |
| Gauntlet | 300 | 39.33% | 7.02 / 8 | 51.08% |
| New-player starter pool | 300 | 1.33% | 9.20 | 7.27% |
| Strong-build Endless to Heat 20 | 200 | 7.5% cleared Heat 20 | 12.82 | 61.31% cleared Heat 12 |

The difficulty curve separates cleanly. Gauntlet has modifiers on every Heat
but is only eight Heats long, so its higher completion rate is not directly
comparable to a 12-Heat Normal run. The Endless stress build reached Heat 20 in
17/200 runs and cleared it in 15/200, proving post-victory modifiers, rising
targets, shops and supplies execute without corrupting state.

## Starter finding

Across 400 paired starter-pool runs per arm, Triple Threat had the highest raw
completion rate (2.25%). Opening Act had the best single-starter average depth
(9.20 Heats), while the guided Copper Chip + Pair Polisher pair reached 9.26.
The confidence intervals overlap heavily, so there is no statistically secure
starter winner from this sample.

The important result is the new-player boss cliff. The starter-only cohort
cleared THE HOUSE in 4/55 attempts (7.27%). The guided first-run pair cleared it
in 3/87 attempts (3.45%). The all-unlocked Medium cohort cleared it in 46/112
attempts (41.07%). This may be intended metaprogression, or it may be a
retention risk; it should be decided using closed-test player evidence rather
than another blind balance edit.

## Focused THE HOUSE sensitivity — 12,000 additional runs

A second paired matrix isolated the two user-proposed block counts and small
boss-target-only changes. Each arm used 1,000 identical seeds. `2 / 1.10` is
the shipped rule: two random equipped Jokers are blocked and THE HOUSE adds
10% to the normal Heat-12 target. These knobs exist only in the simulator; the
production controller and rules were not changed.

### New-player starter-only catalogue

All arms reached THE HOUSE on the same 214/1,000 seeds, so the conditional
comparison is paired cleanly.

| Blocked | Boss target | Whole-run clear | Wilson 95% CI | Boss clear | Boss-clear 95% CI |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 1.10 (2,255) | 1.0% | 0.54–1.83% | 4.67% (10/214) | 2.56–8.39% |
| 2 | 1.05 (2,153) | 1.3% | 0.76–2.21% | 6.07% (13/214) | 3.58–10.11% |
| 2 | 1.00 (2,050) | 1.8% | 1.14–2.83% | 8.41% (18/214) | 5.39–12.90% |
| 3 | 1.10 (2,255) | 0.6% | 0.28–1.30% | 2.80% (6/214) | 1.29–5.98% |
| 3 | 1.05 (2,153) | 0.6% | 0.28–1.30% | 2.80% (6/214) | 1.29–5.98% |
| 3 | 1.00 (2,050) | 0.7% | 0.34–1.44% | 3.27% (7/214) | 1.59–6.60% |

### All-unlocked adaptive catalogue

All arms reached THE HOUSE on the same 492/1,000 seeds.

| Blocked | Boss target | Whole-run clear | Wilson 95% CI | Boss clear | Boss-clear 95% CI |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 1.10 (2,255) | 21.7% | 19.26–24.36% | 44.11% (217/492) | 39.78–48.52% |
| 2 | 1.05 (2,153) | 23.7% | 21.17–26.43% | 48.17% (237/492) | 43.79–52.58% |
| 2 | 1.00 (2,050) | 25.8% | 23.18–28.60% | 52.44% (258/492) | 48.02–56.82% |
| 3 | 1.10 (2,255) | 11.9% | 10.04–14.05% | 24.19% (119/492) | 20.61–28.16% |
| 3 | 1.05 (2,153) | 12.7% | 10.78–14.91% | 25.81% (127/492) | 22.14–29.86% |
| 3 | 1.00 (2,050) | 14.3% | 12.27–16.61% | 29.07% (143/492) | 25.23–33.23% |

### Decision

**Keep two random blocked Jokers for the definitive build.** Moving from two
to three is not “a little easier”: at the current target it nearly halves the
all-unlocked completion rate (21.7% to 11.9%) and reduces the new-player rate
from 1.0% to 0.6%. The user's “two or three, whichever balances better” request
is therefore already satisfied by the current two-block implementation.

No production target change is justified before human closed testing. If
player evidence confirms that THE HOUSE still feels unfair, the smallest
tested follow-up is to keep two blocks and lower only its target multiplier
from 1.10 to 1.05. That moves the target from 2,255 to 2,153, raising the broad
conditional boss clear rate by 4.06 percentage points and whole-run completion
by 2 points, while remaining difficult. Its new-player increase is only 1.40
conditional points / 0.3 whole-run points and the intervals overlap, so it is
not a substitute for improving starter-build understanding or collecting
player evidence.

Target sensitivity is exact for the starter-only pool. In the all-unlocked
pool it is slightly conservative for runs holding Redline: the simulation
clear threshold uses the test target, while Redline's internal 55% activation
check intentionally remains bound to the unchanged production target. This
does not affect the exact two-versus-three block comparison.

Focused evidence:

- `build/simulation/deep_balance_boss-new.json` — SHA-256 `a261df79b72e27f7f5432e8e5f64bdaf846f9a621ad179cc7fec3aa815fe3459`
- `build/simulation/deep_balance_boss-all.json` — SHA-256 `dac3431be646a340d779d2f65dd48689bc69f4401419099837e4c4c986a3bc27`
- 12,000 runs, 0 invariant failures

## Harness corrections and reproducibility

The previous native harness could not support this conclusion because it
stopped buying once the five-Joker row was full and always banked at Heat 12,
even when configured for a higher `maxHeat`. The audit harness now models
selling/upgrading the weakest row slot, records supply and trigger coverage,
adds Adaptive/Pair/Flush policies, and uses an explicit `continueEndless` flag.
These are simulation-only changes.

Run the matrix from `flutter_app` with:

```powershell
dart run tool/deep_balance_audit.dart --section=strategies
dart run tool/deep_balance_audit.dart --section=starters
dart run tool/deep_balance_audit.dart --section=modes
```

Generated evidence:

- `build/simulation/deep_balance_strategies.json` — SHA-256 `928d435a79859f2f4dbd2a3d77599a45cde3912b82b0140bc6c7845324fecd5d`
- `build/simulation/deep_balance_starters.json` — SHA-256 `e6e752502e9adfa93031ad959ca2b2db54a220c96c210ec4ac3cda4734bc242e`
- `build/simulation/deep_balance_modes.json` — SHA-256 `25184cc5ac6d226d9f8372196a5d9f3c73446e77baee6bbfd32edcfedcdae2df`

The SHA values include generation timestamps and elapsed-time metadata; cohort
outcomes themselves are seed-deterministic. The focused simulation test suite
contains six tests and passes in full, including byte-identical seed replay,
2,000 invariant runs, Daily difficulty locking, Gauntlet shop/supply coverage,
and explicit post-Heat-12 Endless execution.

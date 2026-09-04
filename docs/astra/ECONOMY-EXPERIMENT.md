# Astra 6 economy and opening run loop

Baseline: Play release **8.5.3+72**, commit `33fa0ab`. Changes are enabled only
with `WILDCARD_ASTRA_BUILD=true`; they are for the separate phone experiment.

## What changed and why

- Every Normal run can borrow **one** free Joker: Pair Polisher, Flush Fund or
  Straight Wire. This introduces a build decision before the first deal. A
  borrowed Joker does not become a permanent discovery. Draft choices do not
  consume deck, shop, modifier or scoring randomness.
- The first three cleared Heats pay **three extra run coins** each. The first
  shop therefore has at least six coins available even after a slow clear.
  Run coins expire with the run; starting/abandoning grants no account income.
- Those three shops offer **three Jokers**, with **one free reroll each**. The
  existing one-Joker purchase limit remains. The free-reroll marker is saved
  with the resulting shelf and restored on restart. Boss-preparation shops
  retain their existing four offers/two purchases.
- Cleared Normal Heats pay **8 account coins**, or **10** at each third-Heat
  checkpoint: **26 through Heat 3**, **104 through Heat 12**, plus the existing
  10-coin win bonus. Account awards keep the existing durable claim IDs.
- Wood Vault is **60** coins until 15 Jokers are discovered, then **100**.
  Gold Vault is **300**. All existing duplicate protection and disclosed live
  rarity odds remain unchanged.
- The experiment disables Sly's Stake entry. Earned run progression is the
  economy being tested, without optional wagering dominating the result.
- Daily and Gauntlet retain their original run rewards, shops and scoring;
  the experimental free draft and early-shop grants apply only to Normal.

No hand evaluation, Joker effects, heat targets, hand budgets, or random deck
distribution changed. First-run guidance, account journey rewards and UI are
integrated separately and are not counted in this simulation.

## Focused verification

`flutter test --no-pub --concurrency=1 --dart-define=WILDCARD_ASTRA_BUILD=true test/game/astra_progression_test.dart`

**4 tests passed:** free borrowed draft and unchanged deal/RNG; free-reroll
save/resume and per-shop renewal; Daily isolation; fixed reward/pricing bounds.

`dart run tool/astra_economy_compare.dart --runs=30 --out=build/astra-economy.json`

**300 simulated runs, 61.672 seconds, zero engine-invariant failures.** Each
baseline/candidate pair uses the same 30 seeds and the real Dart scorer.
Three starter routes rotate evenly over the candidate seeds. Earlier three-
and six-seed smoke runs also completed without invariant failures.

| Policy and collection | Difficulty | Mean cleared Heats baseline → Astra | Wins baseline → Astra | Mean earned account coins baseline → Astra |
|---|---|---:|---:|---:|
| Basic poker ranking, 10 starters | Medium | 5.30 → 7.53 | 0/30 → 0/30 | 14.73 → 64.53 |
| Basic poker ranking, full collection | Medium | 5.43 → 6.90 | 0/30 → 1/30 | 15.50 → 59.33 |
| Adaptive strategy, 10 starters | Medium | 10.37 → 11.10 | 3/30 → 11/30 | 37.97 → 99.07 |
| Adaptive strategy, full collection | Medium | 7.83 → 9.87 | 3/30 → 6/30 | 26.40 → 86.80 |
| Adaptive strategy, full collection | Hard | 5.57 → 9.43 | 1/30 → 8/30 | 16.33 → 83.93 |

For the basic-ranking, starter-collection cohort, the first shop averaged
**1 affordable Joker option before, 2.77 after**. This means a choice between
offers, not buying all three: both live engine and harness enforce one purchase
at ordinary shops. At its measured mean income, a Wood Vault changes from about
13.57 runs at 200 coins to 0.93 runs at the temporary 60-coin newcomer price.
After discovery 15, the 100-coin standard price applies: about 1.55 runs using
that same simple-policy mean income. These estimates exclude
the tutorial, login, missions, journey rewards, ads, purchases and stakes.

## What the numbers do not prove

Thirty seeds per cell are a **directional sample**, not a precise win-rate
estimate or proof of human retention. Basic poker-ranking is not a measured
beginner cohort; adaptive is a planning policy, not a perfect player. Full
collection still creates shop-synergy dilution relative to the concentrated
starter pool. That deserves human testing before adding more content.

The basic full-collection cohort used one free reroll; the other candidate
cohorts found an affordable useful opening shelf. Reroll correctness is covered
by the live-controller restart test; its enjoyment/value still needs playtesting.
Hard happened to produce 8 wins versus Medium's 6 for the full adaptive cohort,
but cleared fewer Heats on average. Different decisions lead to different later
shops/deals. This small difference is not evidence that Hard is easier, and its
target multiplier was not changed. No economy has a mathematically provable
ideal percentage for fun.

## Progression pace sanity check

The existing 200-coin tutorial gift can buy three 60-coin Wood Vaults immediately.
After starting with 10 tutorial Jokers, only the next five discoveries receive
the discount. It is an intentional small burst of opening variety, not an
unbounded grant. Newly added journey rewards are one-time claims, whereas earned
Normal-run income continues after those claims are exhausted.

At the basic policy's measured 64.53 coins/run, standard Wood costs roughly
1.55 runs and Gold costs 4.65 runs. At the experienced full adaptive policy's
86.80 coins/run, a 1,000-coin cosmetic takes about 11.52 runs from run rewards
alone. A full collection cannot discover more Jokers; cosmetic goals and mastery
therefore matter more for that cohort. Long Endless clears stay bounded at
8/10 coins per Heat instead of an ever-rising reward curve. Stakes cannot dwarf
that pacing in Astra because the entry is disabled.

Raw per-seed results: `astra-economy.json` beside this report. All reported
income is awarded only for completed Heats and wins. The isolated experiment
does not change the Google Play release.

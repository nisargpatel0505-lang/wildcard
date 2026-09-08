# WILDCARD v9.1.0 economy implementation and confirmation

The official promotion implements the recommended Astra earned-progression schedule. **3,000 fresh-seed actual Dart engine runs across eight cohorts passed, with zero engine invariant failures, scorer-fidelity failures, or reward-formula mismatches.** A separate 40-run native pilot is archived but excluded from the results below. The prior 7,550-run study remains preserved.

## Implemented rules

- Normal: 4 coins per cleared Heat 1–3, 7 for 4–6, 10 for 7–9, 13 for 10–12; +20 once at Heat 12. Full clear **122 coins** on every difficulty.
- Gauntlet: the first eight Heat rewards plus +10 once at completion. Full clear **63 coins**. The free Normal starter/early shop rules do not affect Gauntlet.
- Endless: +13 per clear after Heat 12; no additional repeated completion bonus. The earlier study's indefinite +3-per-three-Heat extrapolation is intentionally capped, preventing quadratic total currency growth. A clear through Heat 24 pays 278; a clear through Heat 100 pays 1,266. This is a reward cap per Heat, not a gameplay Heat limit.
- Daily: zero direct repeatable run coins; existing Daily achievements and weekly missions remain. Board-prize proposals are not activated.
- Normal keeps the free three-route starter choice, +3 run coins on each of the first three clears, three early Joker offers, and one free reroll in each of those shops. Run coins cannot be exported into the account wallet.
- Wood Vault: 60 while owning fewer than 15 public Jokers, then 100; Gold 300. Duplicate protection and disclosed dynamic rarity odds are unchanged.
- New stake wagers are disabled. A legacy saved run retains its already-paid stake and original settlement terms.
- The optional run-end ad grants the lesser of earned account coins and 25. Coin-reward ad placements share the five-per-day allowance: **at most 125 ad coins/day**, not five whole-run doubles. This is a separate sensitivity, excluded from engine earnings below.
- Journey contributes **780 one-time coins**, guarded by its persistent claim ledger. Tutorial, achievements, missions, daily login, ads, purchases, and cosmetic spending are outside repeatable direct-run means.

## Fresh-seed confirmation

| Cohort | Runs | Win rate (95% interval) | Mean coins (95% interval) | Median coins |
| --- | ---: | ---: | ---: | ---: |
| endless/medium/adaptive/full | 250 | 20.4% (15.9%–25.8%) | 89.1 (83.4–95.4) | 89 |
| gauntlet/medium/adaptive/full | 250 | 10.4% (7.2%–14.8%) | 31.8 (30.0–33.6) | 33 |
| normal/easy/adaptive/full | 250 | 59.2% (53.0%–65.1%) | 103.5 (100.3–106.4) | 122 |
| normal/hard/adaptive/full | 250 | 8.4% (5.6%–12.5%) | 62.9 (59.5–66.5) | 53 |
| normal/medium/adaptive/full | 500 | 22.8% (19.3%–26.7%) | 81.2 (78.8–83.8) | 89 |
| normal/medium/adaptive/new | 500 | 20.6% (17.3%–24.4%) | 90.2 (88.4–92.0) | 89 |
| normal/medium/handRanking/full | 500 | 4.8% (3.2%–7.0%) | 58.8 (56.5–61.2) | 53 |
| normal/medium/handRanking/new | 500 | 0.0% (0.0%–0.8%) | 50.7 (49.3–52.1) | 53 |

Normal wins mean reaching Heat 12; Gauntlet wins mean eight clears. Endless “win” still means reaching Heat 12, not beating Endless. Its measurement stops at Heat 24 and records survivors as censored. New/full means ten starter discoveries versus the full public catalogue. `handRanking` and `adaptive` are bot policies, not measured novice/expert people.

Win-rate intervals use Wilson 95% intervals. Mean-coin intervals use 2,000 deterministic bootstrap resamples of whole runs per cohort. These describe seed uncertainty for a fixed bot/pool, not uncertainty about real player behavior. The candidate was selected in the earlier study; these fresh seeds did not retune it.

## Early exit, affordability and purchasing

The largest fixed-stop rate ratio across these Normal cohorts and three modeled timing scenarios is **1.069×**, at Heat 6 for `normal/medium/handRanking/new/astra` under `typicalNormal`. Attempts that fail before the planned stopping point remain included. This is a diagnostic from assumed decision/shop timing; it is not measured phone playtime or proof that humans prefer farming.

A 100-coin Wood Vault is reachable from a good Normal run. We deliberately retain the shorter 60-coin introduction and the finite Journey rewards for people who struggle early. Easy and Hard use the same payouts; easier wins can yield a higher modeled earning rate. This is visible difficulty choice, with fair unchanged card RNG.

The prior pack ladder (300/£0.99, 600/£1.79, 1,500/£3.99) remains a research hypothesis. This promotion does not rename existing products, alter backend purchase grants, or replace localized Play prices. Current paid quantities and completed/pending purchase entitlements are preserved. Bots cannot establish willingness to pay or retention.

## Save and release evidence

Focused controller tests verify full Normal payouts at all difficulties, a resumed victory entering Endless with one completion credit, Gauntlet terminal payment, Daily zero direct payout, persisted free rerolls, and legacy stake settlement. Each Heat and completion retains its existing run-specific idempotency claim. The app-level official upgrade tests cover save backup and cloud/Journey behavior separately.

All fingerprinted simulation source hashes were identical between the four batch starts and completions. Raw per-seed outcomes, Heat checkpoints, seeds, summaries, the domain/game source snapshot and the prior study raw outputs are in `WILDCARD-v9.1.0-economy-raw-data.zip` beside the project folder. SHA-256 manifests accompany the report. No simulation process needs to remain running after this report.

Reproduce: compile `flutter_app/tool/astra_mode_economy_study.dart`; use 500 runs/cell for Medium Normal × (handRanking,adaptive) × (new,full), 250 each for adaptive/full Easy Normal, Hard Normal, Gauntlet Medium, and Endless Medium (cap24), all with `--seed-offset=20000`; then run this analysis script. Archive contains the exact batch metadata and source hashes.

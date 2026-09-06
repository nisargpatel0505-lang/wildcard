# WILDCARD coin economy study

## Executive summary

This is an Astra-only economy study. It does not change the game, phone APK, Google Play, Firebase, AdMob, billing or any production catalogue.

The completed batch contains **7,550 deterministic runs across 35 cells**: Normal at three difficulties, Daily, Gauntlet, Endless, baseline Play rewards and two specialist policies. The corrected native simulator reported **zero invariant failures and zero scorer-fidelity failures**. The simulator now mirrors the phone's hand order, deck normalization and supply lifecycle, and it no longer inserts an extra shop between Heat 12 and Heat 13 in Endless.

The clearest candidate is a transparent earned-reward lookup:

| Cleared Heat | Coins for that clear | Cumulative coins before completion bonus |
| ---: | ---: | ---: |
| 1–3 | 4 each | 12 after Heat 3 |
| 4–6 | 7 each | 33 after Heat 6 |
| 7–9 | 10 each | 63 after Heat 9 |
| 10–12 | 13 each | 102 after Heat 12 |
| Heat-12 completion | **+20 once** | **122 total** |

This candidate was the best grid result on the even-seed calibration and remained within the intended range on the odd-seed holdout. In the primary adaptive/full calibration cohort its largest fixed-stop reward-rate ratio was 0.91× the full-run rate. Across exploratory policies the largest observed ratio was 1.17× (the new-player pair-builder probe at Heat 6), so that cohort needs a human review before any live payout change.

## Recommended mode rules

### Normal

Use the same clear table on Easy, Medium and Hard. Do not add a hidden difficulty payout multiplier: Easy already produces more coins per modeled minute because the bot clears more quickly, while Hard is a challenge choice rather than an economy bonus.

### Gauntlet

Use the first eight rows of the Normal table, then add **10 coins once for a full eight-Heat clear**. A full clear is therefore 53 + 10 = **63 coins**. In the 150-run full-catalogue probe, this produced a mean of 33.52 coins per attempt, with median 26 and P90 63 under the candidate schedule. That is intentionally below a full Normal run because Gauntlet is shorter.

### Endless

Use the same table through Heat 12 and continue the per-Heat table afterwards. Pay the +20 Heat-12 completion bonus only once; do not add a repeated end-of-run multiplier. The Endless simulation was capped at Heat 24 for measurement, not as a product limit.

### Daily Challenge

Keep repeatable direct coins at **0 for now**. The Daily probe has an 8.7% full-run win rate for the full catalogue and currently gives its value through a shared deck/leaderboard, the one-time Daily Debut reward and weekly missions. If a coin reward is desired later, **15 coins for one verified 12-Heat win per day** is a reasonable human-test hypothesis, but it must wait for authenticated score attestation and an idempotent reward ledger. Do not activate planned 300/200 board prizes from these simulations.

## What the runs say about affordability

The fixed-cohort savings paths use 2,000 independent empirical reward paths per row. They carry a wallet forward and exclude tutorial/Journey gifts, ads, purchases and spending, so they describe repeatable earnings rather than a complete career.

| Cohort and schedule | 100-coin Wood Vault: median runs (P10–P90) | 300-coin Gold Vault: median runs (P10–P90) |
| --- | ---: | ---: |
| Normal Easy, recommended | 1 (1–2) | 3 (3–3) |
| Normal Medium, new probe, recommended | 2 (1–2) | 4 (3–4) |
| Normal Medium, full catalogue, recommended | 2 (1–2) | 4 (3–5) |
| Normal Hard, full catalogue, recommended | 2 (1–3) | 5 (4–6) |
| Gauntlet, full catalogue, recommended | 4 (3–5) | 9 (8–11) |
| Normal Medium, current Play baseline | 4 (3–6) | 12 (10–14) |

These numbers show why the Astra candidate needs to be tested with real players: a strategy bot can make a Vault look much closer than a new human will experience, and the standard 100-coin Wood price can be reached from one unusually strong run.

## Coin-pack hypothesis (not enabled)

The small ladder retained for a future localized Play experiment is:

| Pack | Coins | UK customer-price hypothesis | Standard Vault equivalents |
| --- | ---: | ---: | ---: |
| Small | 300 | £0.99 | 3 Wood or 1 Gold |
| Medium | 600 | £1.79 | 6 Wood or 2 Gold |
| Large | 1,500 | £3.99 | 15 Wood or 5 Gold |

The quantities divide cleanly into the 100-coin standard Wood and 300-coin Gold Vaults. These are **not** a simulated revenue optimum or a claim about willingness to pay. Do not hardcode the GBP values in Flutter: real Play offer metadata supplies the localized buyer price, and any release must preserve existing product IDs, unfinished purchases and paid entitlements.

The 1,000-path collection sampler starts after ten tutorial discoveries. A wood-first route needs **85 Wood + 7 Gold Vaults = 10,400 coins**; alternating or gold-first routes cost more because WILD rewards are Gold-only. This is a collection-budget diagnostic, not a required player goal.

## Method and limits

- The simulator uses the authoritative Dart scorer and rule lifecycle. It records no changes to live scoring mathematics, joker effects, rewards, RNG streams, saves or services.
- Normal and specialist cells use 250 or 100 runs; Daily/Gauntlet use 150; these are samples, not population confidence intervals.
- Bot policies are stronger and more consistent than most people. `handRanking` is a weak probe; `adaptive`, `pairBuilder` and `flushBuilder` are policy probes, not claims about human skill segments.
- Modeled minutes use explicit animation and decision-time assumptions. They are not phone profiling, FPS measurements or a promise of playtime.
- Savings paths resample observed rewards independently at a fixed collection state. They do not model spending, shop choices, player improvement, retention or wallet mixing.

The next evidence step is a small human playtest with reward telemetry and real localized Play offer data. No production implementation was made from this report.

## Reproducibility

The analysis scripts and bounded outputs are in this folder. Run `python analyze_economy.py`, then `python make_lifecycle_data.py`, `python make_artifact.py`, and the notebook with `nbclient` (or a Jupyter/Notebook UI). The source branch for the analysis is `agent/astra-economy-study`; the public Play build remains untouched.

# Validation Report

## Overall Assessment: Ready to share

## Methodology Review

The analysis answers the requested opening, starter, strategy and fun questions with paired deterministic simulations from the current v6.9.13 source. Power and enjoyment proxies are reported separately.

## Issues Found

No calculation, pairing, provenance or invariant discrepancies found.

## Calculation Spot-Checks

- Game source SHA matched `499c1ebe75a5346e7fe3c06cf0b0328cc29e32e90d62a77b237071ffeaa2bab9`.
- Both simulation suites reported zero data, hook and run-invariant failures.
- All 12 opening arms contain 50,000 paired deals.
- All starter arms use the same 1,000 ordered seeds.
- All strategy arms use the same 1,000 ordered seeds.
- Win rates, run depth, Wilson intervals and paired agency counts reconciled.
- Canonical report datasets and source provenance reconcile to simulation outputs.

## Visualization Review

The canonical artifact uses comparison bars for opening/starter/strategy rankings and a labeled strategy scatter for the strength-versus-variety trade-off. All chart datasets retain sample sizes, confidence bounds and adjacent audit measures.

## Suggested Improvements

1. Add a one-step lookahead opening bot to compare play-now versus discard value.
2. Repeat the starter screen with the full veteran Joker shop pool.
3. Pair simulator proxies with closed-test pace, fairness and trigger-recall questions.

## Required Caveats for Stakeholders

- These are deterministic bot simulations, not player telemetry.
- Opening score is immediate score and does not prove play-now beats discard.
- All strategy bots share an immediate-score card selector; build/shop policy is the main varied factor.
- Joker activity counts scoring-event hooks and understates Heat-clear/economy effects.
- Affordable-choice shops are not guaranteed to contain two positive upgrades.
- Fun conclusions remain proxy-based until pace, fairness and Joker-recall testing is complete.

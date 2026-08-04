# WILDCARD v8.5.0 Joker shop rarity evidence

## Source-backed guardrails

- Common weight: 4.0
- Uncommon weight: 3.2
- Rare weight: 3.0
- WILD weight: 0.45
- WILD gate: Heat 6
- WILD pity: 24 missed eligible shops
- High-impact gate: Heat 4
- High-impact same-rarity weight: 0.5x
- Maximum combined high-impact/WILD offers: one per shelf
- Arcade WILD gate: Round 12, without pity

The high-impact non-WILD set is `rarity_hunter`, `flushfund`,
`rule_breaker`, `danger_music`, `purist`, `survivor` and `ensemble`.
These controls alter availability, not each Joker's rarity, score, effect or
price.

## Measured shop output

The stress audit generated 280,000 shelves with zero undiscovered offers,
duplicates, early-gate violations or premium-cap violations.

| Sample | Shelves | WILD shelf rate | High-impact rate | Pity-forced |
|---|---:|---:|---:|---:|
| Normal, full pool, Heat 3 | 20,000 | 0% | 0% | 0% |
| Normal, 25 discovered, Heat 8 | 20,000 | 0% | 3.47% | 0% |
| Normal, full pool, Heat 8 | 100,000 | 4.988% | 6.537% | 3.164% |
| Arcade, full pool, Round 3 | 20,000 | 0% | 0% | n/a |
| Arcade, full pool, Round 12+ | 100,000 | 2.956% | 10.023% | n/a |

A standard 12-Heat run has only six naturally WILD-eligible shop visits, so a
24-miss pity cannot force a WILD before Normal victory. It remains a deep
Endless drought backstop.

## Joker contribution evidence

The exact Dart engine ran 200 matched-five Medium runs per public Joker.
Largest measured single-Joker win-rate lifts included:

| Joker | Rarity | Win rate | Control | Lift |
|---|---|---:|---:|---:|
| Rarity Hunter | Rare | 60.5% | 26.0% | +34.5pp |
| Pair Trainer | WILD | 60.0% | 31.5% | +28.5pp |
| Flush Fund | Uncommon | 56.5% | 32.0% | +24.5pp |
| Blood Money | WILD | 46.0% | 26.5% | +19.5pp |
| Rule Breaker | Uncommon | 45.5% | 27.0% | +18.5pp |
| Heat Surge | WILD | 51.0% | 32.5% | +18.5pp |

The top-pair audit found 17 tested pairs above a 70% win rate. The strongest
sample was Pair Trainer + Survivor at 81.0% across 200 runs. This evidence
supports acquisition spacing and a maximum-one premium shelf, but does not by
itself justify changing already approved scoring effects.

Raw per-Joker and pair rows are retained in
`wildcard-v8.5.0-joker-balance.csv` and
`wildcard-v8.5.0-joker-pairs.csv`.

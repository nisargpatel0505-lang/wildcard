# WILDCARD v6.9.14 Simulation Audit

Generated from the live `www/index.html` game script.

- Source SHA-256: `b34c7cd44834a6468b058b0250c5d6810479f5e299b167a09e8cb5eabd46478b`
- Simulator SHA-256: `562d4800ecbb4e2f69dc8e7a66766b68bf318ef094ecba1a2fccbd69986cbe46`
- Deterministic seed: `0x57C0FFEE` (mulberry32)

## Scope

- 10,000 randomized scoring and Joker-combination cases.
- 5,000 six-card "The Cheat" subset comparisons.
- 550 complete bot runs across standard, new-player, and Gauntlet cohorts.
- 57 Jokers checked for data validity, hook exceptions, unreachable effects, and interaction failures.
- Invariants checked after every discard, play, clear, and shop.

## Cohorts

| Cohort | Runs | Win rate | Avg cleared | Median | P90 | Avg score | Avg best play |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| standard_all_unlocked | 300 | 42% | 10.36 | 11 | 12 | 12096.8 | 1899.5 |
| standard_free_pool | 150 | 2.67% | 9.75 | 10 | 11 | 8345.7 | 631.1 |
| gauntlet_all_unlocked | 100 | 65% | 7.44 | 8 | 8 | 5846.5 | 1091.2 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 5,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: couple, sniper, tailor, doubledown, encore, redline.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 5: 1, Heat 6: 5, Heat 7: 11, Heat 8: 9, Heat 9: 36, Heat 10: 28, Heat 11: 25, Heat 12: 59
- **standard_free_pool:** Heat 6: 2, Heat 7: 1, Heat 8: 5, Heat 9: 30, Heat 10: 10, Heat 11: 45, Heat 12: 53
- **gauntlet_all_unlocked:** Heat 4: 1, Heat 5: 3, Heat 6: 2, Heat 7: 4, Heat 8: 25

## Most Selected Jokers

- **standard_all_unlocked:** buys polish (100), allin (95), miser (78), surge (75), survivor (74), lastcall (73), royalscam (73), lucky7 (70), pocketflush (68), fulltable (68), modded (67), shortcut (66), trainer (64), redline (63), momentum (61); final builds allin (95), polish (84), surge (75), lastcall (73), survivor (73), glass_joystick (67), shortcut (63), pocketflush (62), redline (62), royalscam (60), trainer (60), lucky7 (55), danger_music (54), miser (53), butcher (47)
- **standard_free_pool:** buys lowball (149), copper (147), opening_act (146), fulltable (146), even (108), retainer (71), presser (44), uniform (23), triple3 (21); final builds polish (150), copper (147), opening_act (146), fulltable (143), lowball (140), even (15), uniform (5), retainer (3), presser (1)
- **gauntlet_all_unlocked:** buys fulltable (26), survivor (25), copper (25), polish (24), clutch_gear (23), lastcall (23), modded (21), storm_harness (21), royalscam (21), lucky7 (21), trainer (18), dividend (18), allin (17), shortcut (17), miser (17); final builds glass_joystick (45), survivor (25), polish (24), lastcall (23), fulltable (22), modded (20), royalscam (20), lucky7 (20), storm_harness (19), allin (17), shortcut (17), miser (17), trainer (17), pocketflush (15), surge (14)

## First Cheat Mismatches

```json
[]
```

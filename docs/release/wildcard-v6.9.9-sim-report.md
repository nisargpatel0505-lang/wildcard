# WILDCARD v6.9.9 Simulation Audit

Generated from the live `www/index.html` game script.

## Scope

- 10,000 randomized scoring and Joker-combination cases.
- 5,000 six-card "The Cheat" subset comparisons.
- 550 complete bot runs across standard, new-player, and Gauntlet cohorts.
- 57 Jokers checked for data validity, hook exceptions, unreachable effects, and interaction failures.
- Invariants checked after every discard, play, clear, and shop.

## Cohorts

| Cohort | Runs | Win rate | Avg cleared | Median | P90 | Avg score | Avg best play |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| standard_all_unlocked | 300 | 28% | 10.2 | 11 | 12 | 11248 | 1693.6 |
| standard_free_pool | 150 | 0.67% | 9.81 | 10 | 11 | 8418.6 | 623.2 |
| gauntlet_all_unlocked | 100 | 34% | 7.11 | 7 | 8 | 5236.7 | 848.3 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 5,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: sniper, tailor, doubledown, encore, redline.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 4: 2, Heat 5: 1, Heat 6: 4, Heat 7: 8, Heat 8: 13, Heat 9: 37, Heat 10: 22, Heat 11: 31, Heat 12: 98
- **standard_free_pool:** Heat 6: 2, Heat 7: 1, Heat 8: 4, Heat 9: 29, Heat 10: 9, Heat 11: 42, Heat 12: 62
- **gauntlet_all_unlocked:** Heat 5: 2, Heat 6: 3, Heat 7: 11, Heat 8: 50

## Most Selected Jokers

- **standard_all_unlocked:** buys fulltable (96), lastcall (95), allin (91), polish (91), lucky7 (89), redline (82), survivor (79), modded (71), copper (69), storm_harness (69), surge (67), royalscam (67), miser (66), opening_act (63), trainer (62); final builds lastcall (95), allin (91), redline (80), polish (78), survivor (78), lucky7 (74), surge (67), trainer (62), glass_joystick (59), shortcut (59), pocketflush (59), royalscam (56), fulltable (54), modded (53), butcher (52)
- **standard_free_pool:** buys fulltable (148), opening_act (146), copper (146), lowball (145), even (105), retainer (61), presser (47), triple3 (25), uniform (24); final builds polish (150), copper (146), opening_act (146), fulltable (144), lowball (141), even (18), uniform (3), retainer (1), presser (1)
- **gauntlet_all_unlocked:** buys polish (29), lucky7 (29), lastcall (28), fulltable (27), flushfund (21), redline (21), allin (21), trainer (20), storm_harness (18), surge (18), royalscam (18), clutch_gear (17), miser (16), modded (16), dividend (16); final builds polish (29), lucky7 (29), glass_joystick (28), lastcall (28), fulltable (23), redline (21), allin (21), trainer (20), surge (18), royalscam (17), storm_harness (16), survivor (15), miser (14), pocketflush (14), shortcut (14)

## First Cheat Mismatches

```json
[]
```

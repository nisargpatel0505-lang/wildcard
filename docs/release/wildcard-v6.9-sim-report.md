# WILDCARD v6.9 Simulation Audit

Generated from the live `www/index.html` game script.

## Scope

- 50,000 randomized scoring and Joker-combination cases.
- 15,000 six-card "The Cheat" subset comparisons.
- 2,600 complete bot runs across standard, new-player, and Gauntlet cohorts.
- 57 Jokers checked for data validity, hook exceptions, unreachable effects, and interaction failures.
- Invariants checked after every discard, play, clear, and shop.

## Cohorts

| Cohort | Runs | Win rate | Avg cleared | Median | P90 | Avg score | Avg best play |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| standard_all_unlocked | 1500 | 30.47% | 10.32 | 11 | 12 | 11822.7 | 1821.6 |
| standard_free_pool | 700 | 2.43% | 9.87 | 10 | 11 | 8541.4 | 646.9 |
| gauntlet_all_unlocked | 400 | 33.75% | 6.95 | 7 | 8 | 5091.8 | 900.9 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 15,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: uniform, sniper, tailor, doubledown, encore, redline, color_wash, prism_lens.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 3: 1, Heat 4: 5, Heat 5: 2, Heat 6: 36, Heat 7: 21, Heat 8: 65, Heat 9: 130, Heat 10: 158, Heat 11: 123, Heat 12: 502
- **standard_free_pool:** Heat 6: 3, Heat 7: 7, Heat 8: 16, Heat 9: 135, Heat 10: 62, Heat 11: 164, Heat 12: 296
- **gauntlet_all_unlocked:** Heat 3: 1, Heat 4: 6, Heat 5: 19, Heat 6: 18, Heat 7: 35, Heat 8: 186

## Most Selected Jokers

- **standard_all_unlocked:** buys polish (471), lastcall (467), fulltable (409), allin (407), miser (406), survivor (393), surge (385), lucky7 (372), royalscam (365), redline (339), danger_music (324), trainer (304), butcher (303), storm_harness (302), modded (299); final builds lastcall (467), polish (413), allin (407), survivor (390), surge (385), redline (336), danger_music (324), royalscam (299), trainer (298), lucky7 (288), butcher (286), pocketflush (286), shortcut (280), glass_joystick (272), miser (261)
- **standard_free_pool:** buys lowball (695), fulltable (690), copper (680), opening_act (676), even (513), retainer (345), presser (220), uniform (112), triple3 (105); final builds polish (700), copper (680), opening_act (676), fulltable (670), lowball (655), even (82), retainer (20), uniform (16), presser (1)
- **gauntlet_all_unlocked:** buys fulltable (102), lastcall (97), polish (81), redline (80), allin (79), dividend (75), clutch_gear (74), miser (73), survivor (72), trainer (72), modded (70), roller (70), momentum (69), doubledown (69), royalscam (67); final builds glass_joystick (105), lastcall (97), fulltable (93), redline (80), polish (80), allin (79), survivor (72), trainer (72), modded (67), miser (66), royalscam (65), lucky7 (65), roller (63), storm_harness (54), shortcut (52)

## First Cheat Mismatches

```json
[]
```

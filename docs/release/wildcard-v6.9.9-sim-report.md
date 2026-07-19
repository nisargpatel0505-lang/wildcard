# WILDCARD v6.9.9 Simulation Audit

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
| standard_all_unlocked | 1500 | 29.07% | 10.22 | 11 | 12 | 11531.7 | 1769.3 |
| standard_free_pool | 700 | 1% | 9.82 | 10 | 11 | 8455.8 | 648.2 |
| gauntlet_all_unlocked | 400 | 35% | 7.05 | 7 | 8 | 5266.1 | 918.4 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 15,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: sniper, tailor, doubledown, encore, redline.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 3: 2, Heat 4: 4, Heat 5: 7, Heat 6: 39, Heat 7: 32, Heat 8: 61, Heat 9: 163, Heat 10: 134, Heat 11: 111, Heat 12: 511
- **standard_free_pool:** Heat 6: 3, Heat 7: 10, Heat 8: 16, Heat 9: 120, Heat 10: 75, Heat 11: 189, Heat 12: 280
- **gauntlet_all_unlocked:** Heat 3: 1, Heat 4: 3, Heat 5: 8, Heat 6: 19, Heat 7: 39, Heat 8: 190

## Most Selected Jokers

- **standard_all_unlocked:** buys polish (506), lastcall (451), fulltable (440), redline (428), allin (396), royalscam (388), surge (386), survivor (384), miser (370), lucky7 (358), storm_harness (318), modded (312), pocketflush (301), dividend (289), shortcut (280); final builds lastcall (451), polish (435), redline (427), allin (396), surge (386), survivor (382), royalscam (312), lucky7 (295), pocketflush (292), danger_music (272), shortcut (268), glass_joystick (264), fulltable (261), trainer (258), cheat (258)
- **standard_free_pool:** buys lowball (705), copper (683), fulltable (682), opening_act (678), even (506), retainer (346), presser (233), uniform (127), triple3 (107); final builds polish (700), copper (683), opening_act (678), fulltable (670), lowball (651), even (74), retainer (24), uniform (19), presser (1)
- **gauntlet_all_unlocked:** buys polish (99), lastcall (95), allin (91), fulltable (91), miser (84), lucky7 (71), storm_harness (71), copper (68), opening_act (68), survivor (68), panic_button (68), flushfund (68), surge (67), modded (65), doubledown (65); final builds glass_joystick (114), polish (99), lastcall (95), allin (91), fulltable (82), miser (81), lucky7 (70), survivor (68), surge (67), royalscam (63), storm_harness (63), modded (62), trainer (62), doubledown (54), redline (53)

## First Cheat Mismatches

```json
[]
```

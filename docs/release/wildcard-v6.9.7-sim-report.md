# WILDCARD v6.9.7 Simulation Audit

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
| standard_all_unlocked | 300 | 26% | 10.21 | 11 | 12 | 11609.4 | 1852.2 |
| standard_free_pool | 150 | 2.67% | 9.81 | 10 | 11 | 8438.2 | 646 |
| gauntlet_all_unlocked | 100 | 35% | 6.89 | 7 | 8 | 5001.3 | 849.6 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 5,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: uniform, sniper, tailor, doubledown, encore, redline, color_wash, prism_lens.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 5: 3, Heat 6: 9, Heat 7: 4, Heat 8: 11, Heat 9: 33, Heat 10: 24, Heat 11: 30, Heat 12: 108
- **standard_free_pool:** Heat 6: 1, Heat 8: 6, Heat 9: 35, Heat 10: 10, Heat 11: 28, Heat 12: 66
- **gauntlet_all_unlocked:** Heat 2: 1, Heat 3: 2, Heat 5: 1, Heat 6: 7, Heat 7: 13, Heat 8: 41

## Most Selected Jokers

- **standard_all_unlocked:** buys lastcall (99), polish (95), miser (88), survivor (86), allin (83), redline (83), lucky7 (79), fulltable (69), pocketflush (69), roller (68), storm_harness (68), danger_music (67), royalscam (62), butcher (61), modded (61); final builds lastcall (99), survivor (86), allin (83), redline (83), polish (81), danger_music (67), lucky7 (67), pocketflush (66), surge (58), butcher (57), trainer (56), miser (55), cheat (53), glass_joystick (53), royalscam (49)
- **standard_free_pool:** buys lowball (149), fulltable (148), opening_act (147), copper (144), even (108), retainer (93), presser (53), uniform (26), triple3 (22); final builds polish (150), opening_act (147), fulltable (145), copper (144), lowball (141), even (15), retainer (5), uniform (2), triple3 (1)
- **gauntlet_all_unlocked:** buys polish (30), clutch_gear (25), fulltable (24), lucky7 (24), surge (21), momentum (20), dividend (19), miser (19), roller (18), modded (18), dumpster (18), redline (17), panic_button (16), lastcall (15), flushfund (15); final builds polish (30), lucky7 (24), fulltable (21), glass_joystick (21), surge (21), roller (18), miser (18), redline (17), dividend (16), modded (16), lastcall (15), pocketflush (14), clutch_gear (14), survivor (14), rehearsal_tape (13)

## First Cheat Mismatches

```json
[]
```

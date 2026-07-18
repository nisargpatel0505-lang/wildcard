# WILDCARD v6.9.12 Simulation Audit

Generated from the live `www/index.html` game script.

- Source SHA-256: `6585cb1976fe44bfbaf49a4aca310d512fbca008392dfc83ff89077f7256f75c`
- Simulator SHA-256: `11660571a5ad227b24ff2f205969dba7801df1d79156bdbb64d65078f72ceb09`
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
| standard_all_unlocked | 300 | 31.67% | 10.34 | 11 | 12 | 11789.4 | 1801.3 |
| standard_free_pool | 150 | 2% | 9.86 | 10 | 11 | 8521.6 | 621.5 |
| gauntlet_all_unlocked | 100 | 39% | 7.03 | 7 | 8 | 5502.3 | 1083.8 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 5,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: sniper, tailor, doubledown, encore, redline.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 6: 6, Heat 7: 6, Heat 8: 16, Heat 9: 31, Heat 10: 25, Heat 11: 21, Heat 12: 100
- **standard_free_pool:** Heat 6: 2, Heat 7: 2, Heat 8: 5, Heat 9: 24, Heat 10: 10, Heat 11: 40, Heat 12: 64
- **gauntlet_all_unlocked:** Heat 4: 1, Heat 5: 2, Heat 6: 8, Heat 7: 10, Heat 8: 40

## Most Selected Jokers

- **standard_all_unlocked:** buys polish (94), surge (89), fulltable (83), allin (82), royalscam (81), lastcall (79), lucky7 (79), survivor (77), redline (76), miser (71), danger_music (68), dividend (66), panic_button (63), pocketflush (63), roller (60); final builds surge (89), polish (87), allin (82), lastcall (79), survivor (76), redline (75), royalscam (68), danger_music (68), lucky7 (65), pocketflush (61), trainer (55), butcher (54), cheat (53), glass_joystick (48), shortcut (47)
- **standard_free_pool:** buys lowball (150), copper (146), fulltable (146), opening_act (146), even (103), retainer (76), presser (41), uniform (29), triple3 (24); final builds polish (150), copper (146), opening_act (146), lowball (143), fulltable (143), even (15), uniform (4), retainer (2), presser (1)
- **gauntlet_all_unlocked:** buys fulltable (28), polish (24), surge (20), lowball (20), trainer (19), lastcall (19), inktrade (18), opening_act (17), redline (17), royalscam (17), survivor (17), modded (16), dividend (16), allin (16), copper (16); final builds glass_joystick (29), fulltable (27), polish (24), surge (20), trainer (19), lastcall (19), redline (17), survivor (17), royalscam (16), allin (16), miser (15), shortcut (15), butcher (14), modded (14), dividend (14)

## First Cheat Mismatches

```json
[]
```

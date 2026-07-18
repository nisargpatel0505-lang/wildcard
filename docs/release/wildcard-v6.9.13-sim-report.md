# WILDCARD v6.9.13 Simulation Audit

Generated from the live `www/index.html` game script.

- Source SHA-256: `499c1ebe75a5346e7fe3c06cf0b0328cc29e32e90d62a77b237071ffeaa2bab9`
- Simulator SHA-256: `0967ab6f51f5a8b45a6c648b569fc79610c51a1a8f1bdc71129d75e3404c0708`
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
| standard_all_unlocked | 300 | 28.33% | 10.36 | 11 | 12 | 11736.8 | 1762.3 |
| standard_free_pool | 150 | 1.33% | 9.91 | 10 | 11 | 8603 | 638.7 |
| gauntlet_all_unlocked | 100 | 39% | 6.95 | 7 | 8 | 5243.2 | 941 |

## Confirmed Mechanics Findings

- Frostbite high-card selection: played A♠ + K♥, scoring flags were [false,true]. The non-frozen K♥ should score. This is working.
- The Cheat chose a lower-scoring five-card subset in 0 / 5,000 cases (0%).
- Hook exceptions: 0.
- Scoring/data failures: 0.
- Run invariant failures: 0.
- Never-activated Joker hooks in the coverage matrix: sniper, tailor, doubledown, encore, redline.
- Effectively always-active hooks in the coverage matrix: copper, roller, fulltable, miser, allin, practice_mode, glass_joystick.

## Failure Walls

- **standard_all_unlocked:** Heat 5: 1, Heat 6: 7, Heat 7: 8, Heat 8: 7, Heat 9: 31, Heat 10: 23, Heat 11: 22, Heat 12: 116
- **standard_free_pool:** Heat 6: 1, Heat 8: 2, Heat 9: 27, Heat 10: 18, Heat 11: 34, Heat 12: 66
- **gauntlet_all_unlocked:** Heat 3: 1, Heat 4: 1, Heat 5: 5, Heat 6: 6, Heat 7: 8, Heat 8: 40

## Most Selected Jokers

- **standard_all_unlocked:** buys fulltable (96), redline (87), polish (84), survivor (81), surge (79), allin (78), royalscam (77), miser (76), lastcall (76), lucky7 (75), roller (71), trainer (71), danger_music (67), modded (65), shortcut (64); final builds redline (87), survivor (80), surge (79), allin (78), polish (77), lastcall (76), trainer (71), danger_music (67), fulltable (64), royalscam (61), butcher (60), shortcut (59), lucky7 (59), pocketflush (55), glass_joystick (53)
- **standard_free_pool:** buys lowball (153), copper (147), fulltable (146), opening_act (144), even (112), retainer (76), presser (46), triple3 (27), uniform (23); final builds polish (150), copper (147), opening_act (144), lowball (143), fulltable (142), even (17), uniform (6), presser (1)
- **gauntlet_all_unlocked:** buys dividend (29), fulltable (26), miser (25), redline (23), allin (22), surge (21), lastcall (21), royalscam (20), polish (19), lucky7 (18), modded (18), lowball (17), wire (17), piggy (16), inktrade (16); final builds dividend (24), miser (23), redline (23), allin (22), fulltable (22), surge (21), lastcall (21), royalscam (20), polish (19), lucky7 (18), glass_joystick (17), modded (16), pocketflush (15), survivor (15), shortcut (14)

## First Cheat Mismatches

```json
[]
```

# WILDCARD — ChatGPT 5.6 balance hotfix (20 July 2026)

This is an isolated test branch. It does not update `main`, the Raspberry Pi deployment, Google Play, or any public `WILDCARD-latest.apk` alias.

## Player reports addressed

- Endless could be pushed indefinitely with a nine-card deck made from repeated same-suit three-card Shortcut sequences, maxed hand boosts and stacked multiplier Jokers.
- Copier allowed enhanced cards to be selected and duplicated.
- Supply prices appeared to reset between Heat shops because v6.9.14 tracked a separate `+2` history for each supply instead of one visible run-wide surcharge.
- Endless rewards grew without bound (`3 + Heat`, so Heat 74 paid 77 run coins).
- The existing modifier cadence remained every third Heat forever and did not create a post-50 difficulty phase.
- Multiplier-heavy builds had too few direct counters.

## Fix design

- Shortcut now makes a three-card Straight only. It no longer silently promotes a same-suit three-card sequence to Straight Flush; the Joker text never promised that upgrade.
- Run decks have a 24-card floor and at most two copies of an exact rank/suit card. Legacy exploit decks are repaired before the next Heat. Duplicate enhanced copies are normalised to one enhanced copy.
- Copier greys out enhanced cards and exact cards already at the two-copy cap, with an explanatory accessibility label and a second runtime guard.
- Supply pricing is now a global run surcharge: every completed supply purchase raises every supply by 5 coins through Heat 20, then by 10 coins from Heat 21 onward. The surcharge is save/resume data and migrates old per-supply purchase histories conservatively.
- Standard Heat 1–12 rewards are unchanged. Endless reward growth is capped at 24 coins, and interest caps at 3 after Heat 20.
- Endless targets retain the old linear curve through Heat 30, then gain a triangular acceleration term. Heat 74 is about 83,800 before target modifiers, rather than 39,250.
- From Heat 51 onward, every Endless Heat receives two distinct stacked modifiers. Existing modifiers combine naturally, including target, hand-size and discard effects.
- Four hard modifiers were added: Blackout (blocks Joker +Mult and ×Mult), Sudden Death (one fewer play), Power Drain (hand boosts count two levels lower), and Shakedown (no interest and half clear reward). To avoid crushing the tutorial curve, these are excluded from standard Heat 3 and 6, but enter at Heat 9, Gauntlet and Endless.
- Glass shattering cannot reduce the deck below the new 24-card floor.

## Why the old simulations missed the flaws

1. Complete bot runs stopped at Heat 12, or Heat 8 for Gauntlet. Endless and post-50 behavior were never simulated.
2. The Scalpel bot only removed cards while the deck was above 42 cards. The exploit required the old nine-card floor.
3. The Copier bot mutated `run.cards` directly. It bypassed picker disabled states and therefore could not test whether enhanced cards were selectable.
4. The bot did not contain an adversarial deck-sculpting strategy that deliberately repeats a same-suit three-rank sequence.
5. The supply unit test correctly proved v6.9.14's *per-item* `+2` persistence. It did not test the newly requested *global* surcharge, which explains why a different supply in the next shop looked reset to players.
6. No long-run economy assertion checked reward growth at Heat 50, 74 or beyond.

## Simulation readout

A source-backed greedy bot probe ran 100 deterministic runs for each requested cohort on the patched game logic:

| Cohort | Unlocked Jokers | Beat Heat 12 | Win rate | Average Heats cleared |
| --- | ---: | ---: | ---: | ---: |
| New player / free pool | 10 | 2 / 100 | 2% | 9.64 |
| Some progression (`unlock <= 80`) | 37 | 1 / 100 | 1% | 8.74 |
| Full unlock | 57 | 14 / 100 | 14% | 8.93 |

The progression cohort underperformed the free pool in this greedy policy because its larger offer pool dilutes the compact starter synergies; this is a bot-policy finding, not evidence that human progression is harmful. The full-unlock rate fell materially from the latest committed v6.9.14 quick baseline (42% in 300 runs), mainly because Blackout/Sudden Death can appear at Heat 9 and the global supply surcharge removes repeated cheap boosts. The sample is useful for regression direction, but should be followed by the repository's larger paired simulator before merging.

## Local test artifact

- Baseline APK SHA-256: `51e9f6257497145076bb47aeaf09bb1c2956df9161549e1bc1506e42bd63428d`
- Patched HTML SHA-256: `fb10cbc090e35296ece6de3c84d94100538de80fb7782f1ef54e67da1284944a`
- Locally rebuilt test APK SHA-256: `347481693ddc2ce1483d3e6ea8ffdca7a095ffcb52531c6ae2c325c56580a7ee`

The local APK is JAR-signed with a separate test certificate, not the production Play certificate. Android will not treat it as an update to an installed production-signed copy; uninstall the production package first or use a separate test device/profile. A GitHub Actions build using the repository signing secrets should be used for an in-place test update.

# WILDCARD v6.9.5

## Win FX visibility

- Win FX now triggers after every positive scoring play.
- High Card scores use a light accent treatment.
- Pair-or-better hands use the standard treatment.
- NICE, GREAT, MEGA, WILD and other large scores use the full hero treatment.
- Classic Sparks is now wired into real runs instead of preview-only use.
- Jackpot, Fireworks, Confetti and Lightning scale their particle budgets by tier.
- A fast centre pulse makes each equipped cosmetic readable during the score reveal.
- Lite-profile phones automatically use reduced particle counts.

## Pacing lock

- Normal-mode scoring remains at the approved `1.08` authored rhythm.
- Fast mode remains an opt-in `0.65` multiplier.
- The 520 ms score-settle, 500 ms score reveal and 340 ms card-exit beats are unchanged.
- Win FX remains cosmetic and adds no awaited delays to scoring.

## Android release

- Version name: `6.9.5`
- Version code: `18`
- APK: `releases/WILDCARD-v6.9.5.apk`
- AAB: `releases/WILDCARD-v6.9.5.aab`
- APK SHA-256: `33e489347eae4475c596a5bb0d274145df3a473e3a4e03fc6cd4905268ab7802`
- AAB SHA-256: `3557503b7929b861349750fa5cf731a35ab8a6adfc5fbf2906f5105399eb126d`

## Verification

- Canonical HTML and standalone JavaScript compiled successfully.
- 50,000 scoring cases, 15,000 Cheat checks and 2,600 complete simulated runs retained zero failures.
- Google/Firebase repository audit retained zero hard-check failures.
- Release APK and AAB built and signed successfully.
- APK installed over the existing phone save and reported version `6.9.5` / code `18`.
- Wardrobe previews were visually checked for Classic Sparks, Jackpot, Fireworks, Confetti and Lightning.
- A real seven-point High Card play showed the new accent Win FX, confirming low scores now trigger it.
- The test run was abandoned and the phone was returned to the main menu.

# WILDCARD v6.9.8 economy and rewarded-recovery notes

## Player-facing changes

- Paid Joker unlocks are now priced by rarity from their existing catalogue values. The 47 paid Jokers total 10,875 account coins; the 10 starter Jokers remain free.
- Wooden and Golden Vaults cost 100 and 300 account coins.
- The daily-login curve is 30 base coins, +18 per streak day, capped at 192. This is exactly 40% below the previous curve.
- A failed non-Daily Heat can offer one rewarded final play per run. The run is checkpointed before the ad opens, the reward restores exactly one play, and revived runs remain local rather than submitting to the official leaderboard.
- Eligible run results can offer one rewarded doubling of that run's account-coin earnings. It does not alter score, Daily Board results or other rewards.
- Browser playtests use an explicit completed-reward simulator. Android uses the native rewarded-ad bridge.

## Save and callback safety

- Account reward claims use a bounded idempotency ledger.
- Heat rewards, completion rewards and doubled run coins use stable per-run claim IDs, preventing duplicate payment after a repeated callback or replayed checkpoint.
- Rewarded-ad callbacks settle when the native earned event arrives; a later dismiss/failure event cannot reverse or duplicate the reward.
- The revive checkpoint is written before presenting the offer. A resumed terminal run returns to the revive decision instead of restoring an interactive zero-play table.

## Economy evidence

- Direct Joker collection: 4,700 -> 10,875 coins.
- Duplicate-free Vault completion mean: 2,969.19 -> 8,776.21 coins.
- Proposed Vault path discount versus direct unlocks: 19.3%.
- 180-day daily-login total: 56,250 -> 33,750 coins.
- Deterministic model: 12,000 player timelines plus 20,000 Vault audits per scenario; all nine model gates pass.
- Model hash: `2d5c58a998709fe5679a41813b31b80a8dfe0989f92c22a2f82cffe2f4e4c226` (matched on repeat).

## Verification

- `npm test`: passed (50,000 scoring/Joker cases, 15,000 Cheat comparisons, 2,600 complete runs, zero failures).
- `npm run test:economy-rewards`: passed.
- `npm run test:native-ads`: passed.
- `npm run test:economy`: passed; repeated model hash matched.
- `npm run audit:google`: passed for v6.9.8 / version code 22.
- Release APK, release AAB and developer APK builds completed successfully.
- Phone-sized browser validation at 390 x 844 completed both rewarded flows with no horizontal overflow and zero console errors.

## Artifacts

- Source HTML SHA-256: `eb6d06b054fc0c9e41fa0dbc3a6b1296fcf089a6e59ffdb17425d96c7fc123a0`
- Release APK: `releases/WILDCARD-v6.9.8.apk`
- Release APK SHA-256: `e00e0d71a0e146294d9af9e906ae1fe0bd02b5b648f8ea9294a4e90abb294738`
- Release AAB: `releases/WILDCARD-v6.9.8.aab`
- Release AAB SHA-256: `fb0c67379554368deffcf2077f1974f9e5f5aeb03dec5c880bd70e94c704257e`
- Developer APK SHA-256: `255f9d9a0e38c3e30596087d6060e1bb24e6896a093eac7e67b0e028c1e23ef1`
- Release signing certificate SHA-256: `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`

## Production blocker

The repository still deliberately contains Google's AdMob test application and ad-unit IDs with test mode enabled. The placement logic is verified, but it earns no revenue in this state. Real AdMob application, rewarded and interstitial IDs must be supplied and verified before any production/internal-track monetization test; no identifiers were invented or substituted in this change.

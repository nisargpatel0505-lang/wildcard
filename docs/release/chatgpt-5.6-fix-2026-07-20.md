# WILDCARD — ChatGPT 5.6 fix — 20 July 2026

Status: isolated tester branch. This work does not change `main`, the Play package, the Raspberry Pi deployment, or any existing public APK alias.

## Diagnosis

The uploaded `WILDCARD-latest.apk` is the currently published v6.9.14 build. Its APK SHA-256 is `51e9f6257497145076bb47aeaf09bb1c2956df9161549e1bc1506e42bd63428d`; the embedded canonical HTML SHA-256 is `b34c7cd44834a6468b058b0250c5d6810479f5e299b167a09e8cb5eabd46478b`.

The reported Endless loop was reproducible in the live rules:

1. Shortcut correctly allowed a three-card sequence, but `evaluateHand()` also promoted a suited three-card sequence to **Straight Flush**. The Flush part was never intended to work with three cards.
2. Scalpel could reduce the run deck to the nine-card hand floor. Copier could duplicate enhanced cards, duplicate an already copied card, and create unlimited exact rank+suit copies. Together these rules allowed a nearly deterministic three-card suited sequence every deal.
3. Endless targets were linear after Heat 12: `2,050 + 600 × (Heat - 12)`. Heat 74 therefore required only 39,250 points while permanent Mult engines continued compounding.
4. Endless used one modifier only every third Heat. A multiplier build could pass many late Heats without seeing a direct counter.
5. Supply prices were represented by per-supply counters. The existing regression checked in-memory `+2` arithmetic, but did not prove the completed purchase was durably recorded, serialized, restored, and still visible after the next Heat/shop.
6. Run-coin rewards, interest and grade bonuses replenished shops quickly enough that repeated deck surgery was cheap.

## Why the previous simulations missed it

The committed v6.9.14 audit ran standard bots only through Heat 12 and Gauntlet bots only through Heat 8. Its deck-sculpting policy used Scalpel only while the deck was above 42 cards and used Copier opportunistically; it never attempted to construct the minimum deterministic Shortcut sequence. The audit was strong at ordinary win-rate and invariant checks, but had no adversarial Endless horizon, no exact-copy/provenance invariant, no repeated-hand exploit probe, and no save/resume supply-price scenario.

The new simulator adds three safeguards:

- a deterministic baseline-versus-patch comparison on identical seeds for guided new players, 30-unlock progression, and full unlock;
- an explicit Heat-74 Shortcut/Mult exploit probe;
- direct assertions for stacked late-Endless modifiers, enhanced-card Copier blocking, deck floor, exact-copy cap, durable supply escalation, and legacy-save repair.

## Main issues fixed

### Endless and modifiers

- Heat 13–20 retains a readable linear ramp.
- Heat 21+ adds quadratic pressure, with a second acceleration after Heat 35.
- Heat 74 is 240,175 before modifiers instead of 39,250.
- After Heat 50, every Heat receives two distinct stacked modifiers.
- Every post-50 stack is guaranteed to contain at least one hard counter.
- Modifier stacks save and restore by modifier ID list.

New hard modifiers:

- **Null Field** — disables all `+Mult` and `×Mult`, including Neon and Glass.
- **Echo Chamber** — repeating the previous hand type halves final Mult.
- **Level Lock** — disables Hand Boost levels for the Heat.
- **Closing Time** — removes one play.
- **Counterfeit** — copied cards contribute zero rank.
- **Thin Ice** — a deck below 30 cards raises the target by 40%.

### Deck and card exploit protection

- A three-card suited Shortcut sequence is a **Straight**, never a Straight Flush.
- Scalpel stops at 24 cards.
- Copier greys out enhanced cards.
- Copier greys out cards that are themselves copies.
- Exact rank+suit copies are capped at two.
- Copied cards cannot be enhanced.
- Dye cannot create a third exact card; a card dyed into an existing exact card is marked copied and loses any enhancement.
- Legacy exploit saves are repaired on resume/next Heat: invalid or excess exact copies are removed, copied enhancements are stripped, and fair base cards are restored to the 24-card floor.

### Supply pricing and persistence

Pricing remains per specific supply, not a shared surcharge:

- purchases completed through Heat 20 add **+5 coins** to that supply’s future price;
- purchases completed after Heat 20 add **+10 coins**;
- every completed purchase is appended to `supplyPurchaseLedger` and saved immediately before UI callbacks;
- v6.9.13/v6.9.14 count-only saves migrate into the durable ledger instead of resetting;
- current-shop locks and the ledger are included in run serialization.

### Coin pressure

- Run reward: `2 + ceil(Heat × 0.75)`.
- Interest: one coin per eight held, capped at three.
- Reroll: three coins.
- Grade bonuses: S `+2`, A `+1`, B/C `+0`.

Account-unlock prices and permanent account rewards are unchanged in this tester patch.

## 500-seed Heat-12 simulation

The same deterministic heuristic policy and seed set were run against the v6.9.14 source and the isolated patch. These are bot-policy measurements, not estimates of human win rate.

| Cohort | v6.9.14 clears | Patched clears | Patched average Heat cleared |
|---|---:|---:|---:|
| Guided new player: 10 free Jokers + Copper Chip + Pair Polisher | 15 / 500 (3.0%) | 4 / 500 (0.8%) | 9.86 |
| Some progression: 30 lowest-cost unlocks | 1 / 500 (0.2%) | 1 / 500 (0.2%) | 8.60 |
| Full unlock: all 57 Jokers | 83 / 500 (16.6%) | 55 / 500 (11.0%) | 9.09 |

The mid-progression cohort remains a warning rather than a balance target: adding many conditional Jokers dilutes the shop pool and the fixed bot does not adapt its archetype well. A future unlock-by-unlock sweep should test whether real players encounter the same progression valley.

Multiplier Jokers remain the strongest normal-run path. In patched full-unlock runs, all final builds averaged 3.75 `×Mult` Jokers and Heat-12 winners averaged 4.80 out of five slots. The patch therefore does not erase Mult builds; it adds late-Endless counters and target pressure so one engine cannot remain universally valid forever.

## Exploit probe

The probe equips Shortcut plus four aggressive multiplier Jokers, maxes Straight Boost, plays suited Q-K-A at Heat 74, and compares identical live-source scoring:

| Source/state | Classification | Hand score | Heat target | Identical hands required |
|---|---|---:|---:|---:|
| v6.9.14 | Straight Flush | 16,134 | 39,250 | 3 |
| Patch, no modifier | Straight | 6,671 | 240,175 | 37 |
| Patch, Null Field + High Stakes | Straight | 384 | 300,219 | 782 |

A Heat provides four plays normally, so the reported deterministic loop cannot clear this probe after the patch.

## Validation

- 12/12 targeted live-source regression tests pass.
- 1,500 patched bot runs and 1,500 baseline bot runs completed without invalid score output.
- Heat 51 generated two distinct modifiers with at least one hard modifier in every repeated assertion.
- Supply escalation, legacy migration and immediate serialized persistence are covered.
- Patched canonical HTML SHA-256: `5cf29ef723d0f4e4e5035d46af0515e52bdc196858aa044c19d39b0e15c72835`.
- Plain patch SHA-256: `4024c3edf4cfcbc685103061469f1e08c1257aecb9e078fda4250b62466ac4d4`.

The detailed machine-readable output is in `docs/release/chatgpt-5.6-fix-2026-07-20-sim.json`.

## Isolated branch implementation

The production `www/index.html` remains byte-for-byte v6.9.14 in the branch history. The gameplay changes are stored as a compressed, source-controlled patch payload. `tools/apply-chatgpt-fix-2026-07-20.py` accepts only the verified v6.9.14 source hash, applies the patch, verifies the exact patched hash, and is idempotent. CI applies it only inside the disposable checkout before testing and Android packaging.

## APK isolation

The `chatgptfix` Android build type uses:

- application ID `com.nisarg.wildcard.chatgptfix`;
- version name `6.9.14-chatgpt-5.6-fix-20260720`;
- version code `1`;
- debug/test signing;
- ads disabled;
- Firebase/Google service configuration removed in CI.

It installs beside the production app and cannot update or replace `com.nisarg.wildcard`. Cloud save, Google sign-in and public leaderboards are intentionally unavailable in the isolated tester package. The workflow uploads the APK only as a GitHub Actions artifact; it does not modify release assets or public download links.

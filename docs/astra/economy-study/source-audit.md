# WILDCARD Astra economy: source audit

Read-only audit of `700372f1e91d970c0b253f859b7548db20b8e40c` (5 September 2026).
This document describes implemented constants and settlement paths, not human playtest results or verified live Google Play prices. No gameplay, reward, price, backend, or release changes were made for this audit.

## Scope and comparison

- **Baseline** means this Play-based source with `astraEnabled == false`, not the historical v8.7 owner/Level build or an older WebView economy.
- **Astra** means the isolated APK with `WILDCARD_ASTRA_BUILD=true`. It disables real purchases, ads, cloud/network services, and all stakes. Only Normal receives the new per-Heat economy.
- Active modes are **Normal, Daily, Gauntlet**. `RunMode` has exactly those three members; no active Level or Arcade mode is present (`game_rules.dart:146`). Endless continues a won Normal run.
- Dart source paths below are relative to `flutter_app/lib/`; backend and historical document paths are relative to the repository root.

## Account coins earned inside runs

Account coins are distinct from temporary **run coins** used in shops.

| Mode | Baseline account income | Astra account income |
|---|---|---|
| Normal: Easy / Medium / Hard | Each cleared Heat H gives `2 + floor(H/3)` | Each cleared Heat gives 8, or 10 when H is divisible by 3 |
| Normal completion | +10 once at Heat 12 | +10 once at Heat 12 |
| Endless | Continues the same per-Heat rule, without an explicit per-run cap | Continues the same Astra rule, without an explicit per-run cap |
| Gauntlet | Baseline per-Heat rule for eight clears, then +10: **35 total** | Unchanged: **35 total** |
| Daily | **0 direct run account coins**, including completion | Unchanged |

Difficulty changes targets (Easy 0.60x, Medium 1.00x, Hard 1.30x), not these per-clear account rewards. Different difficulty therefore changes expected earnings through success and time, not through a direct reward multiplier.

Sources: `domain/game_rules.dart:149,229`; `domain/astra_progression.dart:31`; `domain/economy.dart:12`; `game/game_controller.dart:815`.

### Exact completion, loss, abandon, and Endless timing

Each cleared Heat credits account coins immediately under an idempotent `runId:heat:H` claim. At Heat 12 the separate +10 completion claim is credited **before** showing Bank / Continue. Continue sets Endless and begins Heat 13; it does not award another completion bonus. A later loss or abandon preserves already-credited Heat rewards and the completion bonus. Ending the run records stats; it does not grant an additional blanket reward.

The two exact Normal formulas after **H cleared Heats**, excluding stakes and outside rewards, are:

- Baseline: `sum(h=1..H, 2 + floor(h/3)) + (H >= 12 ? 10 : 0)`.
- Astra: `8H + 2 floor(H/3) + (H >= 12 ? 10 : 0)`.

| Cleared Heats | Baseline | Astra |
|---:|---:|---:|
| 0 | 0 | 0 |
| 1 | 2 | 8 |
| 3 | 7 | 26 |
| 6 | 17 | 52 |
| 8 | 25 | 68 |
| 12 | 56 | 114 |
| 15 | 75 | 140 |
| 20 | 113 | 182 |
| 30 | 215 | 270 |
| 50 | 518 | 442 |
| 100 | 1,860 | 876 |

These are arithmetic source checks, not simulations. The eight-clear row is **Normal**; Gauntlet adds its completion bonus at eight, hence 35. Losing *at Heat 20* usually means only **19 cleared**, not the 20-clear row. There is no 180-coin Endless cap in this source. The 9,999,999 account-balance guard is not a per-run reward cap.

Sources: `game/game_controller.dart:668,688,730,815,1137,1204`; `app/app_controller.dart:892`.

### Stakes and entry spending

**Astra sets stake to zero at run creation**, so stake EV must not be included in Astra earnings. Astra Normal can choose `polish`, `flushfund`, or `wire` free without permanently unlocking the latter two. Other starting boosts use the baseline account-coin cost.

Baseline starter boosts cost 6 / 10 / 16 / 30 by Common / Uncommon / Rare / WILD. Stakes unlock after five cleared Heats: minimum 10, increments of 10, maximum 200 and at most 25% of wallet rounded down to tens.

Baseline Normal stake-return table per 100 staked after 0–12 clears is `[0,20,35,45,55,70,82,92,100,105,110,115,150]`, multiplied by Easy 0.80 / Medium 0.92 / Hard 1.00 and rounded. Entry already debits the original stake: net contract income is payout minus that debit.

Gauntlet settlement is importantly different. Its base-return table is `[0,6,12,20,30,42,58,80,200]` per 100, but actual settlement credits `2*base - stake`; entry has already debited one stake. Total net contract change is therefore **`2*base - 2*stake`**, not `base - stake`. Losing early can debit an additional amount at settlement. The account mutation can reject a negative resulting wallet, so insufficient funds at deferred settlement deserves a targeted test before baseline changes.

Sources: `game/game_controller.dart:55,1104`; `domain/economy.dart:94` and stake helpers; `domain/game_rules.dart:149`.

## Other account-coin sources

| Source | Amount / repeatability | Important qualification |
|---|---|---|
| Tutorial gift | 200 once | `starterGiftClaimed` guard; starting catalogue also normalized separately |
| First-loss comeback | One free Common/Uncommon Joker | No coins; normally `wire`, not a WILD |
| Daily login | 5, 10, 15, 20, then 25/day | Astra uses local UTC date because offline |
| 44 classic achievements | 2,797 total catalog rewards | Finite, individually claimed; some cannot currently be earned in Astra |
| 41 tiered achievements | 520 total catalog rewards | Finite; some title tiers award zero coins |
| Astra Journey | 780 total across nine claims | Astra only; separate permanent one-time claim ledger |
| Weekly missions | Five visible; 205–245 total for the selected set | Progress, selection and weekly reset determine actual availability |
| Baseline weekly refresh | Can expose the other five missions | One rewarded refresh/week; all ten catalog rewards total 450, if completed/claimed in the right order |
| Daily Board prizes | **Inactive** | Planned 300 / 200 / 200 is not live income |
| Rewarded coin ad | +25 | Baseline only; shared five-placement daily cap |
| Rewarded run double | Adds the run's account-earned amount | Baseline only, one per run; consumes one of the same five placements |
| Developer coins | +5,000 per developer action | Exclude entirely from gameplay/economy measurement |
| Paid packs | 250 / 600 / 1,600 / 3,600 / 8,500 | Baseline entitlement delivery; Astra purchases disabled |

The nine Journey amounts are 20, 40, 30, 50, 60, 80, 100, 150, 250. Catalog reward totals are ceilings, not repeatable per-run income. For example, the stake-profit achievement is unavailable with Astra stakes disabled.

Validation: rewards were re-extracted programmatically from the actual source lists: classic 44 entries / 2,797; tiered 41 entries / 520; Journey nine entries / **780**. An earlier draft incorrectly stated 880 for Journey; that arithmetic error is corrected here. Cosmetic source extraction also reconfirmed totals 30,050 / 39,500 / 46,100.

Daily has no direct run payout but can unlock the one-time **Daily Debut +30** and contribute to **three Daily runs/week +45** when that mission is selected. Current code counts a terminal Daily attempt even when abandoned; the same is true of Daily Debut. Non-Daily immediate abandons count for the five-runs mission (+40). These are cheap farming paths, not measured player behavior.

Baseline +25 ads, run doubles, and the weekly refresh share the five-placement cap. A run double is **not capped at 25 coins**: Normal completion doubles 56; a deep Endless result can double much more. The UI excludes Daily, abandoned and zero-earning runs. Rewarded revive uses the ad service directly and does **not** pass through that shared cap ledger; it is gated once per run instead. Astra has no ads, doubles, or paid refreshes.

Sources: `domain/progression_catalog.dart:558,1481,1503,1565` plus achievement/mission definitions; `domain/astra_journey.dart`; `app/app_controller.dart:423,437,466,655,732,973,1095,1583,1591`; `app/screens/game_host_screen.dart` reward-double and revive handlers.

## Joker collection and Vault costs

- Public catalogue: **102 Jokers = 36 Common + 36 Uncommon + 23 Rare + 7 WILD**.
- Ten permanent starters are **eight Common and two Rare** (`polish`, `face_value` are Rare), not ten Commons.
- Fresh locked pool is therefore **28 C + 36 U + 21 R + 7 W = 92**.
- The usual first-loss comeback removes one Uncommon from that pool; it does not change the prices by itself except by advancing Astra's ownership-count threshold.
- Owner DEV x20 is not part of the public catalogue. Direct permanent Joker purchase is absent; catalogue price fields do not mean that purchase route exists.

| Vault | Baseline | Astra | Base rarity weights |
|---|---:|---:|---|
| Wood | 200 | 60 while fewer than 15 public Jokers owned; then 100 | C 70 / U 27 / R 3 / W 0 |
| Gold | 350 | 300 | C 0 / U 52 / R 44 / W 4 |

Vaults do not duplicate owned Jokers. **Exhausted rarity weights transfer through an explicit fallback order, not proportional renormalization.** Wood without Commons becomes 97% Uncommon / 3% Rare; Wood with only Rares left becomes 100% Rare. Gold without Uncommons becomes 96% Rare / 4% WILD; Gold with only WILDs left becomes 100% WILD. Within a chosen rarity, an unowned Joker is selected uniformly.

Buying only Wood until all non-WILDs are owned, then Gold, has these exact minimum collection costs under current prices (no random-gold strategy or simulation assumed):

| Starting position | Baseline | Astra |
|---|---:|---:|
| Ten starters | 85 Wood + 7 Gold = **19,450** | 5 discounted Wood + 80 standard Wood + 7 Gold = **10,400** |
| Ten starters + usual free comeback | 84 Wood + 7 Gold = **19,250** | 4 discounted Wood + 80 standard Wood + 7 Gold = **10,340** |

For simulations, use actual owned IDs rather than only an ownership count: collection changes eligible run-shop offers and strengths. Astra's free starter draft is temporary access, not permanent collection ownership.

Sources: `domain/joker_catalog.dart`; `domain/economy.dart:283` and `JokerChestDefinition.effectiveOdds`; `domain/astra_progression.dart:40`; `app/app_controller.dart:437`.

## Other sinks and pack definitions

- Cosmetics: 24 tables, 21 UI themes, 15 Sly looks; one default in each group, so **57 paid cosmetics**.
- Direct purchase totals: tables 30,050 (250–3,200 each), themes 39,500 (1,000–5,000), Sly looks 46,100 (350–7,500): **115,650 total**.
- Cosmetic Vault is **1,000** and duplicate-protected. When both themes and other cosmetics remain, a theme gate is 0.8%; the remaining 99.2% goes to non-theme items. Within the selected side, per-item weights are Common 1, Uncommon 6, Rare 3, WILD 1. If only themes remain, selection becomes 100% themes. Vault-only completion is 57,000, assuming no other acquisitions; direct prices represent choosing a specific item, not resale value.
- Run-currency shops are separate from the permanent account economy. Baseline Heat reward is `2 + ceil(0.75H)` run coins, with interest `min(3,floor(runCoins/8))` and S/A grade +2/+1. Astra adds +3 run coins to the first three Heat rewards and offers an extra early choice/free reroll.
- Supplies cost run coins: Scalpel 3, Copier 5, Dye 4, Enhancer 6, Hand Boost 5, plus persistent per-run purchase surcharge. Purchases add +5 to that supply's future price (+10 after Heat 20); Inflation adds 2. Each type can be bought once per shop. These are not account-coin sinks.
- Paid grant IDs are `coins_250`, `coins_600`, `coins_1600`, `coins_3600`, `coins_8500`. Grants agree in `core/app_constants.dart`, `domain/economy.dart`, and `functions/billing.js`.
- Current Flutter displays localized Play `product.price`, or **Unavailable** when no metadata is returned. **Current live GBP prices are not established by this audit.** Older docs list £0.99 / £1.99 / £4.99 / £9.99 / £19.99, but those are historical evidence only.
- Remove Ads means forced-ad removal; optional rewarded ads remain available in the baseline. Astra has neither ad delivery nor real billing.

Sources: `domain/progression_catalog.dart`; `domain/economy.dart`; `core/app_constants.dart:41`; `app/screens/shop_hub_screen.dart:267`; `functions/billing.js`; historical-only `docs/release/wildcard-v6.9.10-revenue-sensitivity.md:24`.

## Important measurement risks and recommended definitions

1. **Separate all income channels.** Report direct cleared-Heat income, completion bonus, stake net, outside claims, paid grants, and account spending separately. Wallet change is not identical to the run-result `accountCoinsEarned` field.
2. **Use cleared Heats, not failed-at Heat.** Count completion bonus exactly once. Do not apply a nonexistent Endless cap.
3. **Model modes actually shipped.** Astra has no Level/Arcade and no stakes, real ads, rewarded doubles, or real purchases. Gauntlet remains 35 per full win; Daily remains zero direct run income.
4. **Compare early exit to full attempts.** Higher early Astra rewards may make short-repeat play efficient; compare deliberate abandon after 3/6 clears with full runs rather than assuming completion is always the best income route.
5. **Treat Easy earnings/hour as an open hypothesis.** Equal per-clear rewards plus lower targets may favor Easy for farming; quantify success and duration before changing difficulty rewards.
6. **Do not use simulation CPU time as player minutes.** Use measured animation time and explicitly assumed decision/shop time. Separate policy-strength effects, duration assumptions and seed uncertainty.
7. **Finite rewards must stay finite.** Start each campaign/progression model with its actual claim ledger. Do not add tutorial, achievement, Journey or mission rewards anew on every simulated run.
8. **Clock-based offline rewards are not server-attested.** Astra local-date login and weekly reset can be advanced by clock changes. This is a source-level risk, not a verified production exploit.
9. **Baseline stake-profit achievement checks gross mutation credit.** `app_controller.dart:1147` passes settlement `coinDelta` as `stakeNet`; a positive Normal return can satisfy the profit achievement even when below the original stake. Astra cannot trigger it because stakes are disabled.
10. **Price recommendations must respect backend grant IDs.** Do not change displayed coin counts without coordinated product/validator delivery. Current paid pack purchasing power roughly doubles under Astra's cheaper Joker collection, which matters even if real purchases are currently disabled.
11. **Exclude owner/dev assistance and restored entitlements.** Developer coins, heat skips, and restored existing ownership are not earned progression.

Recommendation: use this audit to define and test a proposed payout grid first. Do not change reward settlement, cap behavior, or live prices merely to make a simulated summary look balanced.

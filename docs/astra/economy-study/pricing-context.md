# WILDCARD coin-pack pricing context

Checked 5 September 2026. Read-only research and pricing hypotheses; no application, Google Play product, or backend changes were made. Astra currently disables real purchases.

## What the source actually contains

| Product ID | Coin grant in Flutter and billing backend | GBP shown in retained WebView source |
| --- | ---: | ---: |
| `coins_250` | 250 | £0.99 |
| `coins_600` | 600 | £1.99 |
| `coins_1600` | 1,600 | £4.99 |
| `coins_3600` | 3,600 | £9.99 |
| `coins_8500` | 8,500 | £19.99 |
| `remove_ads` | Permanent forced-ad removal entitlement | £2.99 |

Quantity evidence: `flutter_app/lib/core/app_constants.dart:31`, `flutter_app/lib/domain/economy.dart:455`, and `functions/billing.js:30`. Historical price evidence: `www/index.html:7703` and `www/index.html:7775`; the July v6.9.10 revenue report contains the same ladder. Those historical GBP amounts are **not proof of current Play Console prices**.

The current Flutter client queries Google Play product details (`flutter_app/lib/services/billing_service.dart:91`) and displays `product.price` (`flutter_app/lib/app/screens/shop_hub_screen.dart:267`). This is the correct place to obtain a customer's real localized price. No live authenticated Play offer response was inspected in this subtask. Google's integration guide confirms that querying product details returns localized product information. [Google Play Billing integration](https://developer.android.com/google/play/billing/integrate)

Remove Ads is a non-consumable, separate from repeatable coin products. Its current store copy says it stops forced interstitials while leaving optional rewarded ads available. Do not describe it as removing every possible ad. Astra returns before billing initialization or purchase and shows an earned-coins screen instead.

## Suggested small ladder to test after the earned economy is settled

The following is a design hypothesis anchored to Astra's 100-coin standard Wood Vault and 300-coin Gold Vault. It is not a simulation-derived revenue optimum. The 60-coin newcomer discount applies only until the player owns 15 Jokers; do not sell packs on the assumption that every future Wood Vault costs 60.

| Proposed pack | Coins | Proposed UK customer price | Standard Wood Vaults, or Gold Vaults | Coins per £ |
| --- | ---: | ---: | --- | ---: |
| Small | 300 | £0.99 | 3 Wood or 1 Gold | 303.03 |
| Medium | 600 | £1.79 | 6 Wood or 2 Gold | 335.20 |
| Large | 1,500 | £3.99 | 15 Wood or 5 Gold | 375.94 |

These three tiers are the provisional minimum catalogue. Each quantity cleanly divides into the normal Vault prices; players need not buy another pack simply to use an awkward Vault remainder. The largest improves coins per pound by about 24.1% against the smallest. No limited-time urgency, automatic best-value selection, or £19.99 tier is necessary for this test. A fresh ten-Joker collection can buy its five discounted Wood Vaults for 300 coins; the counts in the table deliberately use the later standard price.

The earlier proposal of 300/£1.99, 600/£3.79 and 1,200/£6.99 is withdrawn. Reviewing the whole wallet showed that it would make a 7,500-coin Sly look cost £43.93 when funded from those packs, and the cheapest full Joker collection roughly £62. Vault affordability alone was an insufficient basis for that ladder.

If the revised proposal is adopted for a later release, define the new products and grants consistently in Play, Flutter and the verified backend; honor old product IDs and unfinished purchases at their original quantities. Do not change the quantity promised by an old SKU merely because its current store card is hidden. Price discovery can change these proposals. They are neither proven optimal GBP prices nor evidence of consumer willingness to pay.

### Collection bypass and existing cosmetic prices

The collection sampler starts with ten tutorial Jokers and excludes subsequent free Joker gifts. Its wood-first path completes the remaining 92 discoveries using **85 Wood and 7 Gold Vaults for 10,400 coins**, exactly across 1,000 sampled paths. Completion cost is deterministic for this strategy; acquisition order is random. The retained 8,500-coin pack covers **81.7%** of that budget and can buy all 85 Wood Vaults for 8,300 coins, reaching 95 of 102 Jokers with 200 coins left. It bypasses most non-WILD discovery in one purchase.

The proposed 300, 600 and 1,500 packs cover **2.9%, 5.8% and 14.4%** of that same collection budget. Seven 1,500 packs would cover 10,400 coins for £27.93, leaving 100 coins. This is an illustrative full-purchase route, not a suggested player goal: earned coins and free gifts reduce the amount a player would need to buy.

The source's cosmetic catalogue also needs a separate review before treating any new coin ladder as coherent. `flutter_app/lib/domain/progression_catalog.dart` contains older Sly looks at 350–800 coins, newer bespoke Sly looks at 5,000–7,500, normal UI themes at 1,000, premium rooms at 3,500–5,000, and premium tables at 2,200–3,200. A complete Hearts/Spades kingdom set costs **9,800** (1,000 theme + 2,800 table + 6,000 Sly); Diamonds/Clubs costs **11,700** (1,000 + 3,200 + 7,500), more than the cheapest entire Joker collection. With the revised pack hypothesis and no earned balance, a 7,500-coin Sly still costs £19.95; those two complete-set amounts can be covered for £26.72 and £31.51 respectively. Lowering the cash price of coins alone does not settle these relationships.

Secondary hypotheses, **not applied**:

- Preserve the owner's stated 1,000-coin normal UI theme price as the reference. There is no recommendation to reduce every UI theme to 300–600.
- Keep existing cheaper Sly looks and tables as accessible entry choices. Do not raise their prices to fill a new premium tier.
- Test visually distinct, fully animated bespoke Sly looks around **2,000–3,000 coins**, while retaining a premium over older skins. Measure the equivalent earned runs separately for beginners and veterans.
- Review premium table prices toward **at most 1,000 coins**, or **1,200** for exceptional artwork, rather than leaving ordinary table changes at 2,200–3,200. This is an explicit secondary proposal, not part of the payout recommendation.
- Price a coordinated kingdom as a whole when reviewing its value; three separately plausible prices can add up to an unreasonable complete look. An optional direct-price cosmetic/set purchase is another hypothesis, with exact included items and preservation of already-owned pieces. Its GBP price cannot be determined from gameplay sims.

All existing cosmetic ownership, purchased currency and purchase recovery must remain intact if a later release adopts a retune. These notes do not authorize retroactive entitlement changes.

Keep the no-cost starter draft and a satisfying earned route to Vaults. Do not slow normal earnings, tighten difficulty, or withhold basic build choices just to make these packs sell. Buying more collection variety can affect progression; it is not strictly cosmetic monetization. A finite collection means coin demand will eventually decline for experienced players, which is not itself an economy defect. Durable cosmetic content and the separate Remove Ads entitlement are more appropriate reasons for satisfied veterans to support the game than an endless purchased-power treadmill.

For Remove Forced Ads, retain £2.99 as an initial price hypothesis, separate from coin bundles. Actual UK offer price and entitlement behavior must be verified in a Play-installed release. Its value cannot be judged using Astra because Astra has no ads.

## Connect packs to the actual run simulation

Let `E` be the measured repeatable account coins per run for a specific player skill/progression cohort, excluding one-time Journey/tutorial grants, purchases, and ads. A pack of `Q` coins represents `Q / E` such runs on average. Report this for beginner and experienced cohorts separately; do not divide by a blended mean and call it a typical player's experience.

Also show the median number of completed runs until the next 100-coin Wood or 300-coin Gold purchase, including wallet remainders. Early one-time rewards should be reported separately because they make the first purchase arrive sooner without proving that repeatable progression remains healthy. If a small purchase skips an unexpectedly large part of early discovery, or paid players dramatically outpace free players in competitive modes, adjust product scope or quantity before considering a higher price.

Sims can quantify affordability, progression bypass and expected coin supply. They cannot infer willingness to pay, conversion, price elasticity, retention or the revenue-maximizing GBP price. Those require voluntary human feedback and eventually real offer data. Google Play provides one-time-product price experiments, but small closed tests are unlikely to provide enough purchases for a confident commercial conclusion. [Google Play price experiments](https://support.google.com/googleplay/android-developer/answer/13343030?hl=en)

## Current Google Play fee context

The old summary "15% below $1 million, otherwise 30%" is incomplete for this date. Google's current fee page says UK, EEA and US changes took effect on 30 June 2026. For transactions using Google Play Billing, the published first-$1-million tier is 10% service plus 5% billing; standard non-recurring transactions are 20% plus 5% for new installs and 25% plus 5% for existing installs. Do not assume this developer account's enrollment or applied tier has been verified. Other regions still have the preceding fee structure until their rollout. [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en)

Google's separate rollout article defines first Play installs or first Play updates of sideloaded apps for the new/existing distinction. It currently schedules additional Apps/Games program availability for 30 September 2026 in the UK/EEA/US, so those prospective reductions must not be treated as already earned on 5 September. [Updated fee structure and dates](https://support.google.com/googleplay/android-developer/answer/16954621?hl=en)

Illustration only: if a UK customer price includes 20% VAT and the combined applied Play fee is `f`, approximate proceeds before other costs are `price / 1.20 × (1 − f)`. UK standard VAT is currently 20%; Google lists the UK among tax-inclusive pricing markets. Tax treatment, fee invoices, refunds, chargebacks, exchange rates and the actual settlement can change cash received. These figures are not accounting advice or profit forecasts. [UK VAT rates](https://www.gov.uk/vat-rates), [Google Play tax treatment](https://support.google.com/googleplay/android-developer/answer/138000?hl=en)

| Customer price | Illustrative proceeds at combined 15% fee | At 25% | At 30% |
| --- | ---: | ---: | ---: |
| £0.99 | £0.70 | £0.62 | £0.58 |
| £1.79 | £1.27 | £1.12 | £1.04 |
| £3.99 | £2.83 | £2.49 | £2.33 |

Do not hardcode these UK prices into the Flutter purchase button. Price and availability belong to the actual Play product/purchase option for the buyer's region. The current one-time-product model separates entitlement from purchase options and regional prices; the app's regional distribution also limits availability. [Google Play one-time products](https://support.google.com/googleplay/android-developer/answer/16430488?hl=en)

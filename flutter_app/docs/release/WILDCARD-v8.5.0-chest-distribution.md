# WILDCARD v8.5.0 Vault distribution

## Joker Vaults

| Vault | Price | Common | Uncommon | Rare | WILD |
|---|---:|---:|---:|---:|---:|
| Wood | 200 | 70% | 27% | 3% | 0% |
| Gold | 350 | 0% | 52% | 44% | 4% |

Every open awards one unowned eligible Joker. If a configured rarity is
exhausted, its probability follows the documented deterministic fallback order
and the UI displays the resulting live probabilities before purchase. Wood
never falls through into WILD; Gold never falls through into Common.

New accounts receive ten starters. The first genuine Normal loss can award one
safe Common/Uncommon comeback Joker. After that reward, the theoretical
minimum completion path is:

- 84 Wood Vaults for the remaining non-WILD Jokers;
- 7 Gold Vaults for the seven WILD Jokers;
- 91 total paid Joker Vaults;
- 19,250 account coins.

This is a lower-bound duplicate-protected path, not a promised real-world day
count. The 180-day account model and currency-pack acceleration are documented
in the economy evidence report.

## Cosmetic Vault

- Price: 1,000 account coins
- Duplicate protected
- UI themes use an exact 0.8% first-stage gate while both theme and non-theme
  rewards remain
- The remainder is distributed across Sly looks and tables using the live
  rarity weights
- When either side of the pool is complete, the remaining side correctly
  becomes 100%

The pre-purchase card now shows both exact live rarity odds and exact live
reward-kind odds from the same functions used by the roll. No separate
hardcoded marketing percentages are used.

## Save and animation safety

Coins and the selected reward are persisted before the Royal Vault animation
starts. Claim IDs are idempotent, repeated taps are ignored, and closing the
app during the animation cannot lose or duplicate the unlock.

# WILDCARD v8.5.0 Play Console actions

These are owner/console actions for the final Internal Testing candidate. They
are deliberately not performed for every local phone iteration.

## Product text

Keep the existing product ID `remove_ads` and update its customer-facing text:

- Title: **Remove Forced Ads**
- Description: **Removes automatic adverts. Optional rewarded videos remain
  available.**

Do not rename the product ID. Existing entitlements must continue to restore.

## Currency products

Keep the existing product IDs and backend grant mapping:

- `coins_250`
- `coins_600`
- `coins_1600`
- `coins_3600`
- `coins_8500`

Review the 8,500-coin pack before public launch. The current 180-day model
shows material collection acceleration, so store wording must not claim that
coin packs have no gameplay impact.

## Randomized rewards

Before approval, confirm that the Play listing/reviewer notes explain that
coins can open randomized, duplicate-protected Vaults. The in-app Vault screen
must remain the authoritative near-purchase disclosure for live reward-kind
and rarity probabilities.

## Build and testing

1. Complete local profile APK validation without uninstalling the existing
   sideload.
2. Build one release AAB for Internal Testing after phone acceptance.
3. Use demo ad flags only for an explicitly labelled test-ad bundle.
4. Never promote a demo-ad bundle to production.
5. Upload the AAB to Internal Testing and add release notes.
6. Install from the Play tester link.
7. Verify localized product prices, purchase, pending purchase, restore,
   refund/revocation handling and Remove Forced Ads.
8. Verify Firebase sign-in/cloud recovery, Play Games and App Check on the
   Play-installed package.

The Play-signed package cannot update the locally signed sideload in place.
Back up the verified sideload save to the linked cloud account before the
one-time uninstall/Play-install transition.

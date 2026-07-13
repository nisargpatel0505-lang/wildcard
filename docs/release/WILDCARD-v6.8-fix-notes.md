# WILDCARD v6.8 — Rewarded Mission Refresh and Royal Vault Chests

This is an HTML-first feature release based on v6.7. It preserves the existing scoring, Joker balance, save keys and Android bridge contract.

## Weekly challenge refresh

- Added **Watch ≈30s Ad & Refresh** to Weekly Missions.
- The Android wrapper uses the existing native rewarded-AdMob bridge. The standalone HTML uses a short browser preview for testing.
- A successful reward replaces all three visible missions with a different stored set.
- Weekly stat progress and already-claimed rewards are preserved across refreshes.
- Completed, unclaimed rewards must be claimed before refreshing so a ready reward cannot disappear from view.
- Mission sets, rotation number and refresh date persist in local/native saves and save export/import.
- Refresh is limited to once per day and shares the existing rewarded-ad daily cap.
- Remove Ads owners receive the same refresh instantly while retaining the daily limit.
- Refreshing does not also award the normal +25 coin ad bonus.

## Royal Vault chest system

- Replaced emoji boxes with a reusable layered chest model built from lightweight HTML/CSS.
- Wooden, Golden, Tutorial and Cosmetic vaults each have their own material and gem palette.
- Chest shelves now show the actual vault design before purchase.
- Added a staged opening sequence:
  1. Lock charge and rarity scan.
  2. Rarity signal lock.
  3. Physical lid opening and lock release.
  4. Light beam, radial burst and particles.
  5. Joker or cosmetic reward rises from the chest.
  6. Dedicated claim action.
- Joker rewards show their real collectible front, name and full effect.
- Cosmetic rewards show the real Wardrobe preview.
- The unlock is saved before animation begins, so closing or backgrounding the app cannot lose a paid reward.
- Added a double-tap lock so one purchase cannot be charged twice.
- Normal mode receives the full theatrical timing; Fast mode shortens it without skipping the reveal.
- Reduced-motion and Android performance rules are included.

## Verification

- All inline JavaScript compiled successfully.
- 140 HTML IDs were checked with no duplicates.
- Mission-selection testing confirmed all three slots change and progress remains intact.
- Quick deep simulation completed:
  - 57 Jokers checked
  - 10,000 scoring cases
  - 5,000 The Cheat subset cases, 0 mismatches
  - 550 complete bot runs
  - 0 data failures
  - 0 Joker hook errors
  - 0 invariant failures
- Frostbite and The Cheat regression checks passed.

## Android re-wrap note

Use `wildcard-poker-v6.8.html` as `www/index.html` in the existing wrapper. The native bridge already exposes `WildcardNative.showRewardedAd(callback)`, so no new Android plugin is required for mission refresh. Ad duration is controlled by the AdMob creative; the UI describes it as approximately 30 seconds.

## Android build 12 phone polish

- The mirrored lower rank and suit now stay fully inside every card face on Android, including the Ace.
- Mini chest artwork is pinned to the centre of its left-hand art column and no longer overlaps chest names, descriptions, odds or purchase controls.
- Automated 375 px phone measurements report 0 of 9 card corners escaping and 0 of 3 chest images overlapping their descriptions.

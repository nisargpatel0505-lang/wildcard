# WILDCARD 9.1.1 — phone-only polish candidate

This is a private, ad-free **phone APK** candidate, version 9.1.1 / code 75.
Google Play is deliberately unchanged. The public build defaults to ads enabled;
the owner override is not a paid entitlement and is never written to a save.
No owner APK is uploaded to a public GitHub release.

## Changed

- The Normal opening draft now draws one random candidate for each of three
  routes: Pairs, Suits/Flushes and Straights. Previous/next controls browse
  available Jokers in that route. There are 26 relevant public candidates
  across the three pools; locked and developer cards are excluded. Ordinary
  starter Jokers provide a valid route for a new account.
- Choices are still free run loans, not permanent collection unlocks. Browsing
  uses no deck, shop or Joker-luck RNG. Daily and Gauntlet starts are unchanged.
- The official home no longer shows the ASTRA badge. The isolated offline
  experiment keeps its own branding and service isolation.
- A readable WILDCARD placeholder occupies fixed logo bounds until the actual
  boot logo decodes. This addresses the blank central logo observed in 9.1.0
  without lengthening the loading timeline.
- Four **free preview themes** are selectable in Wardrobe: Midnight Observatory,
  Jade Conservatory, Neon Afterhours and Crimson Theatre. Each has original
  artwork, a full palette and its own quiet native animated atmosphere.
- Their room artwork extends through gameplay, shop, Vault, setup and other
  non-overlay screens; dialogs inherit the palette. Existing themes retain
  their authored room choices. Sly and table cosmetics remain independently
  selectable; no existing purchase is replaced or erased.
- Wardrobe now opens to a two-column Live Theme Studio, with Themes / Tables /
  Sly category controls. Free previews do not increment earned-cosmetic
  achievements or deliver any coin reward. Final theme pricing/selection is
  deferred until the owner chooses the release candidates.
- Owner ad suppression skips ad SDK initialization/loading/showing, hides
  reward-ad offers, grants no fake ad rewards and preserves existing Remove
  Forced Ads ownership. Billing and cloud services retain their existing gates.
- Android bundle/publishing tasks reject the owner-no-ads build flag.

## Rendering safeguards

The four WebP backgrounds total 695,084 bytes, rather than video files. Their
static layers are isolated from a native CustomPainter: at most 30 decorative
repaints per second, 16–18 small motes/rain glints and a few unblurred light
paths. No gameplay RNG, image decoding, widget rebuild or saveLayer is used
per animation frame. Motion stops for reduced-motion settings, hidden routes
and app backgrounding. Actual on-device frame-time performance still needs a
playtest; this description is architecture, not a claimed device FPS measurement.

Artwork was created with the built-in image-generation tool, then mechanically
compressed to WebP. The [artwork prompt set](../artwork/v9.1.1-live-theme-prompts.md)
records the design and final asset paths. Original generated PNGs remain local.

## Economy scope and evidence

Account reward formulas, coin products, Vault prices and one-time Journey
rewards have not changed in this polish update. The previous 3,000-run economy
study remains historical evidence for 9.1.0: **its win rates are not proof of
balance for this new random starter selection**.

Starter follow-up used the real Dart engine: 12 adaptive runs split between
newcomer and full collections, plus three instrumentation-parity seed pairs,
with no invariant or scoring-fidelity failures. This is a smoke test, not a
statistical retune. Detailed test/build/device evidence is recorded at delivery.

## Reproduce the owner APK

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --concurrency=2
flutter test --no-pub --dart-define=WILDCARD_OWNER_NO_ADS=true test/services/owner_ad_build_test.dart test/app/shop_hub_screen_test.dart
flutter build apk --release --no-pub --dart-define=WILDCARD_OWNER_NO_ADS=true
```

Public builds omit `WILDCARD_OWNER_NO_ADS`. Do not use an owner APK as a public
ad/billing verification artifact. When the candidate is accepted, build a fresh
public AAB from the accepted source and an appropriate new Play version code;
do not reuse any older AAB left in the local build directory. No workflow has
been dispatched and no Play publication is authorized in this task.

See the [remaining release checklist](WILDCARD-v9.1.1-release-checklist.md).

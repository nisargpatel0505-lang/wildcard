# WILDCARD v8.5.0 Royal Vault visual evidence

## Result

The v8.5 Royal Vault is a native Flutter ceremony using newly generated,
original production artwork. Wood, Gold and Cosmetic Vaults each use four
independently animated transparent layers: body, lid, lock and crest/glow. The
room, chest and reward remain readable at the required phone sizes, including
320x568. The exact Joker or cosmetic presentation used elsewhere in the app
rises from the chest; there is no generic reward placeholder in production.

The reward is resolved and durably saved by `AppController` before this
animation is shown. This visual audit did not change chest odds, prices,
ownership, reward selection, persistence or idempotency.

## Exact artwork-generation prompts

### Wood Joker Vault

> Create a production mobile-game sprite sheet for WILDCARD, a dark-fantasy arcade casino game. Exactly four isolated components in a clean 2x2 layout on a perfectly flat chroma-key #00FF00 background: top-left chest lower body/base, top-right matching separate lid, bottom-left ornate lock plate, bottom-right separate Sly crest/interior magical glow. WOOD JOKER VAULT: dark carved walnut, aged brass corner plates, small teal magical seams and a carved spade/Sly crest; entry-level but premium, hand-painted illustrated 2.5D, front-facing slight three-quarter perspective, consistent alignment, clean edges and a strong silhouette readable on a phone. No text, labels, letters, characters, coins, loose cards, watermark or random symbols. No green parts in the subject. Keep all four components fully separated with margin and no overlap.

### Gold Joker Vault

> Create a production mobile-game sprite sheet for WILDCARD. Exactly four isolated components in a clean 2x2 layout on a perfectly flat chroma-key #00FF00 background: chest lower body/base, matching separate lid, heavy ornate lock, and separate Sly crest/interior magical glow. GOLD JOKER VAULT: deep violet lacquer and dark emerald panels inside a heavy sculpted aged-gold frame, purple velvet/magical interior, gemstone details, bright cyan energy seams and carved spade motifs. It must feel substantially rarer and more exciting than Wood. Hand-painted dark-fantasy arcade-casino 2.5D art, front-facing slight three-quarter perspective, consistent alignment, clean edges, strong mobile silhouette. No text, characters, coins, loose cards, watermark, random symbols or green subject parts. Keep pieces fully separated with margin and no overlap.

### Cosmetic Vault

> Create a production mobile-game sprite sheet for WILDCARD. Exactly four isolated components in a clean 2x2 layout on a perfectly flat chroma-key #00FF00 background: chest lower body/base, matching separate lid, ornate lock, and separate crest/interior glow. COSMETIC VAULT: midnight indigo/obsidian body, dark purple glass, iridescent pearl and polished rose-gold details, teal and restrained magenta cosmic energy, ornate original Sly mask/fan/spade crest. It must be the most luxurious and visually unusual chest and clearly suggest skins/tables/visual effects rather than gameplay power. Premium hand-painted dark-fantasy arcade-casino 2.5D art, aligned slight three-quarter perspective, clean edges, strong phone-size silhouette. No text, characters, coins, loose cards, watermark, random symbols or green subject parts. Keep all pieces fully separated with margin and no overlap.

### Sly's vault room

> Create an original production-quality portrait 9:16 mobile-game environment for WILDCARD: Sly's hidden underground royal casino vault/chest room in an abandoned palace. A monumental carved spade arch, violet banners, aged gold lockwork, teal/cyan magical doorway glow, old arcade-casino bulbs, subtle card-suit carvings and restrained Easter eggs. Put an empty circular presentation plinth low in the centre and preserve clear negative space through the middle for an animated chest and reward UI. Dark fantasy, premium illustrated 2.5D, emerald teal, royal purple, aged gold and restrained magenta; detailed but not noisy, readable rather than black. No chest, no character, no cards, no coins, no text, labels, logo or watermark.

## Source masters

High-resolution generated sources are retained for future reprocessing, but are
outside the Flutter asset manifest.

| File | Dimensions | Bytes |
|---|---:|---:|
| `assets/art/masters/chests/wildcard-wood-vault-components-master.png` | 1254x1254 RGB | 1,838,107 |
| `assets/art/masters/chests/wildcard-wood-vault-components-alpha.png` | 1254x1254 RGBA | 1,293,751 |
| `assets/art/masters/chests/wildcard-gold-vault-components-master.png` | 1254x1254 RGB | 1,919,570 |
| `assets/art/masters/chests/wildcard-gold-vault-components-alpha.png` | 1254x1254 RGBA | 1,562,440 |
| `assets/art/masters/chests/wildcard-cosmetic-vault-components-master.png` | 1254x1254 RGB | 1,883,455 |
| `assets/art/masters/chests/wildcard-cosmetic-vault-components-alpha.png` | 1254x1254 RGBA | 1,419,704 |
| `assets/art/masters/chests/wildcard-sly-vault-room-master.png` | 941x1672 RGB | 2,457,118 |

Master total: **12,374,145 bytes**.

`tool/process_chest_art.py` chroma-keys/crops the component sheets, adds a
small safety margin, caps large layers, and exports quality-90 WebP with alpha.
The room is exported as quality-88 RGB WebP.

## Runtime artwork

| File | Dimensions | Alpha / transparent area | Bytes |
|---|---:|---:|---:|
| `assets/art/chests/wildcard-wood-vault-body.webp` | 570x405 | yes / 16.7% | 66,920 |
| `assets/art/chests/wildcard-wood-vault-lid.webp` | 578x389 | yes / 19.1% | 77,246 |
| `assets/art/chests/wildcard-wood-vault-lock.webp` | 406x420 | yes / 48.3% | 49,626 |
| `assets/art/chests/wildcard-wood-vault-crest.webp` | 307x420 | yes / 75.2% | 25,960 |
| `assets/art/chests/wildcard-gold-vault-body.webp` | 616x396 | yes / 20.0% | 70,080 |
| `assets/art/chests/wildcard-gold-vault-lid.webp` | 604x425 | yes / 31.5% | 69,304 |
| `assets/art/chests/wildcard-gold-vault-lock.webp` | 339x420 | yes / 41.0% | 46,566 |
| `assets/art/chests/wildcard-gold-vault-crest.webp` | 414x420 | yes / 38.8% | 87,116 |
| `assets/art/chests/wildcard-cosmetic-vault-body.webp` | 588x411 | yes / 20.5% | 74,746 |
| `assets/art/chests/wildcard-cosmetic-vault-lid.webp` | 582x469 | yes / 28.7% | 79,132 |
| `assets/art/chests/wildcard-cosmetic-vault-lock.webp` | 372x420 | yes / 52.7% | 44,564 |
| `assets/art/chests/wildcard-cosmetic-vault-crest.webp` | 368x420 | yes / 56.5% | 29,308 |
| `assets/art/chests/wildcard-sly-vault-room.webp` | 941x1672 | RGB | 290,652 |

Runtime total: **1,011,220 bytes** (0.965 MiB).

All 12 layers have a true 0–255 alpha range and a non-empty trimmed bounding
box. Visual inspection confirmed that each body/lid pair shares a compatible
front-facing slight three-quarter perspective, the open body has a readable
interior rim, and each lock/crest remains identifiable at the smallest phone
size.

## Native Flutter integration

Primary implementation:

- `lib/ui/widgets/royal_vault_animation.dart`
- `lib/ui/widgets/royal_vault_chest_art.dart`
- `lib/ui/widgets/royal_vault_reward_art.dart`
- `lib/ui/widgets/wildcard_background.dart`
- `lib/app/screens/vault_screen.dart`
- `tool/process_chest_art.py`
- `pubspec.yaml`

The ceremony uses one `AnimationController`, `AnimatedBuilder`,
transform/opacity animation, isolated `RepaintBoundary` image layers and capped
custom-painted beam/debris effects. It does not use a video, WebView, animation
framework, runtime blur or uncapped particle emitter.

The phase map is deterministic:

| Phase | Timeline |
|---|---:|
| arrival / anticipation | 0–12% |
| neutral rarity scan | 10–56% |
| seal and lock release | 54–62% |
| lid opening | 61–75% |
| beam and capped burst | 72–84% |
| exact reward rises | 74–86% |
| rarity and reward identity reveal | 86–91% |
| settle / shine | 91–98% |
| Claim becomes available | 100% |

Normal takes 4.20s for Common, 4.29s for Uncommon, 4.38s for Rare and 4.52s
for WILD. Fast takes 2.20s, 2.25s, 2.30s and 2.38s respectively. Platform
reduced-motion uses a 0.90s motion-flattened ceremony without removing the
reward-reading frame.

The exact reward resolver covers every public Joker and every catalogue
cosmetic. Joker rewards use the production compact Joker card. Sly rewards use
the mapped Sly sprite frame. Table rewards use the real felt renderer. Theme
rewards use that theme's real background and palette.

## Deterministic visual captures

The captures use the production widget, generated assets, Bungee/Space
Grotesk/Material Icons fonts and a test-only frozen phase. They do not replace
the live animation.

- `test/ui/goldens/royal_vault/wood-closed-320x568.png`
- `test/ui/goldens/royal_vault/wood-open-360x640.png`
- `test/ui/goldens/royal_vault/gold-opening-390x844.png`
- `test/ui/goldens/royal_vault/cosmetic-opening-393x873.png`
- `test/ui/goldens/royal_vault/joker-common-reveal-360x800.png`
- `test/ui/goldens/royal_vault/joker-rare-reveal-390x844.png`
- `test/ui/goldens/royal_vault/joker-wild-reveal-412x915.png`
- `test/ui/goldens/royal_vault/sly-skin-reveal-393x873.png`
- `test/ui/goldens/royal_vault/table-reveal-390x844.png`
- `test/ui/goldens/royal_vault/theme-reveal-412x915.png`

## Phone-size and behaviour verification

`test/ui/royal_vault_animation_test.dart` checks completed layouts at:

- 320x568
- 360x640
- 360x800
- 390x844
- 393x873
- 412x915

It asserts that the dialog, chest, reward details and Claim control remain
inside the viewport, and that reward details do not overlap Claim. It also
checks 1.3x text scale, reduced motion, early rarity secrecy, a reward clearing
the chest rim, Fast finishing before Normal, and double-tap Claim protection.

Additional coverage:

- `test/ui/royal_vault_chest_art_test.dart`: 12 unique layer mappings, every
  reward artwork mapping, image loading, runtime manifest inclusion and master
  exclusion.
- `test/ui/royal_vault_visual_golden_test.dart`: ten deterministic appearance
  comparisons across all tiers and representative reward types.

Focused result: **29 tests passed, zero failures**.

## APK asset contribution

Inspected APK:

- `build/app/outputs/flutter-apk/app-profile.apk`
- SHA-256:
  `E0E3FFD8DEE83A1D6AE98ED5C829434D89F3AF34D1EC783F8F3DAD7109194954`

The APK contains all 13 runtime chest/room files. Their summed uncompressed
length is **1,011,220 bytes** and their summed ZIP compressed length is also
**1,011,220 bytes** because the already-compressed WebP entries are stored.
There are **zero** `assets/art/masters/` entries in the APK, so the
12,374,145-byte source-master set contributes nothing to the install.

The complete v8.5 profile APK is 108,379,182 bytes. A retained byte-identical
v8.4.1 profile APK was not available for a whole-APK subtraction, so the
defensible asset delta is the APK inventory above: **+1,011,220 packaged
bytes** from the new runtime art, with no source-master leakage.

## Physical Android status

The v8.5.0+64 profile APK was installed in place on the connected POCO Android
16 phone, preserving its existing save. Android reported version name 8.5.0
and version code 64; the app launched and produced no fatal Android or Flutter
log entry in the launch sanity window. A live UI hierarchy check of the New
Run screen confirmed Normal Run, Daily Challenge and Gauntlet are available,
and that neither the Arcade label nor its route is present in the installed
phone build.

A human eyes-on Normal/Fast chest ceremony and frame-pacing pass on that
physical device remains pending. The deterministic six-size widget and golden
verification above is complete, but is not represented as a substitute for
that final tactile/performance check.

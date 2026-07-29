# WILDCARD v8.5.2 — Suit Kingdom Themes

Version: `8.5.2`
Android version code: `66`

## What changed

Four complete suit kingdoms are now available as independent UI themes:

- **Crimson Court** — Hearts Queen, rose-gold palace, crimson gameplay room.
- **Iron Dominion** — Spades King, moonlit fortress, steel-blue gameplay room.
- **Gilded League** — Diamonds Regent, crystal exchange, gilded gameplay room.
- **Clubhold Guard** — Clubs General, living forest stronghold, emerald gameplay room.

Each kingdom includes:

- A completely original full-screen home background with its ruler integrated into
  the environment.
- A separate gameplay background designed to keep cards and scoring readable.
- A dedicated table felt.
- A dedicated Sly skin with expression and full-stage reaction atlases.
- A distinct theme palette that carries across themed application surfaces.

The earlier prototype that placed a small ruler cameo over an existing background
has been removed. The four home worlds are now purpose-built scenes and contain no
pre-rendered app UI, text, logo, frame or watermark.

## Cosmetic catalogue

- UI themes: `1,000` account coins each.
- Hearts and Spades tables: `2,800` account coins each.
- Diamonds and Clubs tables: `3,200` account coins each.
- Hearts and Spades Sly looks: `6,000` account coins each.
- Diamonds and Clubs Sly looks: `7,500` account coins each.

The four theme IDs are new and do not replace or rename existing cosmetics.

## Architecture

- Added a central cosmetic visual registry for theme, table and Sly asset
  resolution.
- Separated home-background and gameplay-background selection.
- Removed duplicated asset maps from the app, shop, game and Royal Vault paths.
- Preserved equipped Sly identity while its expression changes during gameplay.

## Verification

- `flutter analyze`: no issues.
- Focused theme/table/Sly/Vault suite: 89 tests passed.
- Independent mapping review: no concrete regressions found.
- All four home backgrounds: visually inspected at phone aspect ratio.
- Android profile APK built successfully.
- In-place phone install succeeded without uninstalling or clearing save data.
- Device launch verified on a POCO `24095PCADG`, Android 16:
  `versionName=8.5.2`, `versionCode=66`.
- No startup fatal exception found in the captured launch log.

The unrelated long-form balance audit was not rerun because this release changes
presentation and cosmetic routing only; it does not change scoring, Jokers,
economy, RNG, saves or backend behaviour.

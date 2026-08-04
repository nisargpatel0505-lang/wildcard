# Level Mode and Kingdom art direction

Generated on 2026-08-02 with OpenAI's built-in image generation, then resized
with Lanczos filtering and encoded as WebP for the Flutter asset bundle.

## Runtime assets

- `assets/art/backgrounds/wildcard-level-campaign-atlas.webp` — a portrait
  Hall of One Hundred Tables campaign map with a quiet centre for phone UI.
- `assets/art/backgrounds/wildcard-kingdom-hearts-gameplay.webp` — a crimson
  rose-and-heart royal ballroom, independent of Ember Casino.
- `assets/art/backgrounds/wildcard-kingdom-spades-gameplay.webp` — an obsidian
  moonlit war chamber, independent of Moonlit Masquerade.
- `assets/art/backgrounds/wildcard-kingdom-diamonds-gameplay.webp` — a luminous
  ivory, gold and cyan crystal casino, independent of Clockwork Royale.
- `assets/art/backgrounds/wildcard-kingdom-clubs-gameplay.webp` — a living-tree
  forest stronghold hall, independent of Emerald Throne.
- `assets/tables/kingdom_{hearts,spades,diamonds,clubs}_felt.webp` — bespoke
  top-down tactile table surfaces, rendered once rather than tiled.

## Prompt brief

The campaign prompt requested a premium 9:16 dark-fantasy poker atlas carved
into a midnight-violet casino wall: ten distinct regions, a winding chain of
small unnumbered table nodes, four-suit constellations and restrained teal,
violet and gold light. The centre was required to stay calm and low contrast;
characters, text, numbers, logos and UI were prohibited.

Each Kingdom gameplay prompt used its existing Kingdom home illustration only
as a style reference and requested a genuinely new, character-free 9:16 run
interior. Architecture and suit identity were concentrated near the edges so
the HUD, Jokers, equation and cards remain readable.

Each table prompt requested a square, orthographic, empty card-table surface
with tactile fibers, a calm centre and a low-contrast suit seal. Hearts uses
oxblood velvet and rose-gold thorns; Spades uses midnight wool and silver
chevrons; Diamonds uses teal micro-suede and mother-of-pearl lattice; Clubs
uses bottle-green baize, tooled leather and aged-bronze Celtic knotwork.

## Rebuild safety

`tool/build_kingdom_theme_assets.py` validates these files by default. It no
longer overwrites the commissioned rooms or tables during a routine run. Its
fallback background option derives only from the matching Kingdom home art,
never from an unrelated UI theme.

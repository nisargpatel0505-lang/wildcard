# WILDCARD artwork

## Runtime backgrounds

Optimized 900 x 1600 WebP files live in `www/assets/art/backgrounds/`:

- `wildcard-main-menu-palace.webp` — title/menu room.
- `wildcard-the-house-boss-room.webp` — THE HOUSE boss Heat.
- `wildcard-sly-shop-backroom.webp` — between-Heat shop.
- `wildcard-royal-vault-chest-room.webp` — chest collection and reveal room.
- `wildcard-endless-victory-cosmos.webp` — run-complete/Endless transition.

They are loaded only by CSS screen states and do not affect balance or saves.
The four general rooms apply to the default UI theme so purchased theme
backgrounds still work; THE HOUSE keeps its dedicated boss room in every theme.

## Concept sheets

The files under `artwork/concepts/` are reference sheets, not ready-to-ship
sprites. Their checkerboard backgrounds are baked into the pixels.

- `sly-expression-sheet-concept.webp`
- `sly-action-sheet-concept.webp`
- `joker-rarity-card-backs-concept.webp`

Before using them in gameplay, crop each pose/card, remove the background,
align shared character anchors and export transparent WebP assets. Owned
Jokers should remain readable during a Heat; rarity card backs are intended
for the shop and unrevealed rewards only.

# WILDCARD Royal Neon Palace — visual preview

This experiment is based on the canonical `www/index.html` runtime in the current branch. The branch was created from `main`, whose confirmed release is WILDCARD v6.9.14.

## Preview

Serve `www/` through the normal local/Pi deployer and open:

`/experiments/royal-arcade-preview.html`

The wrapper loads the branch's own `www/index.html` in a same-origin frame, then injects:

- `experiments/royal-arcade.css`
- `experiments/royal-arcade.js`

This guarantees the comparison is against the real runtime, not an old copied HTML build.

## Concept contents

- **UI theme — Royal Neon Palace**: a complete room takeover with mint glass, violet palace light, gold cabinet trim, stronger phone hierarchy and clearer panels.
- **Table — Crown Grid Table**: double gold edge, mint circuit grid, crown watermark and improved card contrast.
- **Sly — Crown Dealer Sly**: a vector palace-host skin with neon visor, crown and violet tuxedo.
- **Comparison controls**: switch between the current equipped 6.9.14 appearance and the full concept without saving over the player's cosmetics.

## Safety

This branch does not alter scoring, progression, rewards, billing, privacy, cloud saves, analytics or Android native code. It does not modify the canonical `www/index.html`; it is an isolated design preview for review before a production integration pass.

## Figma

The connected Figma Starter plan reached its MCP tool-call limit during this pass, so the exact-source concept is supplied as editable SVG layers and a live HTML/CSS preview. The existing Figma file remains at:

`https://www.figma.com/design/Vi2JpXGuHPTRO5uouRQ96G`

When the Figma MCP allowance resets or the plan is upgraded, these SVG assets can be imported as editable vectors and the exact screen can be captured into that file.

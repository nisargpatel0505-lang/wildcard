# WILDCARD v6.9.6

## UI skins
- Midas Touch, Vaporwave and Blood Moon themes no longer flat-fill the background. A legacy
  rule was overriding the room art with a plain gradient, so equipping those three wiped the
  palace / Sly's Kingdom illustration. They now tint the real room art like every other theme.
- Verified all 14 themes resolve a background image, all 10 table skins render distinct felt,
  and all 8 Sly skins map to distinct sprite frames.

## Home screen
- New Run now opens a mode picker first: **Normal Run** or **Gauntlet**, then continues to the
  Start Boost screen (starter joker + Sly's Stake Contract) as before.
- Gauntlet moved off the top-level menu into that picker (shown locked with an unlock hint until
  Heat 12 is cleared), reducing the main menu from 15 buttons to 14 and removing a mode most new
  players can't use yet.
- Endless is described on the Normal card as the Heat 13+ continuation it already is; there is no
  separate from-scratch Endless start (Endless needs the engine built across Heats 1-12).

## Scoring smoothness
- The full-screen Win FX "centre pulse" ring no longer fires on High-Card (accent-tier) plays —
  the most common play. It still fires on Pair-or-better and on big/called-out hands.
- Win FX particle budgets now also scale down on any perf-lite device (native app / phone), not
  only when the startup fps probe rated the device 'lite'. Capable phones the probe rated 'full'
  were previously running full particle counts on every play.
- On perf-lite the pulse ring drops its blurred box-shadow and inner rings (the mobile-expensive
  parts). Scoring pacing itself is unchanged (Normal 1.08, Fast 0.65).

## Android release
- Version name: `6.9.6`
- Version code: `19`
- Built release-signed so it updates over the installed v6.9.5 in place (save preserved).

## Verification (pre-build, browser)
- Canonical HTML extracted and `node --check` passed.
- Gold/Vapor/Blood confirmed to resolve `wildcard-main-menu-palace.webp` again (was flat gradient).
- Mode picker: Normal -> Start Boost, Gauntlet locked at bestClearedHeat 0 / unlocked at 12.
- Win FX: accent tier spawns 0 pulse rings (was 1 + 7 sparks); hero tier keeps pulse + full budget.
- A full scoring play completed with no errors, hand refilled, particles cleaned up.

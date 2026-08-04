# WILDCARD v8.3 WebView Presentation Parity Audit

Baseline: `agent/flutter-v8.2.0-dev14-feel` at `0b3e9fa42b872ac7b65509aa3d3ed67a9b3e2c59`

Reference: `main` at `5a1a0d0f82a6b25415760bc7a77085a4e4fa3dd1`

This audit covers presentation only. Poker evaluation, scoring, Jokers, targets,
economy, RNG, saves, cloud, purchases, ads and online services remain outside
the change.

## Evidence

The WebView `playHand()` commits one `ScoreResult`, initializes the equation at
`hand base × 1.10`, then advances rank-side events with:

`valuePoints = base + round(rawRank × 0.6)`

and:

`score = round(valuePoints × visibleMultiplier)`.

Flutter dev.14 instead accumulated raw rank into `visibleRank`, labelled it
`VALUE`, and calculated `visibleRank × visibleMultiplier`. The final score was
authoritative, but every intermediate value omitted the hand base and rank
scale.

WebView Normal has an effective card onset gap of about 407 ms
(`beat(220) × 1.85`) and a normal Joker gap of about 666 ms
(`beat(360) × 1.85`). Flutter dev.14 waits 700 ms and 880 ms serially. Because
the whole `GameHostScreen` is under one `ListenableBuilder(game)`, every visual
beat also rebuilds the broad active surface.

## Before / after matrix

| Area | dev.14 before | v8.3 target / implementation |
|---|---|---|
| Scoring data flow | Durable controller mutates presentation and calls `notifyListeners()` per event. | One committed `ScoreResult`; a presentation-only timeline publishes narrow frames without mutating gameplay. |
| Scoring timing | 440 ms lead-in, then serial 700/880 ms waits. | Timestamped Normal/Fast beats with readable overlapping visual lifetimes and deterministic completion/cancellation. |
| Rebuild scope | Broad host rebuild on every score event. | Static shell/background/HUD remain isolated; only timeline listeners for cards, Jokers, equation and overlay update per beat. |
| Equation behaviour | Raw rank is labelled VALUE; intermediate score is mathematically wrong. | Hand base, rank scale, multiplier and total follow the authoritative formula at every beat and land exactly on the result. |
| Playing-card feedback | Cards are mostly static, but settled-state plumbing still describes lift and chip identity is text-keyed. | Stable UID keys, no card movement, explicit normal/selected/scoring/Joker/settled/kicker states, sequence-keyed chips. |
| Joker feedback | Spring scale and small boxed label; active state is driven by the broad controller. | Timeline-driven controlled lift/scale, bright rarity outline and readable unboxed proc label; blocked Jokers never proc. |
| Final score | Equation completes, but no separate large floating total. | Large gold final total above the table, coordinated spatially and temporally with the callout. |
| Sly | Rich quip catalogue exists; reaction is a small expression kick and mostly end-of-hand. | Priority reaction model with mood colour, expression, speech, motion profile, hold and sequence identity. |
| Audio | Good pre-rendered library; callbacks are tied to controller notifications and Lucky Seven uses a separate timer. | Visual, equation, SFX, haptic and Sly cues share the same timeline onset. |
| Haptics | Optional, non-blocking basic beats. | Same safety, with distinct card/Joker/retrigger/multiplier/finale patterns and graceful fallback. |
| Background | Optimized static image plus two cheap drifting lights. | Preserve isolation/decode sizing; add cheap score-progress, modifier, House and major-moment atmosphere. |
| Chest | Large custom implementation, but boxed modal, early rarity/status copy, jitter/flash, rubber easing and icon-like reward. | Physical locked chest on a pedestal, charge/scan/unlock/hinged lid/internal light/reward depth/rarity/settled claim timeline. |
| Shop | Run coins and prices are mainly text. | Reusable painted W coin, balance, price, reward and sell-value components with safe bottom action region. |
| Responsiveness | One `compact` flag; 320×568 scrolls substantially and large screens stretch the phone column. | Explicit very-short/small/standard/tall/large/foldable/tablet metrics across the required sizes and text scales. |
| Reduced motion | Some widgets use the platform flag; timing and ceremony treatment are inconsistent. | Motion is reduced without removing reading time, meaning, rarity or event order. |
| Performance | Static art is isolated, but score beats rebuild the broad tree. | Repaint boundaries plus narrow listenables; no per-beat full-screen rebuild, no card layout motion and deterministic effect disposal. |

## Guardrails

- The domain `WildcardScoringEngine` remains authoritative and unchanged.
- Timeline values are derived from the already-computed result and its events.
- Cards never lift, shake, rotate or scale during selection or scoring.
- Replacement cards appear only after the final score/callout hold.
- The retired full-screen Win FX is not restored.
- Quality and accessibility choices affect presentation only.

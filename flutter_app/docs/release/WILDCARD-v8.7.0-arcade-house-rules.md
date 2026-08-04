# WILDCARD v8.7.0 — Arcade House Rules and Joker repair

Build: `8.7.0+70`

Branch: `agent/flutter-v8.7.0-arcade-house-rules`

## Player-facing changes

- Added eight optional House Rules to Normal Run after the player has cleared
  Heat 12: Paupers' Table, Royal Court, Colour Blind, Suit Carousel, Echo
  Table, Discard Duty, Closing Window and Modifier Marathon.
- House Rule runs keep the normal Heat, shop and Endless loop. They do not use
  stakes and cannot replace a Classic best score or leaderboard entry.
- The active public Joker pool is now 89 focused Jokers. Thirteen duplicate or
  low-value designs were retired from Arcade offers, chests, starters and the
  collection without breaking old saves or authored Levels.
- Retired collection unlocks migrate to equivalent active Jokers. An active
  run that already holds a retired Joker keeps it until that run ends.
- Reworked weak flat-rank Jokers into readable suit, rank, retrigger and
  deck-building engines. The intentionally conservative values avoid the
  runaway multipliers proposed in the original design note.
- Ace Magnet now visibly announces its copy proc and cannot copy a suppressed
  Ace or exceed the exact-card-copy cap.
- The final Joker-discovery milestone now completes when all 89 active public
  Jokers are owned; its stable save identifier is unchanged.

## Presentation and phone polish

- House Rules are explained in Choose Run, announced at the start of a Heat,
  and shown live above the Joker rack.
- House Rule text names the current colour, suit or accumulated discard tax
  where relevant.
- HUD labels, score-equation labels and Joker descriptions are more readable.
- The equation cells now grow safely with Android text scaling instead of
  overflowing on a 320×568 display at 1.3× text.
- Hands, Deck, Sort, Play, Discard, Abandon and contract information controls
  retain at least 48 dp touch targets.
- Long modifier, blocked-Joker and House Rule copy receives an extra line on
  compact phones rather than clipping.
- Level Mode continues to show each Joker's original authored-Level effect,
  while Arcade shows the new effect.
- Sly identifies a House Rule table with concise game-focused dialogue.

## Correctness and compatibility

- Authored Levels retain the legacy effects, descriptions and modifier status
  of reworked Jokers. The Level simulator uses the same legacy switch.
- A House Rule alone no longer activates modifier-dependent Jokers. A real
  Heat modifier still does.
- House Rule saves resume with leaderboard eligibility forced off, including
  older checkpoints that omit the eligibility flag.
- House Rule recent runs retain their real terminal score and display as
  `House Rule`; they are excluded defensively from Classic bests and top runs.
- Pi analytics uses matching `house-<rule>` start/end labels. The aggregate
  server allowlist now accepts Flutter v8.7.0 and the eight bounded House Rule
  modes without collecting player identity or exact scores.

## Verification

- `flutter analyze --no-pub`: no issues.
- Fast regression suite: 533 passed, 1 intentionally skipped.
- Deterministic engine stress inside that suite: 2,000 complete runs, zero
  invariant failures.
- Smart-bot matched-seed smoke: 160 runs over adaptive, hand-ranking, pair and
  flush strategies, zero invariant failures. Adaptive Medium wins moved from
  20.0% to 32.5%, average Heat from 9.95 to 10.53, while triggers per hand
  stayed effectively flat (2.597 to 2.634).
- Phone layout matrix: 320×568, 360×640, 360×800, 393×873, 412×915,
  480×960, 600×960 and 800×1280.
- Dense 320×568 accessibility case: 1.3× text, modifier, two table rules,
  five Jokers, nine cards and all table controls.
- Pi aggregate/privacy and Daily Board security regression: passed.
- APK package: `com.nisarg.wildcard`, min SDK 24, target SDK 36.
- APK signature: verified v2, production certificate SHA-256
  `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`.
- Owner/profile APK SHA-256:
  `a650ccf532053b7322a16ca57b6e0c54d0f8e9189f142c9fc36c16f0aa028492`.

## Owner build behavior

The phone validation APK is a profile owner build. It retains the DEV ×20
test Joker and suppresses forced ads so presentation and scoring can be tested
without interruptions. These owner-only behaviors remain absent from public
release builds.

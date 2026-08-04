# WILDCARD Flutter — Action List for ChatGPT

_Last updated: 2026-07-24 · current build on phone: **v8.2.0-dev.14 (code 59)**_

Restore the WebView's game-feel in the Flutter port. Treat `www/index.html` (v6.9.14, branch
`main`) as the source of truth for look, timing, colour and juice. **Do NOT change game rules,
scoring math, economy, RNG, save format, or backend.** Presentation layer only. Keep
`flutter analyze` clean and existing tests green (currently 139 passing).

---

## ⚠️ READ FIRST — the branch is stale vs what's actually on the phone

The Flutter code lives at `wildcard-app/flutter_app` on branch `agent/flutter-v8-native-beta`
(PR #15). **The committed code on that branch is Codex's ORIGINAL port.** A large body of
presentation work already exists as **UNCOMMITTED local changes (~41 modified files)** and is
what's running on the phone as dev.14.

**Any analysis that says "loading bar missing / SFX missing / Sly is 9 dry lines / no death
screen / no callouts" is describing the OLD committed code, NOT the current build.** Before you
start, diff against the working tree (or have Nisarg commit/push it) or you WILL redo finished
work and hit conflicts.

### Already DONE locally (do not rebuild — enhance only if listed under TODO)
- **Boot loading screen with animated gold load bar** (`lib/ui/screens/boot_loading_screen.dart`,
  wired via `_BootstrapGate` in `main.dart`). The old `CircularProgressIndicator` critique is obsolete.
- **Full SFX layer** — 67 pre-rendered WAVs in `assets/audio/sfx/` (rising score/joker/mult tone
  ladders, callout chords, death jingle, chest/vault chords, buy/sell), played via `SfxService`
  (`audioplayers` `AudioPool`, low-latency). Wired per scoring beat via `game.onScoreBeat`.
- **Sly's 26-category quip system** (`lib/domain/sly_quips.dart`) — ~196 lines, random per context.
  `_saySly()` fires on greet/modifier/discard/clutch/seven-hit/seven-miss/per-hand-mood.
- **Modifier ambience + music ducking** (`AudioService.syncAmbience`).
- **Arcade death screen** — red wash pull-over + slam title + white flash + shake + CRT scanlines,
  shown before the interstitial (`lib/ui/widgets/death_screen_overlay.dart`).
- **Heat intro overlay** (`lib/ui/widgets/round_intro_overlay.dart`) — the round wash/card.
- **Callout tiers WILD!/MEGA!/GREAT!/NICE!** with tier colour + chord + a suit-glyph spark burst
  (`_CalloutStamp` / `_CalloutSparkPainter` in `game_host_screen.dart`).
- **Score count-up** — VALUE/MULT/SCORE roll up beat-by-beat (`_EquationValue` interpolates;
  do NOT snap). Nisarg explicitly likes this — keep and keep prominent.
- **Gold/purple score chips** — big Bungee "+N" rises off each scoring card: GOLD for a card
  score, VIOLET when a Joker acted on it (`_RisingScoreChip` + `_chipColor`, `PlayingCardTile`).
  (The full floating-final-total is still TODO — see P0.)
- **Cards are STATIC** — idle float / select-lift / scale / shake all removed; `PlayingCardTile`
  is a `StatelessWidget`. Only border/glow + the rising chip change. Keep it static.
- **Grade stamp** on heat clear; **green Play / red Discard** swapped sides; **contract payout
  popup** (Easy/Med/Hard) in the mode picker; **Cabinet attention dot**; taller cards + fixed
  centre pip; small-caps legibility (Bungee→SpaceGrotesk at ≤10px); button press-squish +
  springy joker proc (`lib/ui/widgets/springy.dart`, `SpringValue`/`PressableScale`).
- **Next Heat button** raised off the gesture bar (shop).

---

## P0 — SCORING ANIMATION: finish the rebuild (the #1 complaint)

The chips + count-up + callouts are done, but the **architecture and the floating final total
are NOT**, and that's why it still feels like a slideshow.

**Root cause (already diagnosed — just fix):** the whole run screen sits under ONE
`ListenableBuilder` (`game_host_screen.dart`) and `game_controller.dart` `_presentScoreEvents`
calls `notifyListeners()` once per scoring event with `await _wait(beat)` between. So every beat
rebuilds the ENTIRE screen. It's a slideshow of full-tree rebuilds, not an animation.

Do:
1. **Test in profile/release** (`flutter run --profile`), never debug — debug misrepresents perf.
2. Drive the scoring sequence from an **AnimationController / event-queue timeline**, NOT
   `notifyListeners()` per beat. Precompute the full result first; the animation only PRESENTS it
   (the controller already computes `visibleRank/visibleMultiplier/visibleTotal` — use them).
3. **Stop full-screen rebuilds.** Split `RunTableScreen` into independently-updating sections
   (background, target HUD, score display, card hand, joker row, controls) via `ValueNotifier` +
   `ValueListenableBuilder`/`AnimatedBuilder`. A joker proc must not rebuild the background or buttons.
4. Animate **transforms** (Transform/Slide/Scale/Fade), never layout (width/height/padding/Positioned).
5. **Floating final total** — the missing piece: at the end of the sequence, the big final score
   RISES up the screen, large and gold, and fades (WebView `floatScore()` / `@keyframes rise`,
   `www/index.html` ~:433; font ≈ `clamp(40px,9vw,72px)`, floats up ~60px). Keep the small
   equation panel's count-up during the beats, but the finale is this big rising number.
6. Joker tile should **lift + outline** when it procs (WebView `.joker.proc`). Retrigger chip =
   violet "AGAIN +N".
7. Match WebView **timing/overlap** (not fully sequential): selected cards rise ~120ms; first card
   ~180ms; each next staggers ~90ms; joker starts before the previous card fully finishes; mult
   ~220ms; final total ~300ms; whole sequence ~1.2–2.0s. Keep a fast-mode option.
   (NOTE: Nisarg currently finds it too fast/rigid — the fix is smooth overlapping transforms, NOT
   just larger delays. Bigger delays on rigid snaps = same problem, slower.)

WebView refs: beat loop `www/index.html:5710–5790`; `.proc-chip`/`procChipV69` (~:314);
`.float-score`/`rise` (~:433); `calloutFor` (~:3333).

---

## P1 — restore the rest of the game-feel layer

- **Sly bold reactions.** He DOES speak + swap expression + subtly bob today, but it reads as
  "no reaction" because the motion is tiny and he has no mood glow. Give him the WebView's
  `slyReact()`/`slySay()` energy: a visible pop/tremble/rock on reaction, a **mood-coloured
  border/glow per hand tier** (`data-sly-mood`), and more triggers (card scored, joker proc,
  retrigger, big mult, lucky-seven hit/miss, target crossed, WILD, poor hand, narrow miss).
  `lib/ui/widgets/sly_sprite.dart` is already stateful (idle bob + expression kick) — make the
  reaction bold and add the glow. Keep him in the header bubble; do NOT bring back the stage
  sprite (Nisarg had it removed — it read as messy).
- **Animated background (`bgfx`) — the biggest missing "alive" layer.** Flutter is a static room
  image. WebView layers blob/spotlight/suit-rain/casino-floor/jackpot-lines/marquee-bulbs/CRT, and
  crucially the **background heats up with your score** (casino → arcade jackpot) and **reacts to
  the active modifier** (`www/index.html:126, 677`). Build a performant version with CustomPaint /
  cheap transforms, gated behind the quality tier (see P2). The background + felt are already
  static `CustomPaint` in `RepaintBoundary` — extend those, don't replace.
- **Victory cinematic.** Death screen is done; the win still just banks. The single-tear video is
  wired (`_SlyTearCinematic`) but there's no full victory set-piece (WebView v6.9.12). Add one.
- **Score-time particle FX** — WebView `sparkfly`/`stampin`/`wildglow`/`hotpulse`. Flutter has the
  callout spark burst + vault particles only. Add tasteful score-time sparks on big hands.

---

## P2 — targeted UI + responsiveness

- **Shop coin icons.** Coins are plain text (`_RunCoinBadge` "RUN COINS / {n}" and "{price} run
  coins", `between_heat_shop_screen.dart`). Add a real coin glyph for balances and every price.
- **Responsiveness.** `_RunMetrics` only has `compact` (width<340) + `veryShort`, fixed card bases.
  Add proper breakpoints: small-height phones, large phones, **tablets**, and
  `MediaQuery.textScaler` handling. WebView has many `@media` breakpoints for reference
  (width ≤600, height-based ~:1037/:1246, `prefers-reduced-motion`).
- **Quality / performance tiers** (WebView `body.perf-lite`, ~:967). Add Low / Balanced / High /
  Ultra profiles controlling particle count, background animation rate, blur/shadow complexity,
  max concurrent effects, and 60 vs high-refresh. Plus an explicit **Battery-saver / Reduced /
  Full effects** setting. Support 60/90/120 Hz properly. Attractive on flagships, stable on budget
  Android. **Test on a real low-end device, not an emulator/flagship.**

---

## Native upgrades worth doing (Flutter can, WebView couldn't)

- **Patterned/curved haptics** — rising rumble as the total counts up, a sharp tick per card, a
  heavy thump on WILD!. Cheapest "feels premium" win. (Basic `HapticsService` exists; make it patterned.)
- **Home-screen widgets & App Shortcuts** — Daily Board (today's target + best), streak widget,
  long-press "Play Daily"/"Continue run".
- **Local + push notifications** (Firebase already present) — Daily reset, streak-about-to-break,
  new Gauntlet.
- **Themed/dynamic app icon** that follows the equipped theme (Android 13+ Material You).
- **Central audio director** coordinating card ticks / chip accumulation / mult rise / joker /
  target crossed / heat complete / WILD / shop / Sly, with pitch rising over consecutive cards and
  larger multipliers adding layers (not just volume). The SFX ladders exist; the coordinating
  director does not.

---

## KEEP AS-IS (Nisarg likes these — do not change)
- Choose-run screen layout.
- The animated count-up of the total when scoring (make it MORE prominent, don't remove).
- WILD/GREAT callout pops and joker-retrigger popups (enhance to the full 4-tier system, keep feel).
- Cards static — no idle float, no lift. Any card motion only as part of the scoring finale.
- **Do NOT** restore the old full-screen "Win FX" — it was deliberately retired (v6.9.9/v6.9.14).
  The float-score + callouts are the lighter replacement.

---

## Delivery
- Work on `agent/flutter-v8-native-beta` or a child branch. Commit the existing local work first
  (ask Nisarg) so you have a real baseline.
- Profile the scoring sequence in DevTools (build/layout/paint/raster); confirm no dropped frames
  on a mid/low-end device before calling it done.
- Keep `flutter analyze` clean and all tests green.
